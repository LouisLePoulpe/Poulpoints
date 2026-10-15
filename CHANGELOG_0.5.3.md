# Poulpoints 0.5.3 — Synchronisation automatique et navigation simplifiée

## Changements

- Première synchronisation lancée automatiquement après la connexion Poulapp Cloud : aucune pression sur « Synchroniser » n'est requise.
- Changements locaux envoyés avec un délai de regroupement de 2 secondes après une sauvegarde réussie.
- Vérification des modifications distantes environ toutes les 60 secondes **lorsque l’application est ouverte et connectée** ; vérification à la reprise de l’application.
- Échec réseau : données locales conservées, nouvelle tentative automatique avec délais croissants (15, 30, 60, 120, 240 secondes) ; aucune boucle agressive.
- Conflit de versions non résolu : arrêt de la synchronisation automatique afin d'éviter tout écrasement ; relance manuelle disponible dans Paramètres.
- Une modification locale apparue pendant un transfert ne doit pas être remplacée par une réponse cloud plus ancienne.
- Les options cloud, sauvegardes, ancien serveur et apparence se trouvent désormais dans **Paramètres**, séparés de la navigation des tâches.
- Toutes les entrées du menu de gauche partagent la même indentation, hauteur, taille d'icône et style de sélection.
- Version mise à jour : `0.5.3+11`. Logo Poulpoints officiel inchangé. Modèle de données inchangé.

## Limites connues

- Le mot de passe et le jeton de rafraîchissement ne sont pas enregistrés. **Après fermeture complète et redémarrage, il faut encore se reconnecter au compte Poulapp**. Il faudra ultérieurement une conservation sécurisée des sessions.
- Pas de service de synchronisation permanent Android en arrière-plan. Un téléphone fermé ou en veille prolongée récupère les données après réouverture et connexion ; ne pas s'attendre à la synchronisation application complètement arrêtée.
- Sans notification réseau native, la reprise hors ligne est détectée au prochain essai périodique (typiquement dans la minute si l'application est active).
- Le protocole cloud expérimental peut laisser des écritures partielles sur erreur réseau et nécessiter une intervention. Sauvegarder avant d'essayer avec des données importantes.
- Flutter/analyse/compilation Android restent à effectuer sur Bazzite ; le code n'a pas été compilé dans l'environnement de préparation.
