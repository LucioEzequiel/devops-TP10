# devops-TP10

Chart de Helm para la Notes App (backend Flask, frontend Nginx y Postgres).
Entrega continua multi-entorno con aprobación manual y rollback automático.

## Releases y entornos

| Release | Namespace | Valores | Réplicas backend | Host | Aprobación |
|---|---|---|---|---|---|
| notes | staging-helm | values-staging.yaml | 1 | staging.devops-portfolio.local | Automática |
| notes | production-helm | values-prod.yaml | 3 a 6 (HPA) | devops-portfolio.dev | Manual |

## Patrón Render First, Validate Second

Las plantillas de Go no son YAML válido, así que el chart nunca se valida crudo.
Primero se renderiza con `helm template` y después se valida el manifiesto resultante:

    ./scripts/render-validate.sh

## Pipelines

- pr-check.yml (en cada Pull Request): flake8 y pytest sobre backend/, y render-validate.sh más kubeconform.
- helm-cd.yml (en push a develop y main):
  1. deploy-staging valida, despliega con helm upgrade --install --atomic y verifica /health.
  2. deploy-production espera aprobación en el environment production. Si el smoke test falla, ejecuta helm rollback notes 0.

Los jobs de deploy corren en un runner propio del servidor (etiqueta helm-cd), con una ServiceAccount por namespace.

## Operación

    helm history notes -n production-helm
    helm rollback notes 0 -n production-helm --wait
    ./scripts/verificar-helm-entornos.sh
    ./scripts/verificar.sh

## Diferencias respecto de la guía

- Ingress: Traefik (incluido en k3s) en lugar de NGINX Ingress. Las pruebas usan la IP de Traefik con cabecera Host.
- Nombres: release notes y namespaces staging-helm y production-helm, para no mezclar con el TP09B.
- Secretos: las contraseñas viven en archivos values-*.local.yaml, ignorados por git.
- Runner: ServiceAccount con permisos limitados por namespace, en lugar de un kubeconfig de administrador.
- PVC de producción: 1Gi en lugar de 5Gi. Un PVC existente no se puede reducir sin perder datos.
