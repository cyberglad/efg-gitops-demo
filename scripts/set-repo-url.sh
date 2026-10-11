#!/usr/bin/env bash
# Подставляет адрес твоей GitHub-репы во все Application-манифесты.
# Пример: ./scripts/set-repo-url.sh https://github.com/yurga/efg-gitops-demo.git
set -euo pipefail
URL=${1:?"Укажи URL репы: ./scripts/set-repo-url.sh https://github.com/<user>/efg-gitops-demo.git"}
cd "$(dirname "$0")/.."
sed -i "s#REPO_URL_PLACEHOLDER#${URL}#g" root-app.yaml apps-of-apps/*.yaml extras/*.yaml
grep -rn "repoURL" root-app.yaml apps-of-apps extras
