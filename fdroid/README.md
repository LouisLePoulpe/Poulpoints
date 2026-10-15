# Candidature F-Droid

Dépôt public : https://github.com/LouisLePoulpe/Poulpoints
Application : org.poulapp.poulpoints ; version 0.7.1, code 20 ; licence MIT.

La recette org.poulapp.poulpoints.yml a passé fdroid lint (fdroidserver 2.4.5) avec la configuration des catégories officielle. L’APK ARM64 signé en production a passé le scanner binaire F-Droid sans détection de classe propriétaire connue ni bloc de signature supplémentaire. La commande fdroid build --test --scan-binary --no-tarball a ensuite réussi localement dans Fedora/Distrobox depuis le tag public v0.7.1, avec le SDK Flutter téléchargé par la recette. Cela ne remplace pas encore une exécution sur le buildserver officiel.

Le scanner des sources et paquets téléchargés a réussi. Restent : confirmation dans le buildserver officiel, captures publiques fictives et accès GitLab pour soumettre la demande. Aucun dossier n’a encore été envoyé aux mainteneurs. Ne pas désactiver globalement le scanner pour contourner un problème.

La recette utilise une révision Flutter fixe et PUB_CACHE dans l’arbre scanné. La disponibilité de cette révision et des outils doit être confirmée par la construction indépendante. Le fichier .yml.in est un ancien brouillon conservé pour référence.

La comparaison locale des contenus ZIP hors META-INF trouve quatre fichiers natifs différents (libapp.so et trois libdartjni.so) : la reproductibilité n’est pas acquise. L’APK GitHub possède la signature de production Poulapp. Si F-Droid signe avec sa propre clé, les mises à jour entre les deux canaux ne seront pas directement interchangeables. Préférer étudier la reproductibilité avant la première publication F-Droid.

Références :
- https://f-droid.org/docs/Submitting_to_F-Droid_Quick_Start_Guide/
- https://f-droid.org/docs/Reproducible_Builds/
