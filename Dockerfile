FROM --platform=amd64 docker.io/library/node:12 as pre-build
WORKDIR /tmp/code
COPY ["package.json", "package-lock.json*", "yarn.lock", "./"]
RUN set -ex \
    && yarn install

FROM --platform=amd64 pre-build as build-dev
WORKDIR /tmp/code
COPY . .
RUN set -ex \
    && yarn build --mode development 2>/dev/null

FROM --platform=amd64 pre-build as build-hml
WORKDIR /tmp/code
COPY . .
RUN set -ex \
    && yarn build --mode staging 2>/dev/null

FROM --platform=amd64 pre-build as build-prod
WORKDIR /tmp/code
COPY . .
RUN set -ex \
    && yarn build --mode production 2>/dev/null

FROM scratch as dev
COPY --from=build-dev /tmp/code/dist /dist/dev

FROM scratch as hml
COPY --from=build-hml /tmp/code/dist /dist/hml

FROM scratch as prod
COPY --from=build-prod /tmp/code/dist /dist/prod

# export DOCKER_BUILDKIT=1
# docker build -o . ./ -f ./Dockerfile --progress=plain --target dev
# docker build -o . ./ -f ./Dockerfile --progress=plain --target hml
# docker build -o . ./ -f ./Dockerfile --progress=plain --target prod

FROM docker.io/nginxinc/nginx-unprivileged:stable AS dev_image
COPY --from=build-dev /tmp/code/dist /usr/share/nginx/html
RUN set -ex \
    && sed -i '1i server_tokens off;' /etc/nginx/conf.d/default.conf \
    && sed -i '/location \//a if ( $http_user_agent ~* "HealthCheck" ) { access_log off; }' /etc/nginx/conf.d/default.conf \
    && sed -i '/location \//a if ( $http_user_agent ~* "ELB-HealthChecker" ) { access_log off; }' /etc/nginx/conf.d/default.conf \
    && sed -i '/location \//a if ( $remote_addr ~* "127.0.0.1" ) { access_log off; }' /etc/nginx/conf.d/default.conf \
    && sed -i 's|index.*index.html.*|try_files $uri $uri/ /index.html;|g' /etc/nginx/conf.d/default.conf \
    && sed -i 's|access_log.*|access_log /var/log/nginx/access.log main;|g' /etc/nginx/nginx.conf
EXPOSE 8080

FROM docker.io/nginxinc/nginx-unprivileged:stable AS hml_image
COPY --from=build-hml /tmp/code/dist /usr/share/nginx/html
RUN set -ex \
    && sed -i '1i server_tokens off;' /etc/nginx/conf.d/default.conf \
    && sed -i '/location \//a if ( $http_user_agent ~* "HealthCheck" ) { access_log off; }' /etc/nginx/conf.d/default.conf \
    && sed -i '/location \//a if ( $http_user_agent ~* "ELB-HealthChecker" ) { access_log off; }' /etc/nginx/conf.d/default.conf \
    && sed -i '/location \//a if ( $remote_addr ~* "127.0.0.1" ) { access_log off; }' /etc/nginx/conf.d/default.conf \
    && sed -i 's|index.*index.html.*|try_files $uri $uri/ /index.html;|g' /etc/nginx/conf.d/default.conf \
    && sed -i 's|access_log.*|access_log /var/log/nginx/access.log main;|g' /etc/nginx/nginx.conf
EXPOSE 8080

FROM docker.io/nginxinc/nginx-unprivileged:stable AS prod_image
COPY --from=build-prod /tmp/code/dist /usr/share/nginx/html
RUN set -ex \
    && sed -i '1i server_tokens off;' /etc/nginx/conf.d/default.conf \
    && sed -i '/location \//a if ( $http_user_agent ~* "HealthCheck" ) { access_log off; }' /etc/nginx/conf.d/default.conf \
    && sed -i '/location \//a if ( $http_user_agent ~* "ELB-HealthChecker" ) { access_log off; }' /etc/nginx/conf.d/default.conf \
    && sed -i '/location \//a if ( $remote_addr ~* "127.0.0.1" ) { access_log off; }' /etc/nginx/conf.d/default.conf \
    && sed -i 's|index.*index.html.*|try_files $uri $uri/ /index.html;|g' /etc/nginx/conf.d/default.conf \
    && sed -i 's|access_log.*|access_log /var/log/nginx/access.log main;|g' /etc/nginx/nginx.conf
EXPOSE 8080

# export DOCKER_BUILDKIT=1
# docker build -t test-dev . -f ./Dockerfile --progress=plain --target dev_image
# docker build -t test-hml . -f ./Dockerfile --progress=plain --target hml_image
# docker build -t test-prod . -f ./Dockerfile --progress=plain --target prod_image
