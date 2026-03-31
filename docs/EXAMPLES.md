# Example Workflows

## Basic sync (recommended for most users)

Push source files and pull translations on every push to `main`. Creates a PR with the translation changes.

```yaml
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

## Upload only on push

Upload source files when they change — don't download anything.

```yaml
name: Upload sources to WTI
on:
  push:
    branches: [main]
    paths: ['config/locales/en.yml', 'config/locales/**/en.yml']

jobs:
  upload:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: webtranslateit/github-action@v1
        with:
          api_key: ${{ secrets.WTI_API_KEY }}
          upload_sources: true
          download_translations: false
```

## Download translations every 6 hours

Use a cron schedule to keep translations up-to-date.

```yaml
name: Download WTI Translations
on:
  schedule:
    - cron: '0 */6 * * *'
  workflow_dispatch:

jobs:
  download:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
      - uses: webtranslateit/github-action@v1
        with:
          api_key: ${{ secrets.WTI_API_KEY }}
          upload_sources: false
          download_translations: true
          create_pull_request: true
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Destructive push (override safe defaults)

By default the action pushes with `--merge --ignore-missing` so keys on WTI are never accidentally obsoleted. If you need the old destructive behaviour, clear the default flags:

```yaml
- uses: webtranslateit/github-action@v1
  with:
    api_key: ${{ secrets.WTI_API_KEY }}
    push_options: ''
```

## Push target files (translations)

Upload translated files alongside source files. Use with caution — target file uploads can overwrite translations done on WTI.

```yaml
- uses: webtranslateit/github-action@v1
  with:
    api_key: ${{ secrets.WTI_API_KEY }}
    upload_translations: true
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Pull specific locales only

Download only French translations.

```yaml
- uses: webtranslateit/github-action@v1
  with:
    api_key: ${{ secrets.WTI_API_KEY }}
    upload_sources: false
    pull_options: '--locale fr'
```

## Custom config file path

Point the action to a `.wti` file that lives in a non-default location.

```yaml
- uses: webtranslateit/github-action@v1
  with:
    api_key: ${{ secrets.WTI_API_KEY }}
    config: 'config/.wti'
```

## Using API key from `.wti` file directly

For **private repos** where the key is already committed in `.wti`, no secret is needed.

```yaml
- uses: webtranslateit/github-action@v1
  # No api_key input — reads from .wti file
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Full-featured example

Upload sources with merge, download translations, and create a PR with custom settings.

```yaml
name: WTI Full Sync
on:
  push:
    branches: [main]
  schedule:
    - cron: '0 4 * * *'
  workflow_dispatch:

jobs:
  sync:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4

      - uses: webtranslateit/github-action@v1
        id: wti
        with:
          api_key: ${{ secrets.WTI_API_KEY }}
          upload_sources: true
          upload_translations: false
          push_options: '--merge --minor'
          download_translations: true
          pull_options: '--force'
          localization_branch_name: 'l10n_latest'
          commit_message: 'chore: update translations'
          create_pull_request: true
          pull_request_title: '🌐 Translation update'
          pull_request_labels: 'localization, automated'
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Print PR URL
        if: steps.wti.outputs.pull_request_url
        run: echo "PR → ${{ steps.wti.outputs.pull_request_url }}"
```
