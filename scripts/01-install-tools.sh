#!/usr/bin/env bash
# Ставит docker, kubectl, kind, helm, yq, argocd CLI на Ubuntu.
set -euo pipefail

ARCH=$(dpkg --print-architecture)   # amd64 или arm64
echo ">>> Архитектура: $ARCH"

sudo apt-get update
command -v docker >/dev/null || sudo apt-get install -y docker.io; sudo apt-get install -y curl git ca-certificates
sudo usermod -aG docker "$USER"

# kubectl
KVER=$(curl -Ls https://dl.k8s.io/release/stable.txt)
curl -Lo /tmp/kubectl "https://dl.k8s.io/release/${KVER}/bin/linux/${ARCH}/kubectl"
sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl

# kind
curl -Lo /tmp/kind "https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-${ARCH}"
sudo install -m 0755 /tmp/kind /usr/local/bin/kind

# helm (нужен только для локального "helm template", ArgoCD рендерит сам)
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# yq — тот самый, которым Bamboo в EFG правил теги
curl -Lo /tmp/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${ARCH}"
sudo install -m 0755 /tmp/yq /usr/local/bin/yq

# argocd CLI (по желанию)
curl -Lo /tmp/argocd "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-${ARCH}"
sudo install -m 0755 /tmp/argocd /usr/local/bin/argocd

echo
echo ">>> Готово. ВАЖНО: перелогинься (или выполни 'newgrp docker'),"
echo ">>> чтобы docker работал без sudo."
