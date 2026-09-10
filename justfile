# https://just.systems

build:
    podman run --rm -it \
        -v "$(pwd):/app:rw,Z" \
        -w /app \
        docker.io/library/node:24 \
        sh -c "npm ci && npm run lint"
