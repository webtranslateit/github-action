#!/bin/bash
set -euo pipefail

# ─── Helpers ────────────────────────────────────────────────────────────────────

# Sanitize user-provided CLI options: allow only flags, alphanumerics, dashes,
# dots, underscores, commas, spaces, and forward slashes. Reject anything else
# (prevents shell injection via push_options / pull_options).
sanitize_options() {
  local opts="$1"
  if [[ "$opts" =~ [^a-zA-Z0-9\ _.,:/-] ]]; then
    echo "::error::Invalid characters in options: $opts"
    exit 1
  fi
  echo "$opts"
}

# ─── Step 0: Resolve and mask the API key ────────────────────────────────────

API_KEY="${INPUT_API_KEY:-${WTI_API_KEY:-}}"
CONFIG_PATH="${INPUT_CONFIG:-.wti}"

# Fall back to the .wti file if no key was passed explicitly
if [ -z "$API_KEY" ] && [ -f "$CONFIG_PATH" ]; then
  API_KEY=$(grep -E '^api_key:' "$CONFIG_PATH" | head -1 | awk '{print $2}' | tr -d "\"'")
fi

if [ -z "$API_KEY" ]; then
  echo "::error::No API key provided. Set the api_key input, WTI_API_KEY env var, or add it to your .wti file."
  exit 1
fi

# Mask the key so it never appears in logs
echo "::add-mask::$API_KEY"

# Write / patch the .wti config so `wti` can read it
if [ -n "${INPUT_API_KEY:-${WTI_API_KEY:-}}" ]; then
  if [ -f "$CONFIG_PATH" ]; then
    sed -i "s/^api_key:.*$/api_key: ${API_KEY}/" "$CONFIG_PATH"
  else
    echo "api_key: $API_KEY" > "$CONFIG_PATH"
  fi
fi

# ─── Step 1: Upload source files ─────────────────────────────────────────────

if [ "${INPUT_UPLOAD_SOURCES:-true}" = "true" ]; then
  echo "::group::Pushing source files to WebTranslateIt"

  PUSH_ARGS=("push" "--config" "$CONFIG_PATH")

  if [ "${INPUT_UPLOAD_TRANSLATIONS:-false}" = "true" ]; then
    PUSH_ARGS+=("--target")
  fi

  if [ -n "${INPUT_PUSH_OPTIONS:-}" ]; then
    SAFE_OPTS=$(sanitize_options "$INPUT_PUSH_OPTIONS")
    # Word-split is intentional here for CLI flags
    # shellcheck disable=SC2206
    PUSH_ARGS+=($SAFE_OPTS)
  fi

  echo "Running: wti ${PUSH_ARGS[*]}"
  wti "${PUSH_ARGS[@]}" || echo "::warning::Push encountered errors (exit code $?)"

  echo "::endgroup::"
fi

# ─── Step 2: Download translations ───────────────────────────────────────────

if [ "${INPUT_DOWNLOAD_TRANSLATIONS:-true}" = "true" ]; then
  echo "::group::Pulling translations from WebTranslateIt"

  PULL_ARGS=("pull" "--config" "$CONFIG_PATH")

  if [ -n "${INPUT_PULL_OPTIONS:-}" ]; then
    SAFE_OPTS=$(sanitize_options "$INPUT_PULL_OPTIONS")
    # shellcheck disable=SC2206
    PULL_ARGS+=($SAFE_OPTS)
  fi

  echo "Running: wti ${PULL_ARGS[*]}"
  wti "${PULL_ARGS[@]}" || echo "::warning::Pull encountered errors (exit code $?)"

  echo "::endgroup::"
fi

# ─── Step 3: Git — commit & push ─────────────────────────────────────────────

if [ "${INPUT_PUSH_TRANSLATIONS:-true}" != "true" ]; then
  echo "push_translations is disabled — skipping git operations"
  exit 0
fi

if git diff --quiet; then
  echo "No translation changes detected"
  exit 0
fi

echo "::group::Committing translation changes"

git config user.name "WebTranslateIt"
git config user.email "support@webtranslateit.com"

BRANCH="${INPUT_LOCALIZATION_BRANCH_NAME:-l10n_wti_translations}"
BASE="${INPUT_PULL_REQUEST_BASE_BRANCH_NAME:-}"

if [ -z "$BASE" ]; then
  BASE=$(git remote show origin | grep 'HEAD branch' | sed 's/.*: //')
fi

# Create or reset localisation branch from current HEAD
git checkout -B "$BRANCH"

# Stage everything, then un-stage the config file so we never commit secrets
git add -A
git reset HEAD "$CONFIG_PATH" 2>/dev/null || true

if git diff --cached --quiet; then
  echo "No translation changes to commit after staging"
  echo "::endgroup::"
  exit 0
fi

git commit -m "${INPUT_COMMIT_MESSAGE:-New translations from WebTranslateIt}"
git push origin "$BRANCH" --force

echo "::endgroup::"

# ─── Step 4: Create / update Pull Request ─────────────────────────────────────

if [ "${INPUT_CREATE_PULL_REQUEST:-true}" != "true" ]; then
  exit 0
fi

echo "::group::Managing Pull Request"

GITHUB_API="https://api.github.com"

# Check for an existing open PR from the localisation branch
EXISTING_PR=$(curl -sf \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "${GITHUB_API}/repos/${GITHUB_REPOSITORY}/pulls?head=${GITHUB_REPOSITORY_OWNER}:${BRANCH}&base=${BASE}&state=open")

PR_COUNT=$(echo "$EXISTING_PR" | jq 'length')

if [ "$PR_COUNT" -gt 0 ]; then
  PR_URL=$(echo "$EXISTING_PR" | jq -r '.[0].html_url')
  PR_NUMBER=$(echo "$EXISTING_PR" | jq -r '.[0].number')
  echo "Existing PR found: $PR_URL"
else
  # Build the JSON payload safely with jq to avoid injection via title/body
  PR_TITLE="${INPUT_PULL_REQUEST_TITLE:-New translations from WebTranslateIt}"
  PR_BODY="${INPUT_PULL_REQUEST_BODY:-Translations synced by [WebTranslateIt GitHub Action](https://github.com/webtranslateit/github-action)}"

  PAYLOAD=$(jq -n \
    --arg title "$PR_TITLE" \
    --arg body  "$PR_BODY" \
    --arg head  "$BRANCH" \
    --arg base  "$BASE" \
    '{title: $title, body: $body, head: $head, base: $base}')

  PR_RESPONSE=$(curl -sf -X POST \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    "${GITHUB_API}/repos/${GITHUB_REPOSITORY}/pulls" \
    -d "$PAYLOAD")

  PR_URL=$(echo "$PR_RESPONSE" | jq -r '.html_url')
  PR_NUMBER=$(echo "$PR_RESPONSE" | jq -r '.number')

  if [ "$PR_URL" = "null" ]; then
    echo "::error::Failed to create PR: $(echo "$PR_RESPONSE" | jq -r '.message')"
    exit 1
  fi

  echo "Created PR: $PR_URL"

  # Apply labels
  LABELS="${INPUT_PULL_REQUEST_LABELS:-localization}"
  if [ -n "$LABELS" ]; then
    LABELS_JSON=$(echo "$LABELS" | jq -R 'split(",") | map(gsub("^\\s+|\\s+$"; ""))')
    curl -sf -X POST \
      -H "Authorization: token ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github.v3+json" \
      "${GITHUB_API}/repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/labels" \
      -d "{\"labels\": ${LABELS_JSON}}" > /dev/null
  fi
fi

# Set outputs
echo "pull_request_url=$PR_URL"       >> "$GITHUB_OUTPUT"
echo "pull_request_number=$PR_NUMBER" >> "$GITHUB_OUTPUT"

echo "::endgroup::"
