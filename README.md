# WebTranslateIt GitHub Action

Synchronize translation files between your GitHub repository and your [WebTranslateIt](https://webtranslateit.com) project. Upload source files, download translations, and automatically open a pull request — all powered by the official [`wti` CLI](https://github.com/webtranslateit/webtranslateit).

## Prerequisites

1. A WebTranslateIt project with an API key.
2. A `.wti` configuration file in your repository (created by `wti init`).

## Quick Start

```yaml
# .github/workflows/wti-sync.yml
name: WTI Sync
on:
  push:
    branches: [main]

jobs:
  sync:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
      - uses: webtranslateit/github-action@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Inputs

| Input | Description | Default |
|-------|-------------|---------|
| `api_key` | WTI API key. If not provided, the key is read from the `.wti` config file. | — (read from `.wti`) |
| `config` | Path to the `.wti` config file | `.wti` |
| `upload_sources` | Push source files to WTI | `true` |
| `upload_translations` | Also push target (translated) files | `false` |
| `push_options` | Flags for `wti push` (see [Safe Sync Model](#safe-sync-model)) | `'--merge --ignore-missing'` |
| `download_translations` | Pull translations from WTI | `true` |
| `pull_options` | Extra flags for `wti pull` (e.g. `--force --locale fr`) | `''` |
| `push_translations` | Commit & push downloaded translations | `true` |
| `localization_branch_name` | Branch name for commits | `l10n_wti_translations` |
| `commit_message` | Commit message | `New translations from WebTranslateIt` |
| `create_pull_request` | Create or update a PR | `true` |
| `pull_request_title` | PR title | `New translations from WebTranslateIt` |
| `pull_request_body` | PR body | *(link to this action)* |
| `pull_request_labels` | Comma-separated PR labels | `localization` |
| `pull_request_base_branch_name` | Base branch for PR | *(repo default)* |

## Outputs

| Output | Description |
|--------|-------------|
| `pull_request_url` | URL of the created / updated PR |
| `pull_request_number` | Number of the created / updated PR |

## Using the Existing `.wti` File

If your repository already has a `.wti` file (from running `wti init` locally), the action reads it automatically — including locale filters, file ignore patterns, and hooks. You only need to supply the API key via a GitHub secret:

```yaml
- uses: webtranslateit/github-action@v1
  with:
    api_key: ${{ secrets.WTI_API_KEY }}
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

The action merges the secret `api_key` into your `.wti` at runtime so the `wti` CLI can use it. Your committed `.wti` is never modified in the resulting PR.

## Securing the API Key

For **private repos** the key can live directly in `.wti`. For **public repos** (or as a best practice), store it as a GitHub secret:

1. Go to **Settings → Secrets and variables → Actions**.
2. Create a secret named `WTI_API_KEY` with your project API key.
3. Remove (or leave blank) the `api_key` line in your `.wti` file.

Priority order: action input `api_key` → env var `WTI_API_KEY` → `.wti` file.

## Permissions

The workflow needs these permissions to commit translations and manage PRs:

```yaml
permissions:
  contents: write
  pull-requests: write
```

## Safe Sync Model

By default, source files are pushed with `--merge --ignore-missing`:

- **`--merge`** — new keys in the file are added to WTI; existing translations are not overwritten.
- **`--ignore-missing`** — keys present on WTI but absent from the uploaded file are left alone (not obsoleted).

This means pushes are **additive** — they can add or update keys, but never delete. Translations done on WTI are never lost by a push.

### Why this matters

Without these flags, pushing a source file that is missing keys (e.g. because a translator added them on WTI and the developer hasn't pulled yet) would silently obsolete those keys and lose their translations.

### Target file uploads

Target file push (`upload_translations: true`) uploads translated files alongside source files. Use this with caution: target file uploads **can overwrite translations** done on WTI, because they replace the full translation content. Only enable this if you are sure your local translations are up to date.

```yaml
- uses: webtranslateit/github-action@v1
  with:
    upload_translations: true
    push_options: '--merge --ignore-missing'
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Overriding the defaults

If you want the old destructive behaviour (keys missing from the file get obsoleted), clear the default flags:

```yaml
- uses: webtranslateit/github-action@v1
  with:
    push_options: ''
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Recommended Workflow

1. Developer adds keys and source text (e.g. English) in code, commits, pushes to the default branch.
2. The action pushes the source file to WTI (safe merge — adds new keys, never deletes).
3. Translators translate on the WTI web interface.
4. The action pulls translations back and opens a pull request.
5. The team merges the PR to get translations into the codebase.

Developers can run `wti pull` locally to preview translations during development, but should never run `wti push` — the action is the sole writer to WTI.

## Advanced Examples

See [docs/EXAMPLES.md](docs/EXAMPLES.md) for more workflow recipes:

- Upload only on push
- Scheduled download every 6 hours
- Destructive push (override safe defaults)
- Push target files (translations)
- Pull specific locales
- Custom config path
- Using the key from `.wti` directly

## License

[MIT](LICENSE)
