#!/bin/bash
set -e

info()  { echo -e "\033[1;34m[INFO]\033[0m $*"; }
ARCH=$(uname -m)

info "Installing prerequisites..."
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg


info "Installing docker..." # https://docs.docker.com/engine/install/debian/
if [ ! -f /etc/apt/keyrings/docker.asc ]; then
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
fi

if ! grep -q "download.docker.com" /etc/apt/sources.list.d/docker.list 2>/dev/null; then
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
fi

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl start docker && info "Docker started"


info "Installing kubectl..." # https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
if [ ! -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]; then
  sudo mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
fi

if ! grep -q "pkgs.k8s.io" /etc/apt/sources.list.d/kubernetes.list 2>/dev/null; then
  echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
  sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list
fi

sudo apt-get update
sudo apt-get install -y kubectl


info "Installing k3d..." # https://k3d.io/stable/#releases
if ! command -v k3d > /dev/null 2>&1; then
  wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

if ! sudo k3d cluster list | grep -q inception-of-things; then
  info "Creating k3d cluster 'inception-of-things'..."
  sudo k3d cluster create inception-of-things --servers 1 -p "80:80@server:0" -p "443:443@server:0" --wait || true
fi

sudo kubectl get nodes


info "Installing argocd cmdline tool"
if ! command -v argocd > /dev/null 2>&1; then
  if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    ARGOCD_URL="https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-arm64"
  else
    ARGOCD_URL="https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
  fi
  curl -sSL -o /tmp/argocd-linux $ARGOCD_URL
  curl -sSL -o /tmp/argocd-linux $ARGOCD_URL
  sudo install -m 555 /tmp/argocd-linux /usr/local/bin/argocd
  rm /tmp/argocd-linux
fi

info "Installation completed!"
