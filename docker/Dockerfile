FROM nginx:alpine
COPY nginx.conf /etc/nginx/nginx.conf
COPY 40-h3xboard-config.sh /docker-entrypoint.d/40-h3xboard-config.sh
COPY html /usr/share/nginx/html
