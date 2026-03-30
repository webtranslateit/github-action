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
        with:
          api_key: ${{ secrets.WTI_API_KEY }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Inputs

| Input | Description | Default |
|-------|-------------|---------|
| `api_key` | WTI API key. Overrides value in `.wti`. Use `${{ secrets.WTI_API_KEY }}`. | — (read from `.wti`) |
| `config` | Path to the `.wti` config file | `.wti` |
| `upload_sources` | Push source files to WTI | `true` |
| `upload_translations` | Also push target (translated) files | `false` |
| `push_options` | Extra flags for `wti push` (e.g. `--merge --minor`) | `''` |
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

## Advanced Examples

See [docs/EXAMPLES.md](docs/EXAMPLES.md) for more workflow recipes:

- Upload only on push
- Scheduled download every 6 hours
- Push with `--merge --ignore-missing`
- Pull specific locales
- Custom config path
- Using the key from `.wti` directly

## License

[MIT](LICENSE)
