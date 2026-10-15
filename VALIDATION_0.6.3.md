# Validation 0.6.3 — 14 octobre 2026

- APK Android ARM64 release 0.6.3+16 compilé.
- 11 tests Android Robolectric/API 35 réussis.
- Liste moderne : 81 éléments disponibles, défilement possible dans une petite surface et dernière position atteinte ; texte de la dernière ligne vérifié.
- 13 tâches restent accessibles après réduction, agrandissement puis réduction du widget.
- Filtre de liste et jeu vide vérifiés.
- Ancienne interface RemoteViewsFactory : 81 éléments, dernière ligne et changement de filtre vérifiés. Son hébergement sur un ancien appareil Android n’a pas été testé physiquement.
- Modèle de clic broadcast mutable explicite : ID et révision de la ligne reçus par la file authentifiée, sans Intent d’activité.
- Tests existants d’alarmes, doublons et authentification conservés.
- Contrôle du DEX de l’APK final réussi : constructeurs Room et Worker présents. Correction du plantage 0.6.1 conservée.
- Aucun changement Dart ni du format de données. Les 56 tests Flutter de la 0.6.2 ne sont pas présentés comme une nouvelle exécution ici.

Le Pixel n’était plus connecté à la finalisation. Aucun test physique du défilement ni installation de la 0.6.3 sur le téléphone pendant cette séance. Vérifier le geste de défilement et une validation en bas de liste sur le lanceur réel.

Référence : https://developer.android.com/develop/ui/views/appwidgets/collections
