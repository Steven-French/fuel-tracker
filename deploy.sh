#!/usr/bin/env bash
# Deploy an update to GitHub Pages: stamps a new service-worker version (so installed copies refresh), commits, pushes.
#   ./deploy.sh "what changed"      deploy
#   ./deploy.sh --dry-run           show what would be deployed; verify GitHub access without pushing
set -euo pipefail
cd "$(dirname "$0")"
# the box's gh lives in /usr/local/bin (a configured helper may point at /usr/bin/gh, which does not exist)
push() { git -c credential.helper= -c credential.helper='!/usr/local/bin/gh auth git-credential' push "$@"; }
DRY=0; if [ "${1:-}" = "--dry-run" ]; then DRY=1; shift; fi
CHANGES="$(git status --porcelain)"
if [ -z "$CHANGES" ]; then
  echo "Nothing to deploy (working tree matches the live site)."
  [ "$DRY" = 1 ] && push --dry-run origin main
  exit 0
fi
if [ "$DRY" = 1 ]; then
  echo "Would deploy these changes:"; echo "$CHANGES"
  push --dry-run origin main
  exit 0
fi
sed -i.bak "s/^const VERSION = .*/const VERSION = '$(date +%Y%m%d-%H%M%S)';/" sw.js && rm -f sw.js.bak
git add -A
git commit -qm "${1:-Update Fuel}"
push -q origin main
echo "Pushed $(git rev-parse --short HEAD). Live in about a minute at https://steven-french.github.io/fuel-tracker/"
