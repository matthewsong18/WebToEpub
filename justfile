# https://just.systems

build:
    nix build

remote machine:
    ssh {{ machine }} 'cd ~/Projects/WebToEpub && just build'
    rsync -rvzL ms-pc:~/Projects/WebToEpub/result/ ./result/

fix:
    podman run --rm -it \
        -v "$(pwd):/app:rw,Z" \
        -w /app \
        docker.io/library/node:24 \
        sh -c "npm ci && npm run lint:fix || npm run lint"
