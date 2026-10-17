# Candidature F-Droid

Application : org.poulapp.poulpoints ; version 0.8.1, code 22 ; licence MIT.
Dépôt : https://github.com/LouisLePoulpe/Poulpoints
Candidature en brouillon : https://gitlab.com/fdroid/fdroiddata/-/merge_requests/52699

La recette 0.8.0 a passé la CI GitLab. La recette 0.8.1 utilise le sous-module Flutter fixé, le commit complet de la livraison, les mises à jour par tags et les captures Fastlane fictives en français et anglais. Elle demande la conservation du certificat de production via Binaries et AllowedAPKSigningKeys.

Deux compilations locales indépendantes de la 0.8.1, l’une signée et l’autre non signée, ont donné les mêmes fichiers hors signatures. La commande apksigcopier compare --unsigned a réussi : la signature de production valide la seconde compilation. Le SDK et les chemins de compilation fixes éliminent les différences natives observées en 0.8.0.

Cette preuve locale ne remplace pas la validation dans l’environnement officiel F-Droid. La recette déplace temporairement le dépôt vers le même chemin fixe et ramène le cache des dépendances dans l’arbre pour le scanner. Ne pas désactiver globalement le scanner pour contourner un problème. La candidature reste en brouillon tant que la nouvelle CI et la revue ne sont pas terminées.

Références :
- https://f-droid.org/docs/Submitting_to_F-Droid_Quick_Start_Guide/
- https://f-droid.org/docs/Reproducible_Builds/
