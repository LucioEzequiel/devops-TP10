#!/usr/bin/env bash
set -euo pipefail

CHART="devops-portfolio"
RENDER="manifests-rendered-prod.yaml"

echo "==> helm lint"
helm lint "$CHART"

echo "==> render values-prod"
helm template notes "$CHART" -f "$CHART/values-prod.yaml" > "$RENDER"

echo "==> validación YAML (Python)"
python3 -c "
import yaml
with open('$RENDER') as f:
    docs = [d for d in yaml.safe_load_all(f) if d]
print(f'    OK: {len(docs)} objetos')
"

echo "==> yamllint"
/root/venv-tp07/bin/yamllint -d '{extends: default, rules: {line-length: {max: 120}}}' "$RENDER"
echo "    OK"

if command -v kubectl >/dev/null && kubectl cluster-info >/dev/null 2>&1; then
  echo "==> kubectl dry-run"
  kubectl apply --dry-run=client -f "$RENDER" > /dev/null
  echo "    OK"
else
  echo "==> kubectl dry-run omitido (sin cluster accesible)"
fi

echo "==> Validación completa"
