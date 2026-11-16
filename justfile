# https://just.systems

build:
    nix build

fix:
    podman run --rm -it \
        -v "$(pwd):/app:rw,Z" \
        -w /app \
        docker.io/library/node:24 \
        sh -c "npm ci && npm run lint:fix || npm run lint"
