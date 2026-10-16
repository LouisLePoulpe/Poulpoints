# Inventaire des licences — 16 octobre 2026

Code Poulpoints : MIT. Inventaire de 99 paquets Dart (y compris outils et tests), chacun avec son texte de licence disponible. Les paquets du SDK Flutter renvoient à sa licence racine. Voir DART_LICENSE_INVENTORY.json et THIRD_PARTY_DART_LICENSES.txt.

L’arbre Android releaseRuntimeClasspath résout 101 coordonnées Maven. Leurs POM déclarent Apache-2.0 ou BSD-3-Clause ; ListenableFuture hérite sa licence du POM parent Guava 26.0-android. Les bibliothèques Google listées (Guava, Gson, Tink, annotations) ne sont pas les services propriétaires Google Play. Aucune dépendance Firebase ou Google Play Services n’a été relevée dans cet arbre. Voir ANDROID_LICENSE_INVENTORY.json.

Les notices embarquées trouvées dans les JAR/AAR sont conservées dans THIRD_PARTY_ANDROID_NOTICES.txt. Les notices générées par Flutter sont aussi incluses dans les binaires. Cet inventaire n’est pas une certification F-Droid : le scanner F-Droid et la compilation indépendante restent à vérifier, notamment pour le moteur Flutter et les outils de construction.

Les bibliothèques système Linux (GTK, GLib, etc.) sont fournies par la distribution ; le paquet n’embarque pas Distrobox ni Fedora.

L’inventaire Dart a été actualisé pour la 0.8.0 (file_selector et url_launcher inclus). L’inventaire Maven décrit la 0.7.1 et devra être réactualisé pour le dossier F-Droid ; les notices Flutter de la 0.8.0 sont embarquées dans les binaires.
