# Préparation F-Droid

Préparé : licence MIT, sources, dépendances verrouillées, compilation sans signature de développement par défaut, descriptions français/anglais, icône officielle, changelog versionCode 19 et brouillon de recette.

Le fichier `.yml.in` est volontairement un modèle désactivé : il ne constitue pas une recette validée. Il manque le dépôt public, son commit de release et la vérification dans l’environnement de compilation F-Droid. La révision Flutter indiquée est celle du SDK local ; sa disponibilité dans les sources et outils F-Droid doit être vérifiée.

Avant soumission : compléter les URL, ajouter des captures avec données fictives, examiner les licences natives/transitives, exécuter le scanner et `fdroid lint`, puis compiler sur le buildserver. Adapter si nécessaire le srclib Flutter, les chemins PUB_CACHE et les règles du scanner. Ne pas contourner une erreur du scanner en ignorant largement les bibliothèques. La signature reproductible n’a pas été prouvée.

L’application ne contient pas de Firebase ni de services Google ajoutés pour les widgets, rappels ou le cloud. Elle fonctionne localement sans compte. Le cloud est facultatif, utilise Supabase et peut viser un serveur compatible choisi par l’utilisateur. L’inclusion dépend de l’examen F-Droid, pas de ce seul dossier.

Références vérifiées le 15 octobre 2026 :
- https://f-droid.org/docs/Submitting_to_F-Droid_Quick_Start_Guide/
- https://f-droid.org/docs/Inclusion_Policy/
