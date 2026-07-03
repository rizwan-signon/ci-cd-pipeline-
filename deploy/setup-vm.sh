#!/usr/bin/env bash
# Run this ONCE on a fresh Ubuntu VM to install Docker + Docker Compose.
# Usage: bash setup-vm.sh
set -e

sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Let your user run docker without sudo
sudo usermod -aG docker "$USER"

mkdir -p ~/practice-app

echo ""
echo "Setup complete."
echo "Log out and back in (or run 'newgrp docker') for the docker group to take effect."
echo "Next: create ~/practice-app/.env with DOCKERHUB_USERNAME=your-dockerhub-username"
