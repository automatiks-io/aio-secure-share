FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
COPY robots.txt /usr/share/nginx/html/robots.txt
RUN printf 'server {\n\
  listen 80;\n\
  root /usr/share/nginx/html;\n\
  add_header X-Robots-Tag "noindex, nofollow, nosnippet, noarchive" always;\n\
  add_header X-Content-Type-Options "nosniff" always;\n\
  add_header X-Frame-Options "DENY" always;\n\
  add_header Referrer-Policy "no-referrer" always;\n\
  add_header Permissions-Policy "camera=(), microphone=(), geolocation=(), payment=(), usb=()" always;\n\
  add_header Content-Security-Policy "default-src '"'"'none'"'"'; script-src '"'"'self'"'"' '"'"'unsafe-inline'"'"'; style-src '"'"'self'"'"' '"'"'unsafe-inline'"'"' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; img-src '"'"'self'"'"' https://automatiks.io data:; connect-src https://n8n.automatiksio.cloud https://pwpush.automatiks.io; form-action '"'"'self'"'"'; frame-ancestors '"'"'none'"'"'; base-uri '"'"'none'"'"'" always;\n\
  client_max_body_size 8k;\n\
  location / { try_files $uri /index.html; }\n\
}\n' > /etc/nginx/conf.d/default.conf
EXPOSE 80
