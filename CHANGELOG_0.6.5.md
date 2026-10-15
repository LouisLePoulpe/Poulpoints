# Poulpoints 0.6.5+18

- Linux : démarrage discret à l’ouverture de session, fermeture de fenêtre conservant le processus, activation de l’instance existante, synchronisation cloud chaque minute même fenêtre cachée.
- Reprise de la lecture de session si le coffre-fort Linux est indisponible au démarrage.
- Android : travail cloud unique périodique WorkManager, réseau requis, intervalle de 15 minutes soumis aux restrictions système. Aucun lancement d’activité par ce travail.
- Moteur Flutter, stockage et synchronisation partagés ; attente de fin du travail sans interface avant chargement de la fenêtre. Écritures locales et checkpoint atomiques.
- Trois tests du traitement sans interface : import/persistance/projection, coupure réseau et reprise, passage au traitement de l’interface.
- Règle R8 et contrôle DEX pour le constructeur du nouveau worker.
- Logo officiel, palettes du widget, données et protections de récurrence conservés. Aucune nouvelle dépendance.

Android : revenir à l’accueil programme également une tentative d’envoi persistante avec réseau disponible, afin de conserver les modifications faites juste avant la fermeture de la fenêtre.
