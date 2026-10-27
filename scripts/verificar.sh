#!/bin/bash
set -uo pipefail

CHART="devops-portfolio"
TRAEFIK="172.22.0.2"
ERRORS=0

ok()   { echo "  [OK]   $1"; }
fail() { echo "  [FAIL] $1"; ERRORS=$((ERRORS+1)); }

echo "=================================================="
echo "  VERIFICACIÓN HELM & TRAEFIK (TP10B)"
echo "=================================================="

echo "--- 1. Render (Render First) ---"
if helm template notes "$CHART" -f "$CHART/values-prod.yaml" > /tmp/verif-render.yaml 2>/dev/null; then
  ok "helm template renderiza values-prod"
  if python3 -c "import yaml; list(yaml.safe_load_all(open('/tmp/verif-render.yaml')))" 2>/dev/null; then
    ok "YAML renderizado válido"
  else
    fail "YAML renderizado inválido"
  fi
else
  fail "helm template falló"
fi

for entorno in staging-helm:staging.devops-portfolio.local production-helm:devops-portfolio.dev; do
  NS=${entorno%%:*}
  HOST=${entorno##*:}

  echo ""
  echo "--- 2. Release en $NS ---"
  STATUS=$(helm status notes -n "$NS" 2>/dev/null | awk '/^STATUS:/{print $2}')
  if [ "$STATUS" = "deployed" ]; then
    ok "release notes -> deployed"
  else
    fail "release notes -> ${STATUS:-no encontrado}"
  fi

  echo "--- 3. Pods en $NS ---"
  while read -r NAME READY PSTATUS _; do
    if [ "$PSTATUS" = "Running" ]; then
      ok "$NAME -> $PSTATUS ($READY)"
    else
      fail "$NAME -> $PSTATUS"
    fi
  done < <(kubectl get pods -n "$NS" --no-headers 2>/dev/null)

  echo ""
  echo "--- 4. Endpoints vía Traefik ($HOST) ---"
  for path in "/" "/health" "/api/notes"; do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: $HOST" --max-time 5 "http://$TRAEFIK$path")
    [ "$CODE" = "200" ] && ok "$HOST$path -> HTTP $CODE" || fail "$HOST$path -> HTTP $CODE"
  done
done

echo ""
echo "=================================================="
if [ "$ERRORS" -eq 0 ]; then
  echo "  TP10B OK: todos los checks pasaron"
else
  echo "  ATENCIÓN: $ERRORS checks fallaron"
fi
echo "=================================================="
exit "$ERRORS"
