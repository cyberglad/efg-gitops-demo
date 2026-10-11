#!/usr/bin/env bash
# Имитация Bamboo из EFG: yq меняет тег -> коммит -> пуш -> пинок ArgoCD.
# Пример: ./scripts/bamboo-bump.sh 1.28.0-alpine
set -euo pipefail
TAG=${1:?"Укажи тег: ./scripts/bamboo-bump.sh 1.28.0-alpine"}
cd "$(dirname "$0")/.."

yq -i ".image.tag = \"${TAG}\"" values/ds-egress/values.yaml
git add values/ds-egress/values.yaml
git commit -m "ds-egress: bump image to ${TAG} [bamboo-sim]"
git push

# В EFG Bamboo дёргал ArgoCD API. Здесь — аннотация "обновись сейчас",
# иначе ArgoCD сам заметит коммит в течение ~3 минут.
kubectl -n argocd annotate application ds-egress argocd.argoproj.io/refresh=hard --overwrite
echo ">>> Смотри: kubectl -n demo get pods -w"
