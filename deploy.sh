#!/usr/bin/env bash
# Deploy an update: stamps a new service-worker version (so installed copies refresh), commits, pushes to GitHub Pages.
set -euo pipefail
cd "$(dirname "$0")"
sed -i.bak "s/^const VERSION = .*/const VERSION = '$(date +%Y%m%d-%H%M%S)';/" sw.js && rm -f sw.js.bak
git add -A
git commit -qm "${1:-Update Fuel}" || { echo "Nothing to deploy."; exit 0; }
git push -q origin main
echo "Pushed. GitHub Pages will serve it in about a minute."
