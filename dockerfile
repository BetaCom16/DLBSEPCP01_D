FROM nginx:alpine

RUN rm /usr/share/nginx/html/index.html

COPY index.html /usr/share/nginx/html/index.html

COPY default.conf.template /etc/nginx/nginx.conf

CMD ["nginx", "-g", "daemon off;"]