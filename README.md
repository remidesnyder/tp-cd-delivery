# tp-cd-github-flow

API de gestion de taches - support du TP cours-04 sur le Continuous Delivery avec GitHub Flow.

## Objectifs pedagogiques

Ce depot part d'une CI deja verte. Vous ajoutez la partie livraison :

- appliquer un GitHub Flow court et local ;
- versionner avec Conventional Commits et `commit-and-tag-version` ;
- publier un package npm dans Verdaccio ;
- publier une image Docker dans un registre local `registry:2` ;
- executer les workflows GitHub Actions localement avec `act`.

## Stack technique

| Outil | Role |
|---|---|
| Node 24 + NestJS 11 | API backend |
| better-sqlite3 | Base SQLite locale |
| Jest + Supertest | Tests unitaires et E2E |
| Prettier + ESLint | Qualite de code |
| Trivy | Scan de vulnerabilites |
| commit-and-tag-version | Versioning SemVer depuis les commits |
| Verdaccio | Registre npm local |
| registry:2 | Registre Docker local |
| act | Execution locale des workflows GitHub Actions |

## Demarrage recommande

Prerequis : Docker Desktop, VS Code et l'extension Dev Containers.

1. Forker le depot `GVI2026/tp-cd-github-flow` sur GitHub.
2. Cloner votre fork :
   ```bash
   git clone <url-de-votre-fork>
   cd tp-cd-github-flow
   ```
3. Ouvrir le dossier dans VS Code.
4. Accepter `Reopen in Container`.
5. Attendre la fin du `postCreateCommand`.

Le DevContainer installe les dependances, initialise SQLite, demarre Verdaccio et `registry:2`, installe `act` et precharge l'image runner.

## Services locaux

| Service | URL |
|---|---|
| API | http://localhost:3000 |
| Swagger | http://localhost:3000/api |
| Verdaccio | http://localhost:4873 |
| Docker Registry | http://localhost:5000/v2/ |

Commandes de verification :

```bash
curl http://localhost:4873/-/ping
curl http://localhost:5000/v2/
```

Si les relais reseau tombent apres une veille :

```bash
bash bin/check-relays.sh
```

## Lancer l'application

```bash
npm run start:dev
```

Routes principales :

| Methode | Route | Description |
|---|---|---|
| GET | `/health` | Healthcheck |
| GET | `/tasks` | Lister les taches |
| GET | `/tasks/:id` | Recuperer une tache |
| POST | `/tasks` | Creer une tache |
| PATCH | `/tasks/:id` | Mettre a jour |
| DELETE | `/tasks/:id` | Supprimer |

## Tests et CI locale

```bash
npm test
npm run test:e2e
act -j security
```

Pipeline initiale :

```text
install -> format-lint -> tests -> tests-e2e -> build -> security
```

Mission du TP :

```text
security -> release -> publish-npm
                    -> publish-docker
```

Deroule du TP :

- Partie 1 : travailler directement sur `main` pour ajouter les jobs CD manquants et les tester avec `act`.
- Partie 2 : appliquer localement la release avec `npx commit-and-tag-version`, puis faire un petit fix via branche courte, rebase et integration fast-forward.

Important : quand `npx commit-and-tag-version` est lance par `act`, le commit de release et le tag restent dans le runner ephemere. Ils ne sont pas visibles dans votre depot local. Pour continuer a coder apres un essai de release, lancez vous-meme `npx commit-and-tag-version` dans le DevContainer.

## Exercices

Les consignes detaillees sont dans [EXERCICE.md](./EXERCICE.md).

Commandes de fin de TP :

```bash
act -j release
act -j publish-npm
npm view tp-cd-github-flow --registry http://localhost:4873
act -j publish-docker
curl http://localhost:5000/v2/tp-cd-github-flow/tags/list
```

Integration locale de la branche de fix :

```bash
git checkout main
git checkout -b fix/swagger-description
# modifier une ligne dans src/main.ts
git add src/main.ts
git commit -m "fix: clarify api description"
git rebase main
git checkout main
git merge --ff-only fix/swagger-description
act -j security
```

## Nettoyer les registres locaux

Les publications locales sont conservees dans des volumes Docker. Si vous relancez le TP plusieurs fois, vous pouvez tomber sur une erreur du type "version deja publiee" cote npm, ou garder d'anciens tags Docker.

Pour supprimer une version npm precise dans Verdaccio :

```bash
npm unpublish tp-cd-github-flow@0.0.1 --registry http://localhost:4873 --force
```

Pour repartir de zero sur les deux registres locaux :

```bash
docker compose down
docker volume rm tp-cd-github-flow_verdaccio-storage 2>/dev/null || true
docker volume rm tp-cd-github-flow_registry-storage 2>/dev/null || true
bash .devcontainer/start-registries.sh
```

Le registre Docker local ne supprime pas un tag de facon simple dans cette configuration TP. Le reset du volume `registry-storage` est donc la methode recommandee pour repartir proprement.

Verifications apres nettoyage :

```bash
npm view tp-cd-github-flow --registry http://localhost:4873
curl http://localhost:5000/v2/tp-cd-github-flow/tags/list
```

## Documentation utile

- [docs/ci-pipeline.md](docs/ci-pipeline.md) : rappel de la CI.
- [docs/fonctionnement-cache.md](docs/fonctionnement-cache.md) : cache `node_modules`.
- [docs/artefacts-et-runners.md](docs/artefacts-et-runners.md) : passage du build aux publications.
