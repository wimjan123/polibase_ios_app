#!/usr/bin/env bash
set -euo pipefail

# Creates a GitHub repo named polibase_ios_app and pushes current directory.
# Requires either the 'gh' CLI (interactive) or GITHUB_TOKEN + GITHUB_OWNER env vars.

REPO_NAME="polibase_ios_app"
OWNER="${GITHUB_OWNER:-}" # optional when using gh
TOKEN="${GITHUB_TOKEN:-}"

if [ -z "$(git rev-parse --git-dir 2>/dev/null || true)" ]; then
  git init
  git add -A
  git commit -m "Initial commit: planning files" || true
fi

if command -v gh >/dev/null 2>&1; then
  echo "Using gh CLI to create repo..."
  gh auth status || true
  gh repo create "$OWNER/$REPO_NAME" --public --source=. --remote=origin --push --confirm
  echo "Created and pushed to: https://github.com/${OWNER:-<your-user>}/$REPO_NAME"
  exit 0
fi

if [ -n "$TOKEN" ] && [ -n "$OWNER" ]; then
  echo "Using GitHub API with token to create repo under $OWNER"
  curl -s -H "Authorization: token $TOKEN" \
    -d "{\"name\": \"$REPO_NAME\", \"private\": false}" \
    "https://api.github.com/orgs/$OWNER/repos" || \
  curl -s -H "Authorization: token $TOKEN" \
    -d "{\"name\": \"$REPO_NAME\", \"private\": false}" \
    "https://api.github.com/user/repos"

  git remote add origin "https://github.com/$OWNER/$REPO_NAME.git" || true
  git push -u origin HEAD:main
  echo "Created and pushed to: https://github.com/$OWNER/$REPO_NAME"
  exit 0
fi

echo "ERROR: neither gh CLI found nor GITHUB_TOKEN+GITHUB_OWNER set."
echo "Install and authenticate gh (https://cli.github.com/) or set GITHUB_TOKEN and GITHUB_OWNER and re-run."
exit 1
