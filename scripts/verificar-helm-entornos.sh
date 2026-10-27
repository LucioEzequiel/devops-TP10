#!/bin/bash
# Auditoría de releases Helm en staging-helm y production-helm (TP10C)
set -uo pipefail

TOTAL=0
PASSED=0
ok()   { echo "  [PASS] $1"; PASSED=$((PASSED+1)); }
fail() { echo "  [FAIL] $1"; }
check() { TOTAL=$((TOTAL+1)); }

echo "=============================================================="
echo "  AUDITORÍA MULTI-ENTORNO CON HELM (TP10C)"
echo "=============================================================="

echo "--- 1. Releases activos ---"
for par in staging-helm:1 production-helm:3; do
  NS=${par%%:*}
  check
  STATUS=$(helm status notes -n "$NS" 2>/dev/null | awk '/^STATUS:/{print $2}')
  if [ "$STATUS" = "deployed" ]; then
    ok "release notes en $NS -> deployed"
  else
    fail "release notes en $NS -> ${STATUS:-no encontrado}"
  fi
done

echo "--- 2. Réplicas del backend ---"
check
REP_STG=$(kubectl get deployment notes-backend -n staging-helm -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)
if [ "$REP_STG" -eq 1 ]; then ok "staging-helm: $REP_STG réplica"; else fail "staging-helm: $REP_STG réplicas (esperado 1)"; fi
check
REP_PRD=$(kubectl get deployment notes-backend -n production-helm -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)
if [ "$REP_PRD" -ge 3 ]; then ok "production-helm: $REP_PRD réplicas (mínimo 3)"; else fail "production-helm: $REP_PRD réplicas (esperado >= 3)"; fi

echo "--- 3. HPA de producción ---"
check
HPA_MIN=$(kubectl get hpa notes-backend -n production-helm -o jsonpath='{.spec.minReplicas}' 2>/dev/null || echo 0)
HPA_MAX=$(kubectl get hpa notes-backend -n production-helm -o jsonpath='{.spec.maxReplicas}' 2>/dev/null || echo 0)
if [ "$HPA_MIN" -eq 3 ] && [ "$HPA_MAX" -eq 6 ]; then
  ok "HPA notes-backend: min $HPA_MIN, max $HPA_MAX"
else
  fail "HPA notes-backend: min $HPA_MIN, max $HPA_MAX (esperado 3 y 6)"
fi

echo "--- 4. Ingress por entorno ---"
for par in staging-helm:staging.devops-portfolio.local production-helm:devops-portfolio.dev; do
  NS=${par%%:*}
  HOST_ESPERADO=${par##*:}
  check
  HOST=$(kubectl get ingress -n "$NS" -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null || echo "")
  if [ "$HOST" = "$HOST_ESPERADO" ]; then
    ok "Ingress en $NS apunta a $HOST"
  else
    fail "Ingress en $NS apunta a '$HOST' (esperado $HOST_ESPERADO)"
  fi
done

echo "--- 5. Historial para rollback ---"
check
REVS=$(helm history notes -n production-helm 2>/dev/null | tail -n +2 | wc -l)
if [ "$REVS" -ge 2 ]; then
  ok "production-helm tiene $REVS revisiones registradas"
else
  fail "production-helm tiene $REVS revisiones (se necesitan al menos 2 para rollback)"
fi

echo "=============================================================="
echo "  Resultado: $PASSED de $TOTAL pruebas superadas"
if [ "$PASSED" -eq "$TOTAL" ]; then
  echo "  Estado: APROBADO"
else
  echo "  Estado: REQUIERE AJUSTES"
fi
echo "=============================================================="
[ "$PASSED" -eq "$TOTAL" ]
