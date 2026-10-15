# Première diffusion publique 0.7.1

## Android ARM64

Le fichier Poulpoints_v0.7.1_Android_ARM64.apk utilise la clé de production Poulapp. Il ne peut pas mettre directement à jour les APK d’essai déjà installés : leur certificat est différent. Ne désinstallez pas votre version d’essai sans export vérifié et procédure de migration. Le Pixel de développement reste volontairement sur la version d’essai.

Pour une nouvelle installation, installer l’APK et autoriser les notifications selon les fonctions souhaitées. La synchronisation cloud est facultative et nécessite un serveur et un compte autorisé. Le cloud Poulapp personnel n’est pas un service d’inscription publique.

## Linux Bazzite KDE

Extraire Poulpoints_v0.7.1_Linux_Bazzite_KDE.tar.gz. Depuis Bazzite, hors du conteneur :

```sh
cd Poulpoints_v0.7.1
bash desktop/install.sh bundle
```

L’environnement Distrobox poulpoints-dev doit déjà contenir les bibliothèques nécessaires. Enregistrer toute modification et fermer l’ancienne instance résidente avant de démarrer la nouvelle. Le widget KDE inclut le correctif 0.7.1.2. Plasma peut nécessiter une reconnexion de session pour charger sa présentation.

## Fichiers et contrôle

SHA256SUMS contient les empreintes des fichiers de cette livraison. Les notices des dépendances sont dans l’archive source et le dossier distribution du paquet Linux. F-Droid n’a pas encore publié l’application.
