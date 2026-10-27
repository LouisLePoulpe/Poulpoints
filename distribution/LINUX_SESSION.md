# Connexion cloud persistante sous Linux / KDE

Poulpoints conserve le jeton de renouvellement dans le coffre-fort du système,
via Secret Service/libsecret. Aucun mot de passe ou jeton n'est enregistré en
clair dans les préférences de l'application.

Sur KDE, KWallet doit être activé et déverrouillé. Certains systèmes exposent
l'activation du service sous `org.kde.secretservicecompat` uniquement : Poulpoints
0.8.5 tente cette activation si aucun fournisseur Secret Service n'est présent.
Il ne modifie pas automatiquement les réglages du coffre-fort et ne remplace
pas un fournisseur déjà actif.

Si le coffre-fort est momentanément indisponible au démarrage, la restauration
est réessayée périodiquement et lorsque l'application revient au premier plan.
Une première tentative d'enregistrement échouée ne désactive plus définitivement
la conservation de la session. Les jetons renouvelés sont toujours enregistrés
avant les requêtes authentifiées suivantes.

Si une ancienne version n'avait jamais pu enregistrer la session, une connexion
manuelle est nécessaire une dernière fois après activation du coffre-fort.
Avec une ouverture automatique de session KDE, le coffre-fort peut demander son
propre déverrouillage : ne pas supprimer son mot de passe pour contourner cela.

Validation : tests de reprise après échec d'écriture, rotation des jetons,
restauration dans un nouveau client et déconnexion explicite. Un redémarrage
réel du PC reste nécessaire pour confirmer le fonctionnement de son déverrouillage
KDE/PAM propre à la machine.
