# https://just.systems

build:
    podman run --rm -it \
        -v "$(pwd):/app:rw,Z" \
        -w /app \
        docker.io/library/node:24 \
        sh -c "npm ci && npm run lint"

test:
    podman run --rm -it \
        -p 127.0.0.1:8080:8080 \
        -v "$(pwd):/app:rw,Z" \
        -w /app \
        docker.io/library/node:24 \
        sh -c "npm ci && npm test"

fix:
    podman run --rm -it \
        -v "$(pwd):/app:rw,Z" \
        -w /app \
        docker.io/library/node:24 \
        sh -c "npm ci && npm run lint:fix || npm run lint"
