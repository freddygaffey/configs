#!/bin/sh
# Docker, for self-hosted services.
#
# Docker rather than podman: every self-hosting guide and almost every upstream
# project ships a docker-compose.yml, so this is the path with the least
# friction. Podman is the better design — rootless, no daemon — but it is only
# worth the compose translation if you are running untrusted code, and a
# single-user home server behind Tailscale is not that.
#
# Being in the `docker` group is root-equivalent, which is a real trade and the
# reason to keep this machine's services off the public internet by default.
#
# Undo: sudo apt remove docker-ce docker-ce-cli containerd.io
#       sudo deluser "$USER" docker
set -eu

# Docker's own repository: Debian and Ubuntu ship docker.io, which lags badly and
# does not include compose v2.
sudo install -m 0755 -d /etc/apt/keyrings
. /etc/os-release
curl -fsSL "https://download.docker.com/linux/$ID/gpg" \
    | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$ID $VERSION_CODENAME stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

# So you can run docker without sudo. Takes effect at your next login.
sudo usermod -aG docker "$USER"

# Containers come back after a reboot on their own, as long as each compose file
# says `restart: unless-stopped`. The daemon is a SYSTEM service, so unlike
# rootless podman there is no lingering to enable.
sudo systemctl enable --now docker

echo "docker installed. Log out and back in, then: docker compose version"
