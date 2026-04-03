FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
# SPA-style: all routes serve index.html (hash routing)
RUN echo 'server { listen 80; root /usr/share/nginx/html; location / { try_files $uri /index.html; } }' > /etc/nginx/conf.d/default.conf
EXPOSE 80
