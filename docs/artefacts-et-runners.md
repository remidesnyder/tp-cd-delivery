# Artefacts et runners locaux

Un job GitHub Actions ne partage pas son systeme de fichiers avec les autres jobs. Pour transmettre le resultat du build a un job de publication, le workflow utilise donc `actions/upload-artifact` puis `actions/download-artifact`.

Dans ce TP, `act` execute les jobs dans des conteneurs locaux. Les registres sont exposes sur `localhost` grace a `.actrc` et aux relais lances par le DevContainer.

Repere important :

- `build` compile l'application et sauvegarde `dist/`.
- `publish-npm` publie ce `dist/` dans Verdaccio.
- `publish-docker` construit une image avec le meme `dist/` et la pousse dans `registry:2`.

Le principe a retenir est `build once, publish many` : on ne recompile pas separement pour chaque format d'artefact.

## Runner `act` et depot local

Un runner `act` est ephemere. Il clone le depot, execute le job, puis disparait.
Si le job `release` lance `npx commit-and-tag-version`, les modifications de
`package.json`, `CHANGELOG.md` et le tag Git restent dans ce runner. Elles ne
sont pas visibles dans votre DevContainer.

Pour continuer le TP apres une release simulee, lancez vous-meme :

```bash
npx commit-and-tag-version
```

Cette commande realigne votre depot local avant de creer une branche courte et
de rebaser votre fix sur `main`.

## Immutabilite des publications

Une version npm publiee dans Verdaccio est immuable : publier deux fois `tp-cd-github-flow@0.0.1` est refuse.

Un tag Docker est different. Dans le registre Docker officiel `registry:2`, un tag comme `localhost:5000/tp-cd-github-flow:0.0.1` est une reference mutable vers un manifeste d'image. Pousser une nouvelle image avec le meme tag deplace cette reference et masque l'image precedente.

Pour obtenir un comportement proche de npm dans ce TP, le job `publish-docker` verifie l'existence du tag via l'API Registry avant de pousser. Si le tag existe deja, le job echoue. Dans une vraie plateforme, on peut aussi utiliser un registre qui supporte les tags immuables, par exemple Harbor, GitLab Container Registry ou une politique d'immutabilite cote cloud registry.
