#!/usr/bin/env bash
set -euo pipefail

CHART="devops-portfolio"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> helm lint"
helm lint "$CHART"

for env in values values-staging values-prod; do
  echo "==> render $env"
  if [ "$env" = "values" ]; then
    helm template test "$CHART" > "$TMP/$env.yaml"
  else
    helm template test "$CHART" -f "$CHART/$env.yaml" > "$TMP/$env.yaml"
  fi
  kubectl apply --dry-run=client -f "$TMP/$env.yaml" > /dev/null
  echo "    OK: $env"
done

echo "==> Validación completa: todos los entornos pasaron"
