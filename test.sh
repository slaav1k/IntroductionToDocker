#!/bin/sh

set -e

buildFrontend() {
  DOCKER_BUILDKIT=1 docker build -f frontend.Dockerfile frontend/ --tag frontend:v1.0
}

buildBackend() {
  ./backend/gradlew clean build -p backend
  DOCKER_BUILDKIT=1 docker build -f backend.Dockerfile backend/ --tag backend:v1.0
}

createNetworks() {
  docker network create --driver=bridge network-backend
  docker network create --driver=bridge network-frontend
}

createVolume() {
  docker volume create postgres-data
}

runPostgres() {
  docker run -d \
    --name postgres \
    -p 5432:5432 \
    -e POSTGRES_USER=program \
    -e POSTGRES_PASSWORD=test \
    -e POSTGRES_DB=todo_list \
    --volume postgres-data:/var/lib/postgresql/data \
    --network=network-backend \
    --network-alias=postgres \
    postgres:13
}

runBackend() {
  docker run -d \
  -e SPRING_PROFILES_ACTIVE=docker \
  --name backend \
  --network=network-backend \
  backend:v1.0

  docker network connect --alias backend-service network-frontend backend
}

runFrontend() {
  docker run -d \
    --name frontend \
    -p 3000:80 \
    --network=network-frontend \
    frontend:v1.0
}

checkResult() {
  sleep 10
  http_response=$(
    docker exec \
      frontend \
      curl -s -o response.txt -w "%{http_code}" http://backend-service:8080/backend/api/v1/public/items
  )

  if [ "$http_response" != "200" ]; then
    echo "Check failed"
    exit 1
  fi
}

echo "=== Build backend backend:v1.0 ==="
buildBackend

echo "=== Build frontend frontend:v1.0 ==="
buildFrontend

echo "=== Create networks between backend <-> postgres and backend <-> frontend ==="
createNetworks

echo "=== Create persistence volume for postgres ==="
createVolume

echo "== Run Postgres ==="
runPostgres

echo "=== Run backend backend:v1.0 ==="
runBackend

echo "=== Run frontend frontend:v1.0L ==="
runFrontend

echo "=== Run check ==="
checkResult