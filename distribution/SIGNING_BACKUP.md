# Sauvegarde de la signature de production

La clé privée n’est jamais publiée. Son dossier local est ~/.local/share/poulpoints-signing (permissions 700), avec production.p12, signing.properties et password.txt (permissions 600 pour les secrets).

Avant de dépendre de cette clé pour des mises à jour publiques, conserver une copie de production.p12 sur un support indépendant chiffré et son mot de passe dans un gestionnaire de mots de passe. Ne pas envoyer ces fichiers dans une conversation ou un dépôt Git. Le certificat public et son empreinte SHA-256 ne sont pas secrets.

Une copie sur le même disque n’est pas une sauvegarde indépendante. Aucun support externe n’a encore été fourni ; cette sauvegarde reste à réaliser avec l’utilisateur. Ne pas supprimer la clé actuelle après copie : vérifier d’abord la lecture de la copie et l’empreinte du certificat.

L’APK d’essai utilise une autre clé. Le changement de canal implique une migration des données et ne doit jamais être testé par une désinstallation non préparée.
