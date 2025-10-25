FROM nginx:alpine

RUN rm /usr/share/nginx/html/index.html

COPY index.html /usr/share/nginx/html/index.html

CMD ["/bin/sh", "-c", "envsubst < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"]

