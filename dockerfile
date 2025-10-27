FROM nginx:alpine

RUN apk add gettext

RUN rm /usr/share/nginx/html/index.html

COPY index.html /usr/share/nginx/html/index.html

COPY default.conf.template /etc/nginx/conf.d/default.conf.template

CMD ["/bin/sh", "-c", "envsubst '$PORT' < /etc/nginx/conf.d/default.conf.template > /tmp/default.conf && nginx -c /tmp/default.conf -g 'daemon off;'"]