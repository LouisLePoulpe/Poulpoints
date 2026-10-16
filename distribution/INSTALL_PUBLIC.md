# Poulpoints 0.8.0 — Installation

Android ARM64 : installer Poulpoints_v0.8.0_Android_ARM64.apk. Cet APK est signé avec le certificat de production, comme celui de GitHub 0.7.1. Il ne remplace pas directement un APK personnel signé pour les essais : ne pas désinstaller ce dernier ni effacer ses données ; utiliser l’APK d’essai fourni séparément dans la conversation pour cette installation.

Linux Bazzite/KDE : extraire l’archive, puis lancer `bash desktop/install.sh bundle` depuis le dossier extrait, hors Distrobox. L’environnement `poulpoints-dev` doit déjà exister. Enregistrer les modifications, quitter entièrement l’ancienne instance (la fermeture de fenêtre peut la laisser en arrière-plan), puis relancer depuis le menu. Ce paquet est destiné à Bazzite avec l’environnement Fedora/Distrobox existant, pas à toutes les distributions Linux.

Pièces jointes : ouvrir une tâche enregistrée, descendre sous les notes et choisir « Ajouter une pièce jointe ». Connexion au cloud nécessaire, 10 Mo par fichier. Terminer la tâche supprime sa copie cloud après synchronisation ; le fichier original reste intact. Pour une instance auto-hébergée, déployer les migrations et la fonction décrites dans ATTACHMENTS.md.
