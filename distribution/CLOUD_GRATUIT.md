# Cloud gratuit : 1 utilisateur aujourd’hui, 5 à 10 envisagés

## Offre et limites

Au 15 octobre 2026, la documentation Supabase indique 500 Mo de base par projet, 50 000 utilisateurs actifs mensuels et 5 Go de trafic sortant non mis en cache sur l’offre gratuite. Ce sont des quotas, pas une garantie de disponibilité ni de gratuité illimitée. Les quotas et les conditions de pause peuvent évoluer. Les autres applications Poulapp peuvent consommer le même budget.

Sources : https://supabase.com/pricing ; https://supabase.com/docs/guides/platform/billing-on-supabase ; https://supabase.com/docs/guides/platform/manage-your-usage/egress

## Réduction ajoutée en 0.7.0

Lorsque les données locales correspondent au dernier état synchronisé, le client demande seulement les identifiants, versions et marqueurs de suppression. Si rien n’a changé, il évite les contenus complets et leur deuxième lecture de vérification. Aucun changement SQL ni effacement de tâches terminées n’est nécessaire. Les changements continuent à utiliser les contrôles de conflit.

## Estimation, pas une mesure du compte réel

Hypothèse : 100 tâches/projets conservés par personne, 90 octets de métadonnées par enregistrement, Linux ouvert 8 h/jour (480 vérifications), Android 96 vérifications/jour, 30 jours. Environ 0,156 Go/personne/mois pour les seuls corps des métadonnées ; 0,78 Go pour 5 personnes, 1,56 Go pour 10. Les en-têtes, connexions, autorisations, synchronisations après modification, autres services et autres appareils sont en plus.

Avec Linux actif 24 h/24, ce même calcul atteint environ 0,415 Go/personne/mois, soit 4,15 Go pour 10 personnes avant tout supplément : trop près du quota pour promettre zéro coût. À 1 000 enregistrements/personne, multiplier ces volumes par dix. Les tâches terminées et marqueurs de suppression comptent aussi.

Le nombre de comptes ne sera donc probablement pas la première limite ; le volume des données et la fréquence d’actualisation sont plus importants. Pour 1 personne avec peu de tâches, commencer en Free est raisonnable. Pour 5–10, vérifier la consommation réelle avant d’annoncer un service gratuit durable.

## Exploitation proposée

Conserver l’accès sur invitation pour ce petit groupe. Examiner chaque semaine la taille de base et le trafic dans le tableau de bord Supabase ; fixer des seuils de suivi à 50 %, 75 % et 90 % du quota. Aucun accès au tableau de bord, aucune mesure ni alerte automatique réelle n’a été configuré pendant ce chantier.

Avant 75 %, déterminer la cause : clients actifs en permanence, gros historiques, autres applications. Prévoir une synchronisation différentielle côté serveur ou un intervalle ajustable avant d’augmenter le nombre d’utilisateurs. Ne pas supprimer les marqueurs de suppression sans protocole de rattrapage des appareils hors ligne.

Conserver des exports réguliers et préparer une sauvegarde serveur administrateur. Tester une restauration dans un environnement séparé. Ne pas conserver une clé service_role dans l’application. Le choix entre hébergement géré payant et auto-hébergement sera à réévaluer si les quotas sont dépassés ; l’auto-hébergement a lui aussi un coût d’entretien.
