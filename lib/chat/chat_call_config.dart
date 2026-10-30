// lib/chat/chat_call_config.dart
//
// Configuration des appels (ZEGOCLOUD).
//
// 1) Crée un compte et un projet sur https://console.zegocloud.com
// 2) Colle ci-dessous l'AppID (nombre) et l'AppSign (chaîne) de ton projet.
//
// ⚠️ L'AppSign est un secret : ne le publie jamais (dépôt public, capture
//    d'écran, discussion...).

const int zegoAppID = 1546025728;
const String zegoAppSign = '2a0538de0ee32e8601552ce45fbad1f2edfbb6da7c37eb9b562845680d5e597b';

/// true quand les deux valeurs ont été renseignées.
bool get zegoConfigured => zegoAppID != 0 && zegoAppSign.isNotEmpty;
