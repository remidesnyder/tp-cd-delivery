# Pipeline CI du TP

Le workflow `.github/workflows/ci.yml` est volontairement deja vert au debut du TP.

```text
install -> format-lint -> tests -> tests-e2e -> build -> security
```

Votre travail consiste a ajouter la suite Continuous Delivery :

```text
security -> release -> publish-npm
                    -> publish-docker
```

Dans la premiere partie du TP, cette suite est ajoutee directement sur `main`.
La branche courte n'arrive qu'ensuite, pour un petit fix applicatif rebase sur
`main` puis integre en fast-forward.

## Jobs initiaux

| Job | Role |
|---|---|
| `install` | Installe les dependances avec `npm ci` et prepare le cache `node_modules`. |
| `format-lint` | Verifie Prettier et ESLint/SonarJS. |
| `tests` | Lance les tests unitaires avec couverture. |
| `tests-e2e` | Lance les tests HTTP avec Supertest sur l'application NestJS en memoire. |
| `build` | Compile TypeScript vers `dist/` et sauvegarde l'artefact `build-dist`. |
| `security` | Lance Trivy sur le depot. Le scan informe mais ne bloque pas la pipeline. |

## Pourquoi sauvegarder `build-dist` ?

Les jobs GitHub Actions sont isoles. Le dossier `dist/` produit par `build` n'existe donc pas automatiquement dans `publish-npm` ou `publish-docker`.

Le workflow utilise :

- `actions/upload-artifact@v4` dans `build` ;
- `actions/download-artifact@v4` dans les jobs de publication.

Cela illustre le principe `build once, publish many` : le meme build sert au package npm et a l'image Docker.

## Conditions de branche

Les jobs ajoutes pendant le TP doivent etre limites a `main` :

```yaml
if: github.ref == 'refs/heads/main'
```

Une branche de feature doit donc valider la CI, mais ne doit pas publier de release ni d'artefact.

## `act` et release locale

Quand `act` lance le job `release`, `npx commit-and-tag-version` modifie le
clone Git present dans le runner ephemere. Le commit de release et le tag ne
sont pas recopies dans votre depot local.

Avant de coder une nouvelle modification apres un essai de release, lancez donc
la commande localement :

```bash
npx commit-and-tag-version
```

Vous repartez ainsi d'un `main` local aligne avec le bump de version et le
changelog attendus.
