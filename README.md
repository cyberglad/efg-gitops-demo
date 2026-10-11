# EFG GitOps Demo — ArgoCD + app-of-apps на Ubuntu

Миниатюрная копия того, как был устроен GitOps в EFG: репа `argocd`,
головное приложение `ds-apps`, дочерние приложения через app-of-apps,
Helm-чарт + values, авто- и ручной sync, «Bamboo», который коммитит тег через `yq`.

## Что чему соответствует

| Здесь                              | В EFG                                             |
|------------------------------------|---------------------------------------------------|
| кластер `kind`                     | OpenShift (dev-ocp)                               |
| эта GitHub-репа                    | `devops/argocd.git` в Bitbucket                   |
| `root-app.yaml` → `ds-apps`        | головное приложение `ds-apps`                     |
| папка `apps-of-apps/`              | папка `apps-of-apps/` (например `gravitee.yml`)   |
| `charts/demo-nginx/`               | Helm-чарт в Nexus                                 |
| `values/ds-egress/values.yaml`     | values с тегом образа в репе `argocd`             |
| inline values в `gravitee.yaml`    | inline values Gravitee с лицензией                |
| `docker.io/library/nginx`          | `docker-registry.efgz.efg.corp/.../efg-ds-nginx`  |
| `scripts/bamboo-bump.sh`           | Bamboo: `yq` → commit → вызов ArgoCD API          |

Цепочка та же, четыре этажа:
`ds-apps` → создаёт Application → Application рендерит чарт+values → Deployment → под (образ качает kubelet).

---

## Шаг 0. Требования

Ubuntu 22.04/24.04, 4 ГБ свободной RAM, аккаунт на GitHub.

## Шаг 1. Установить инструменты

```bash
./scripts/01-install-tools.sh
newgrp docker        # или перелогиниться
docker ps            # должно работать без sudo
```

## Шаг 2. Свою Git-репу

ArgoCD должен откуда-то читать Git — это будет твоя публичная репа на GitHub.

1. Создай на GitHub пустую публичную репу `efg-gitops-demo` (без README).
2. Подставь её адрес во все манифесты и запушь:

```bash
./scripts/set-repo-url.sh https://github.com/<твой-логин>/efg-gitops-demo.git

git init -b main
git add .
git commit -m "initial: gitops demo"
git remote add origin https://github.com/<твой-логин>/efg-gitops-demo.git
git push -u origin main
```

(Для пуша по HTTPS GitHub попросит Personal Access Token вместо пароля.)

## Шаг 3. Кластер и ArgoCD

```bash
./scripts/02-create-cluster.sh
./scripts/03-install-argocd.sh     # в конце напечатает пароль admin
```

В отдельном терминале держи открытым UI:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Открой https://localhost:8080 → логин `admin` + пароль из скрипта.

## Шаг 4. Запустить матрёшку

Единственное, что делается руками, — головное приложение:

```bash
kubectl apply -f root-app.yaml
```

Дальше смотри в UI и в терминале:

```bash
kubectl -n argocd get applications      # появятся ds-apps, ds-egress, gravitee
kubectl -n demo get deploy,pods         # ds-egress поднялся сам (auto-sync)
kubectl -n gravitee get pods            # пусто! gravitee OutOfSync, ждёт ручного Sync
```

Вот она, асимметрия из EFG: `ds-egress` развернулся сам, а `gravitee` появился
как Application, но ничего не задеплоил — у него нет `automated`.

---

## Упражнения

### 1. Application — это просто объект Kubernetes

```bash
kubectl -n argocd get application gravitee -o yaml
```

Найди `source`, `destination`, `syncPolicy`. Потом посмотри, что он породил:

```bash
kubectl -n demo get deploy ds-egress -o yaml | grep image:
```

Application — бригадир с нарядом, Deployment — бригада.

### 2. Ручной Sync (как у Gravitee)

В UI открой `gravitee` → кнопка **SYNC** → **SYNCHRONIZE**. Или:

```bash
argocd login localhost:8080 --username admin --insecure
argocd app sync gravitee
kubectl -n gravitee get pods,cm
kubectl -n gravitee get cm gravitee-config -o yaml   # тут "лицензия"
```

### 3. «Bamboo» выкатывает новую версию

```bash
./scripts/bamboo-bump.sh 1.28.0-alpine
kubectl -n demo get pods -w           # rolling update: новые поды, старые уходят
kubectl -n demo get deploy ds-egress -o jsonpath='{..image}'; echo
```

Обрати внимание: ArgoCD образ не качает. Он обновил Deployment, а образ
скачал kubelet на ноде — видно в событиях:

```bash
kubectl -n demo get events --sort-by=.lastTimestamp | grep -i pull
```

### 4. Почему PR в обход Bamboo бесполезен (история PR #364)

Поправь тег в `values/ds-egress/values.yaml` руками на `1.27.5-alpine`,
закоммить, запушь — ArgoCD откатит. А потом запусти
`./scripts/bamboo-bump.sh 1.28.0-alpine` — и твоя правка перезатёрта.
Кто последний коммитит в Git — тот и прав.

### 5. Self-heal: ручные правки в кластере не живут

```bash
kubectl -n demo scale deploy ds-egress --replicas=5
kubectl -n demo get pods -w           # через несколько секунд снова 2
```

А теперь то же с `gravitee` (selfHeal нет):

```bash
kubectl -n gravitee scale deploy gravitee --replicas=3
```

Поды останутся, приложение станет OutOfSync и будет ждать человека.

### 6. Воспроизвести проблему `ds-egress` + `ignoreDifferences`

Добавь в `apps-of-apps/ds-egress.yaml` внутрь `spec:`:

```yaml
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/template/spec/containers/0/image
```

Закоммить, запушь. Потом `./scripts/bamboo-bump.sh 1.27.5-alpine`.
ArgoCD покажет **Synced**, а образ в кластере старый — разница по
образу игнорируется, значит и синкать «нечего». Ровно поэтому в EFG
приходилось делать `oc set image`. Здесь аналог:

```bash
kubectl -n demo set image deploy/ds-egress nginx=docker.io/library/nginx:1.27.5-alpine
```

После упражнения убери блок `ignoreDifferences` обратно.

### 7. Добавить сервис одним файлом

```bash
cp extras/techradar.yaml apps-of-apps/
git add apps-of-apps/techradar.yaml && git commit -m "add techradar" && git push
kubectl -n argocd annotate application ds-apps argocd.argoproj.io/refresh=hard --overwrite
kubectl -n argocd get applications     # techradar родился сам
```

### 8. Удалить сервис одним файлом (prune)

```bash
git rm apps-of-apps/techradar.yaml && git commit -m "remove techradar" && git push
```

У `ds-apps` включён `prune: true` — Application `techradar` исчезнет.
Важно: без finalizer на дочернем Application его ресурсы (Deployment)
могут остаться в кластере. Проверь `kubectl -n demo get deploy` и
почитай про `resources-finalizer.argocd.argoproj.io` — частый вопрос на собеседованиях.

### 9. Посмотреть рендер глазами (что делает ArgoCD в памяти)

```bash
helm template ds-egress charts/demo-nginx -f values/ds-egress/values.yaml
```

Это ровно то, что ArgoCD склеивает из чарта и values перед сравнением с кластером.

---

## Если что-то не так

- **Application в статусе Unknown / ComparisonError** — проверь, что репа публичная
  и `repoURL` подставлен (`grep repoURL -r .`).
- **ArgoCD не видит коммит** — он опрашивает Git раз в ~3 минуты. Ускорить:
  `kubectl -n argocd annotate application <имя> argocd.argoproj.io/refresh=hard --overwrite`
- **ImagePullBackOff** — опечатка в теге; проверь, что тег есть на Docker Hub.

## Удалить всё

```bash
./scripts/cleanup.sh
```
