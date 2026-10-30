// functions/index.js
//
// Cloud Function déclenchée automatiquement à chaque nouvelle annonce.
// C'est ICI, côté serveur, que la notification est réellement envoyée à
// tous les membres — jamais depuis l'application Flutter, qui ne fait que
// déposer un petit événement dans Firestore (voir
// lib/services/push_notification_service.dart, notifyNewAnnouncement).
//
// Déploiement (une seule fois, puis à chaque modification de ce fichier) :
//   1. npm install -g firebase-tools   (si pas déjà fait)
//   2. firebase login
//   3. Depuis la racine du projet Flutter : firebase init functions
//      (choisir JavaScript, réutiliser ce fichier)
//   4. cd functions && npm install
//   5. firebase deploy --only functions
//
// ⚠️ Nécessite le plan Firebase "Blaze" (pay-as-you-go) pour les
// déclencheurs Firestore — reste gratuit dans la limite du quota gratuit
// mensuel pour un usage associatif normal.

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Doit être identique à `ajemAnnouncementsTopic` dans
// lib/services/push_notification_service.dart.
const TOPIC = 'ajem_announcements';

exports.sendAnnouncementNotification = functions.firestore
  .document('announcement_notifications/{eventId}')
  .onCreate(async (snapshot) => {
    const data = snapshot.data() || {};
    const message = (data.message || '').toString().trim();

    if (!message) {
      console.log('Événement sans message, notification ignorée.');
      return null;
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
      console.log('Notification envoyée avec succès :', response);
    } catch (error) {
      console.error("Échec de l'envoi de la notification :", error);
    }

    return null;
  });
