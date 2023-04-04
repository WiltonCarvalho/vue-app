### VUE Tarball Bootstrap
curl -fsSL https://github.com/WiltonCarvalho/vue-app/tarball/main | tar xvz --one-top-level=myapp --strip-components=1
cd myapp
export DOCKER_BUILDKIT=1
docker build -o . ./ -f ./Dockerfile.vue-bootstrap --progress=plain --target vue-bootstrap
docker-compose build --progress=plain
docker-compose up -d
google-chrome --incognito http://localhost:8080

### VUE Remote Bootstrap
docker build -o . https://raw.githubusercontent.com/WiltonCarvalho/vue-app/main/Dockerfile.vue-bootstrap --progress=plain
