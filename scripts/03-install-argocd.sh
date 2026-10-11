#!/usr/bin/env bash
set -euo pipefail
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo ">>> Жду, пока ArgoCD поднимется..."
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s

echo
echo ">>> Логин: admin"
echo -n ">>> Пароль: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
echo
echo ">>> UI: запусти в отдельном терминале"
echo "    kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ">>> и открой https://localhost:8080 (предупреждение о сертификате — нормально)"
