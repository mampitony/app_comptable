// api/notify-chat.js — notifications push de la messagerie AJEM (Vercel).
//
// À placer à côté de api/notify.js (même dossier, même variable
// d'environnement FIREBASE_SERVICE_ACCOUNT). Aucune autre configuration.
//
// L'app Flutter envoie seulement { conversationId, messageId }. Ce serveur :
//   1. relit le message dans Firestore (il ne fait pas confiance au texte
//      envoyé par l'app),
//   2. refuse s'il n'existe pas, s'il date de plus de 2 minutes, s'il n'est
//      pas un vrai message (texte ou photo) ou s'il a déjà été notifié,
//   3. envoie la notification aux appareils des autres participants
//      (jamais à l'expéditeur).
const admin = require('firebase-admin');

const MAX_AGE_MS = 2 * 60 * 1000;

function init() {
  if (admin.apps.length) return;
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!raw) throw new Error('Variable FIREBASE_SERVICE_ACCOUNT manquante');
  admin.initializeApp({ credential: admin.credential.cert(JSON.parse(raw)) });
}

function validId(v) {
  return typeof v === 'string' && v.trim() !== '' && !v.includes('/');
}

function chunk(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'Méthode non autorisée' });
  }

  let msgRef = null;
  try {
    init();

    const body = req.body || {};
    if (!validId(body.conversationId) || !validId(body.messageId)) {
      return res.status(400).json({ error: 'Identifiants invalides' });
    }
    const conversationId = body.conversationId.trim();
    const messageId = body.messageId.trim();

    const db = admin.firestore();
    const convRef = db.collection('conversations').doc(conversationId);
    msgRef = convRef.collection('messages').doc(messageId);

    // Réserve le message de façon atomique : un seul envoi possible.
    const claim = await db.runTransaction(async (t) => {
      const snap = await t.get(msgRef);
      if (!snap.exists) return { status: 404, error: 'Message introuvable' };
      const data = snap.data();
      const notifiable = ['text', 'image', 'call_video', 'call_voice'];
      if (!notifiable.includes(data.type)) {
        return { status: 403, error: 'Message non notifiable' };
      }
      if (data.deleted) return { status: 403, error: 'Message retiré' };
      if (data.notified) return { status: 409, error: 'Déjà notifié' };
      const created = data.createdAt && data.createdAt.toDate
        ? data.createdAt.toDate().getTime()
        : 0;
      if (!created || Date.now() - created > MAX_AGE_MS) {
        return { status: 403, error: 'Message trop ancien' };
      }
      t.update(msgRef, { notified: true });
      return { status: 200, data };
    });

    if (claim.status !== 200) {
      msgRef = null; // rien n'a été réservé
      return res.status(claim.status).json({ error: claim.error });
    }

    const message = claim.data;
    const senderId = String(message.senderId || '');

    const convSnap = await convRef.get();
    if (!convSnap.exists) {
      return res.status(404).json({ error: 'Conversation introuvable' });
    }
    const conv = convSnap.data();
    const participants = Array.isArray(conv.participants) ? conv.participants : [];
    if (!participants.includes(senderId)) {
      return res.status(403).json({ error: 'Expéditeur invalide' });
    }
    const recipients = participants.filter((p) => p !== senderId);
    if (recipients.length === 0) return res.status(200).json({ ok: true, sent: 0 });

    // Nom de l'expéditeur
    const senderSnap = await db.collection('users').doc(senderId).get();
    const s = senderSnap.exists ? senderSnap.data() : {};
    const senderName =
      [s.prenom, s.name].filter((x) => x && String(x).trim()).join(' ') || 'Un membre';

    // Jetons des appareils des destinataires
    const tokens = new Set();
    for (const part of chunk(recipients, 30)) {
      const q = await db.collection('chatUsers').where('memberId', 'in', part).get();
      q.forEach((d) => {
        const tk = d.get('fcmToken');
        if (typeof tk === 'string' && tk) tokens.add(tk);
      });
    }
    if (tokens.size === 0) return res.status(200).json({ ok: true, sent: 0 });

    const count = Math.min(Math.max(parseInt(body.count, 10) || 1, 1), 10);
    let text;
    if (message.type === 'image') {
      text = count > 1 ? `📷 ${count} photos` : '📷 Photo';
    } else if (message.type === 'call_video') {
      text = '🎥 Appel vidéo en cours — touchez pour rejoindre';
    } else if (message.type === 'call_voice') {
      text = '📞 Appel vocal en cours — touchez pour rejoindre';
    } else {
      text = String(message.text || '').trim().replace(/\s+/g, ' ');
    }
    const preview = text.length > 120 ? text.slice(0, 120).trim() + '…' : text;
    const isGroup = conv.type === 'group';
    const title = isGroup ? String(conv.name || 'Groupe') : senderName;
    const bodyText = isGroup ? `${senderName} : ${preview}` : preview;

    let sent = 0;
    for (const part of chunk(Array.from(tokens), 500)) {
      const result = await admin.messaging().sendEachForMulticast({
        tokens: part,
        notification: { title, body: bodyText },
        android: { priority: 'high', notification: { sound: 'default' } },
        apns: { payload: { aps: { sound: 'default' } } },
        data: { type: 'chat', conversationId },
      });
      sent += result.successCount;

      // Nettoie les appareils qui n'existent plus.
      const dead = [];
      result.responses.forEach((r, i) => {
        const code = r.error && r.error.code;
        if (
          code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token'
        ) {
          dead.push(part[i]);
        }
      });
      for (const tk of dead) {
        const q = await db.collection('chatUsers').where('fcmToken', '==', tk).get();
        for (const d of q.docs) {
          try { await d.ref.update({ fcmToken: admin.firestore.FieldValue.delete() }); } catch (_) {}
        }
      }
    }

    return res.status(200).json({ ok: true, sent });
  } catch (err) {
    console.error('Erreur notify-chat:', err);
    // L'envoi a échoué : libère le message pour qu'un nouvel essai soit possible.
    if (msgRef) {
      try { await msgRef.update({ notified: false }); } catch (_) {}
    }
    return res.status(500).json({ error: "Échec de l'envoi" });
  }
};
