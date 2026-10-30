// notification-server/index.js
//
// Remplace la Cloud Function (qui nécessitait le plan Blaze) par un
// petit serveur Node.js autonome qui joue exactement le même rôle :
//
//   Responsable crée une annonce (Flutter, inchangé)
//         ↓
//   Firestore : nouveau document dans announcement_notifications
//   (écrit par lib/services/push_notification_service.dart, inchangé)
//         ↓
//   CE SERVEUR : écoute Firestore en temps réel, détecte le nouveau
//   document, envoie la notification via Firebase Cloud Messaging
//         ↓
//   Tous les téléphones abonnés au topic "ajem_announcements"
//
// Ce serveur ne touche jamais à l'authentification, aux rôles, à la
// gestion des membres ni à la logique des annonces : il ne fait que
// lire announcement_notifications et envoyer des notifications.
//
// Sécurité : serviceAccountKey.json donne un accès total (niveau
// administrateur) à votre projet Firebase. Il ne doit JAMAIS être :
//   - commité dans Git (voir .gitignore fourni),
//   - copié dans l'application Flutter,
//   - partagé publiquement.
// Il doit rester uniquement sur la machine qui fait tourner ce serveur.

require('dotenv').config();
const http = require('http');
const admin = require('firebase-admin');

// ─────────────────────────────────────────────────────────────
// 1. Connexion à Firebase (Firestore + Cloud Messaging) avec le
//    compte de service (droits admin, jamais exposé côté client).
// ─────────────────────────────────────────────────────────────
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// Doit rester identique à `ajemAnnouncementsTopic` dans
// lib/services/push_notification_service.dart.
const TOPIC = 'ajem_announcements';

// ─────────────────────────────────────────────────────────────
// 2. Écoute en temps réel de Firestore.
//    On ne traite que les documents créés APRÈS le démarrage du
//    serveur, pour ne jamais ré-envoyer d'anciennes annonces à
//    chaque redémarrage.
// ─────────────────────────────────────────────────────────────
const startedAt = admin.firestore.Timestamp.now();
console.log('🚀 Serveur de notifications AJEM démarré.');
console.log(`⏱️  Écoute des annonces créées après ${startedAt.toDate().toLocaleString()}`);
console.log(`📡 Topic FCM ciblé : "${TOPIC}"`);

db.collection('announcement_notifications')
  .where('createdAt', '>', startedAt)
  .onSnapshot(
    (snapshot) => {
      snapshot.docChanges().forEach((change) => {
        if (change.type === 'added') {
          handleNewAnnouncement(change.doc);
        }
      });
    },
    (error) => {
      console.error('❌ Erreur d\'écoute Firestore :', error);
    }
  );

// ─────────────────────────────────────────────────────────────
// 3. Envoi de la notification push pour un nouveau document.
// ─────────────────────────────────────────────────────────────
async function handleNewAnnouncement(doc) {
  const data = doc.data() || {};
  const message = (data.message || '').toString().trim();

  if (!message) {
    console.log(`⚠️  Document ${doc.id} sans message, ignoré.`);
    return;
  }

  const body = message.length > 150 ? `${message.substring(0, 147)}...` : message;

  try {
    const response = await admin.messaging().send({
      topic: TOPIC,
      notification: {
        title: 'Nouvelle annonce AJEM',
        body,
      },
    });
    console.log(`✅ Notification envoyée pour ${doc.id} :`, response);
  } catch (error) {
    console.error(`❌ Échec de l'envoi pour ${doc.id} :`, error);
  }
}

// ─────────────────────────────────────────────────────────────
// 4. Petit serveur HTTP de "santé" (health check).
//    Beaucoup d'hébergeurs (Render, Railway, etc.) exigent qu'un
//    port réponde pour considérer le service comme actif — sans
//    impact sur la logique ci-dessus, qui tourne en continu à côté.
// ─────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
http
  .createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Serveur de notifications AJEM actif.\n');
  })
  .listen(PORT, () => {
    console.log(`🌐 Health check disponible sur le port ${PORT}`);
  });
