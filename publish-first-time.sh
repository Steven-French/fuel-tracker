#!/usr/bin/env bash
# One-time: create a public GitHub repo "fuel-tracker" from this folder and turn on GitHub Pages.
# Requires: gh auth login (already done by Steven).
set -euo pipefail
cd "$(dirname "$0")"
REPO="${1:-fuel-tracker}"
gh auth status >/dev/null 2>&1 || { echo "Not signed in. Run: gh auth login"; exit 1; }
USER_LOGIN="$(gh api user --jq .login)"
USER_ID="$(gh api user --jq .id)"
echo "Publishing as GitHub user: $USER_LOGIN"
[ -d .git ] || git init -q -b main
git config user.name  "$(gh api user --jq '.name // .login')"
git config user.email "${USER_ID}+${USER_LOGIN}@users.noreply.github.com"
sed -i.bak "s/^const VERSION = .*/const VERSION = '$(date +%Y%m%d-%H%M%S)';/" sw.js && rm -f sw.js.bak
git add -A && git commit -qm "Publish Fuel" || true
gh repo create "$REPO" --public --source=. --remote=origin --push --description "Fuel — calorie, protein & weight tracker (PWA)"
gh api -X POST "repos/$USER_LOGIN/$REPO/pages" -f "source[branch]=main" -f "source[path]=/" >/dev/null
echo "GitHub Pages enabled. Live in ~1 minute at: https://$USER_LOGIN.github.io/$REPO/"
