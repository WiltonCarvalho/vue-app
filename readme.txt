export DOCKER_BUILDKIT=1
docker build -o . ./ -f ./Dockerfile.vue-bootstrap --progress=plain --target vue-bootstrap
docker-compose build --progress=plain
docker-compose up -d
google-chrome --incognito http://localhost:8080