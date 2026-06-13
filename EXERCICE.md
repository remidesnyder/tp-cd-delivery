# Exercices - TP Cours-04 : Continuous Delivery avec GitHub Flow

## Contexte

La CI du depot est deja operationnelle : installation, formatage, lint, tests unitaires, tests E2E, build et scan de securite.

Votre mission est de completer la partie Continuous Delivery : versionner, publier un package npm dans Verdaccio, puis publier une image Docker dans un registre local `registry:2`.

Infrastructure disponible dans le DevContainer :

- API locale : `http://localhost:3000`
- Verdaccio : `http://localhost:4873`
- Docker Registry : `http://localhost:5000`
- Execution locale GitHub Actions : `act`

Avant de commencer :

```bash
curl http://localhost:4873/-/ping
curl http://localhost:5000/v2/
act -j security
```

Si un registre ne repond plus apres une veille du poste :

```bash
bash bin/check-relays.sh
```

## GitHub Flow full local

Le TP simule GitHub Flow sans dependance a GitHub.com :

```bash
git checkout main
git checkout -b feature/add-delivery-pipeline

# modifier .github/workflows/ci.yml
npm test
act -j security

git add .
git commit -m "feat: add delivery pipeline"

# simulation de PR locale
git diff main...HEAD

git checkout main
git merge --no-ff feature/add-delivery-pipeline
```

La suite CD se teste ensuite sur `main` :

```bash
act -j release
act -j publish-npm
act -j publish-docker
```

## Exercice 1 - job `release`

Objectif : calculer une version SemVer a partir des Conventional Commits.

Ajouter un job `release` dans `.github/workflows/ci.yml` :

- `needs: [security]`
- `if: github.ref == 'refs/heads/main'`
- checkout avec `fetch-depth: 0`
- setup Node.js 24
- restauration du cache `node_modules`
- configuration Git :
  ```bash
  git config user.email "ci@example.com"
  git config user.name "CI"
  ```
- execution :
  ```bash
  npx commit-and-tag-version
  ```

Solution :

```yaml
release:
  name: Release
  runs-on: ubuntu-latest
  needs: [security]
  if: github.ref == 'refs/heads/main'

  steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '24'

    - name: Restaurer le cache node_modules
      uses: actions/cache@v4
      with:
        path: node_modules
        key: node-modules-${{ hashFiles('package-lock.json') }}

    - name: Configurer git user
      run: |
        git config user.email "ci@example.com"
        git config user.name "CI"

    - name: Calculer la version
      run: npx commit-and-tag-version
```

Avec `act`, le commit et le tag sont crees dans le runner ephemere. Ils servent a comprendre le mecanisme, mais ne modifient pas automatiquement votre depot local.

## Exercice 2 - job `publish-npm`

Objectif : publier exactement l'artefact deja compile par le job `build`, sans recompiler.

Ajouter un job `publish-npm` :

- `needs: [release]`
- limite a `main`
- checkout + setup Node.js 24
- restauration du cache `node_modules`
- telechargement de `build-dist` dans `dist/`
- configuration npm :
  ```bash
  npm set //localhost:4873/:_authToken "dummy-token"
  ```
- publication :
  ```bash
  npm publish --registry http://localhost:4873
  ```

Solution :

```yaml
publish-npm:
  name: Publish npm
  runs-on: ubuntu-latest
  needs: [release]
  if: github.ref == 'refs/heads/main'

  steps:
    - uses: actions/checkout@v4

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '24'

    - name: Restaurer le cache node_modules
      uses: actions/cache@v4
      with:
        path: node_modules
        key: node-modules-${{ hashFiles('package-lock.json') }}

    - name: Telecharger le build
      uses: actions/download-artifact@v4
      with:
        name: build-dist
        path: dist/

    - name: Configurer Verdaccio
      run: npm set //localhost:4873/:_authToken "dummy-token"

    - name: Publier le package
      run: npm publish --registry http://localhost:4873
```

Verification :

```bash
act -j publish-npm
npm view tp-cd-github-flow --registry http://localhost:4873
```

Verdaccio refuse de publier deux fois la meme version. C'est normal : une version publiee est consideree comme immuable.

## Exercice 3 - job `publish-docker`

Objectif : publier en parallele une image de conteneur correspondant au meme code valide.

Ajouter un job `publish-docker` :

- `needs: [release]`
- limite a `main`
- checkout
- telechargement de `build-dist` dans `dist/`
- calcul de la version depuis `package.json`
- verification que le tag Docker n'existe pas encore
- build de l'image
- push vers `localhost:5000`

Solution :

```yaml
publish-docker:
  name: Publish Docker
  runs-on: ubuntu-latest
  needs: [release]
  if: github.ref == 'refs/heads/main'

  steps:
    - uses: actions/checkout@v4

    - name: Telecharger le build
      uses: actions/download-artifact@v4
      with:
        name: build-dist
        path: dist/

    - name: Calculer le tag Docker
      id: version
      run: |
        VERSION=$(node -p "require('./package.json').version")
        echo "version=${VERSION}" >> "$GITHUB_OUTPUT"

    - name: Verifier que le tag Docker n'existe pas
      run: |
        TAG="${{ steps.version.outputs.version }}"
        URL="http://localhost:5000/v2/tp-cd-github-flow/manifests/${TAG}"
        if curl -fsI \
          -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
          "$URL" > /dev/null; then
          echo "Le tag Docker ${TAG} existe deja dans le registry local."
          echo "Publier deux fois le meme tag masquerait l'image precedente."
          exit 1
        fi

    - name: Construire l'image
      run: docker build -t localhost:5000/tp-cd-github-flow:${{ steps.version.outputs.version }} .

    - name: Publier l'image
      run: docker push localhost:5000/tp-cd-github-flow:${{ steps.version.outputs.version }}
```

Verification :

```bash
act -j publish-docker
curl http://localhost:5000/v2/tp-cd-github-flow/tags/list
```

Contrairement a Verdaccio, `registry:2` accepte par defaut de pousser un tag Docker qui existe deja. Un tag Docker est une reference mutable vers un manifeste d'image : repusher `:0.0.1` peut donc faire pointer ce tag vers une nouvelle image. La verification ci-dessus rend le pipeline local plus strict en refusant de masquer une image deja publiee.

## Nettoyage des registres locaux

Les artefacts publies pendant le TP restent dans les volumes Docker de Verdaccio et du registre Docker. C'est pratique pour verifier les publications, mais cela peut bloquer un nouveau run si la meme version existe deja.

### Supprimer une version npm dans Verdaccio

Verdaccio refuse de publier deux fois la meme version. Pour supprimer une version precise :

```bash
npm unpublish tp-cd-github-flow@0.0.1 --registry http://localhost:4873 --force
```

Puis verifier :

```bash
npm view tp-cd-github-flow --registry http://localhost:4873
```

### Reinitialiser les deux registres locaux

La methode la plus simple pour un TP est de supprimer les volumes de stockage des registres :

```bash
docker compose down
docker volume rm tp-cd-github-flow_verdaccio-storage 2>/dev/null || true
docker volume rm tp-cd-github-flow_registry-storage 2>/dev/null || true
bash .devcontainer/start-registries.sh
```

Le registre Docker local ne supprime pas un tag de facon simple dans cette configuration TP. Le reset du volume `registry-storage` est donc la methode recommandee pour repartir proprement.

Puis verifier que les services repondent :

```bash
curl http://localhost:4873/-/ping
curl http://localhost:5000/v2/
```

Apres cette reinitialisation, les packages npm Verdaccio et les images Docker poussees dans `localhost:5000` ont ete supprimes.
