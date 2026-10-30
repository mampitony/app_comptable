# Serveur de notifications AJEM

Remplace la Cloud Function (plan Blaze requis) par un serveur Node.js
autonome. Rôle unique : écouter `announcement_notifications` dans
Firestore et envoyer une notification FCM au topic `ajem_announcements`
quand une nouvelle annonce est créée.

Ne touche jamais à l'authentification, aux rôles ou à la gestion des
membres/annonces — l'application Flutter fonctionne exactement comme
avant.

## Installation

1. **Récupérer la clé de compte de service** :
   Firebase Console → ⚙️ Paramètres du projet → Comptes de service →
   "Générer une nouvelle clé privée" → un fichier `.json` est
   téléchargé.
   Renommez-le `serviceAccountKey.json` et placez-le dans ce dossier
   (`notification-server/`). **Ne le committez jamais, ne le mettez
   jamais dans l'app Flutter.**

2. **Installer les dépendances** :
   ```
   cd notification-server
   npm install
   ```

3. **Lancer le serveur** :
   ```
   node index.js
   ```
   Vous devez voir :
   ```
   🚀 Serveur de notifications AJEM démarré.
   📡 Topic FCM ciblé : "ajem_announcements"
   🌐 Health check disponible sur le port 3000
   ```

## Test de bout en bout

1. Laissez le serveur tourner (`node index.js`).
2. Depuis l'app, publiez une annonce en tant que responsable.
3. Dans le terminal du serveur, vous devez voir :
   ```
   ✅ Notification envoyée pour <id du document> : projects/.../messages/...
   ```
4. Sur un téléphone où l'app est installée (et abonnée au topic), la
   notification doit apparaître dans la barre système — application
   ouverte, en arrière-plan, ou fermée.

## Faire tourner le serveur en continu (production)

Ce script doit rester actif en permanence pour détecter les nouvelles
annonces. Options adaptées à une association de moins de 100 membres,
de la plus simple à la plus robuste :

- **Test / développement** : le laisser tourner sur votre ordinateur
  avec `node index.js`. Suffisant pour valider que tout fonctionne,
  mais s'arrête si l'ordinateur s'éteint ou se met en veille.
- **Petit serveur toujours allumé** : un Raspberry Pi ou un vieux PC
  laissé sur le réseau, avec `pm2` pour redémarrer le script
  automatiquement en cas de plantage :
  ```
  npm install -g pm2
  pm2 start index.js --name ajem-notifications
  pm2 save
  pm2 startup   # pour redémarrer au démarrage de la machine
  ```
- **Hébergement en ligne** : un petit VPS (quelques euros/mois) ou un
  service comme Railway/Render en formule payante minimale. Le
  health-check HTTP intégré (port `process.env.PORT`) est prévu pour
  ce type d'hébergeur.

## Rappel de sécurité

`serviceAccountKey.json` donne un accès total (niveau administrateur)
à votre projet Firebase — Firestore, Authentication, tout. Il doit
rester uniquement sur la machine qui exécute ce serveur.
