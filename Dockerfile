FROM --platform=amd64 docker.io/library/node:18-slim AS pre-build
WORKDIR /tmp/code
COPY ["package.json", "package-lock.json*", "yarn.lock", "./"]
RUN set -ex \
    && yarn install

FROM --platform=amd64 pre-build AS build-dev
WORKDIR /tmp/code
COPY . .
ARG NODE_ENV=production
RUN set -ex \
    && yarn build --mode development 2>/dev/null

FROM --platform=amd64 pre-build AS build-hml
WORKDIR /tmp/code
COPY . .
ARG NODE_ENV=production
RUN set -ex \
    && yarn build --mode staging 2>/dev/null

FROM --platform=amd64 pre-build AS build-prod
WORKDIR /tmp/code
COPY . .
ARG NODE_ENV=production
RUN set -ex \
    && yarn build --mode production 2>/dev/null

FROM scratch AS dev
COPY --from=build-dev /tmp/code/dist /dist/dev

FROM scratch AS hml
COPY --from=build-hml /tmp/code/dist /dist/hml

FROM scratch AS prod
COPY --from=build-prod /tmp/code/dist /dist/prod

FROM docker.io/nginxinc/nginx-unprivileged:stable AS base_image
RUN set -ex \
    && sed -i '1i server_tokens off;' /etc/nginx/conf.d/default.conf \
    && sed -i '2i add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";' /etc/nginx/conf.d/default.conf \
    && sed -i '3i add_header Referrer-Policy "no-referrer-when-downgrade";' /etc/nginx/conf.d/default.conf \
    && sed -i '4i add_header X-XSS-Protection "1; mode=block";' /etc/nginx/conf.d/default.conf \
    && sed -i '5i add_header X-Frame-Options "sameorigin";' /etc/nginx/conf.d/default.conf \
    && sed -i '6i add_header X-Content-Type-Options "nosniff";' /etc/nginx/conf.d/default.conf \
    && sed -i '7i add_header Set-Cookie "HttpOnly; Secure";' /etc/nginx/conf.d/default.conf \
    && sed -i '8i add_header Permissions-Policy "geolocation=(self), microphone=(), camera=()";' /etc/nginx/conf.d/default.conf \
    && sed -i '9i add_header Content-Security-Policy "default-src 'self'; img-src * data:; script-src *; font-src *; style-src *";' /etc/nginx/conf.d/default.conf \
    && sed -i '/location \//a if ( $http_user_agent ~* "HealthCheck" ) { access_log off; }' /etc/nginx/conf.d/default.conf \
    && sed -i '/location \//a if ( $http_user_agent ~* "ELB-HealthChecker" ) { access_log off; }' /etc/nginx/conf.d/default.conf \
    && sed -i '/location \//a if ( $http_user_agent ~* "^avi/" ) { access_log off; }' /etc/nginx/conf.d/default.conf \
    && sed -i '/location \//a if ( $http_user_agent ~* "kube-probe" ) { access_log off; }' /etc/nginx/conf.d/default.conf \
    && sed -i '/location \//a if ( $remote_addr ~* "127.0.0.1" ) { access_log off; }' /etc/nginx/conf.d/default.conf \
    && sed -i 's|index.*index.html.*|try_files $uri $uri/ /index.html;|g' /etc/nginx/conf.d/default.conf \
    && sed -i 's|access_log.*|access_log /var/log/nginx/access.log main;|g' /etc/nginx/nginx.conf
EXPOSE 8080

FROM base_image AS dev_image
COPY --from=build-dev /tmp/code/dist /usr/share/nginx/html

FROM base_image AS hml_image
COPY --from=build-hml /tmp/code/dist /usr/share/nginx/html

FROM base_image AS prod_image
COPY --from=build-prod /tmp/code/dist /usr/share/nginx/html

############
# Copy "dist" from build stage to current directory
# docker build -o . ./ -f ./Dockerfile --progress=plain --target dev
# docker build -o . ./ -f ./Dockerfile --progress=plain --target hml
# docker build -o . ./ -f ./Dockerfile --progress=plain --target prod

############
# Multi Arch
# docker run -d --rm --name registry -p 5000:5000 registry:2
# docker buildx create --name image-builder --use --driver docker-container --driver-opt network=host
# docker buildx build --platform=linux/amd64,linux/arm64/v8 --pull --push --tag 127.0.0.1:5000/image:dev --progress=plain . --target dev_image
# docker buildx build --platform=linux/amd64,linux/arm64/v8 --pull --push --tag 127.0.0.1:5000/image:hml --progress=plain . --target hml_image
# docker buildx build --platform=linux/amd64,linux/arm64/v8 --pull --push --tag 127.0.0.1:5000/image:prod --progress=plain . --target prod_image

# docker buildx build --platform=linux/amd64,linux/arm64/v8 --pull -o type=oci,dest=- --progress=plain . --target dev_image --sbom=false --provenance=false > /tmp/dev_image.tar
# skopeo inspect --raw oci-archive:/tmp/dev_image.tar | jq
