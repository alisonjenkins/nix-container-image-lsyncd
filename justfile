# Build the container with Nix
build:
    #!/usr/bin/env bash
    set -euo pipefail

    nix build -o container_aarch64 '#.packages.x86_64-linux.container_aarch64' && \
        podman load < container_aarch64
    nix build -o container_x86_64 '#.packages.x86_64-linux.container_x86_64' && \
        podman load < container_x86_64

# Push the image
push tag:
    aws ecr get-login-password --profile alisonRW-script --region eu-west-1 | podman login --username AWS --password-stdin 918821718107.dkr.ecr.eu-west-1.amazonaws.com

    REPO="918821718107.dkr.ecr.eu-west-1.amazonaws.com/lsyncd"
    TAG="{{tag}}"
    podman manifest create --amend "$REPO:$TAG"
    podman manifest add "$REPO:$TAG" "localhost/lsyncd:latest-aarch64"
    podman manifest add "$REPO:$TAG" "localhost/lsyncd:latest-x86_64"
    podman manifest push --all --rm "$REPO:$TAG"

# Inspect the container
dive:
    dive podman://localhost/lsyncd:latest-x86_64

# Run the container
run:
    mkdir -p state tmp world
    podman run -it --rm -v "$(pwd)/world:/media/storage/world" -v "$(pwd)/state:/mnt/state/world" -v "$(pwd)/tmp:/tmp" localhost/lsyncd:latest-x86_64 /bin/lsync_world /media/storage/world /mnt/state/world

alias b := build
alias d := dive
alias r := run
