# Serveur MinIO + création automatique des buckets.
#
# Image de base : le build MinIO utilisé dans le cours (datascientest/minio, une version
# officielle de MinIO republiée sur Docker Hub). Elle fournit déjà `minio`, `mc` (le client
# MinIO) et `curl` dans /usr/bin, donc init_minio.sh n'a besoin de rien d'autre.
# Remarque : le dépôt amont `minio/minio` et les URL de téléchargement `dl.min.io` servant à
# récupérer `mc` ne sont plus fiables ; on ne télécharge donc volontairement RIEN ici.
FROM datascientest/minio:latest

# Le script passe par /tmp pour pouvoir retirer les fins de ligne Windows (CRLF) :
# sinon `#!/bin/sh\r` ferait échouer le conteneur avec « no such file or directory ».
# (l'image n'a pas `sed`, d'où `tr`)
COPY init_minio.sh /tmp/init_minio.sh
RUN tr -d '\r' < /tmp/init_minio.sh > /usr/local/bin/init_minio.sh \
    && chmod +x /usr/local/bin/init_minio.sh \
    && rm /tmp/init_minio.sh

# 9000 = API S3, 9001 = console web
EXPOSE 9000 9001
VOLUME ["/data"]

# Remplace l'entrypoint de l'image : init_minio.sh lance lui-même `minio server`, puis crée les buckets.
ENTRYPOINT ["/usr/local/bin/init_minio.sh"]