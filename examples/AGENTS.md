# AGENTS.md — Equipo DevOps-SRE

## Contexto del Proyecto
Este repositorio gestiona la infraestructura AWS usando Terraform y Terragrunt.
El equipo DevOps-SRE es responsable de la operación y mantenimiento de los
servicios en producción y staging.

## Stack
- **Cloud:** AWS (EKS, RDS, S3, CloudFront, Lambda, Route53)
- **IaC:** Terraform 1.8+ con Terragrunt
- **CI/CD:** GitHub Actions
- **Observabilidad:** Datadog / CloudWatch
- **Containers:** Docker + EKS (Kubernetes)

## Reglas Obligatorias

### Prohibiciones
- NUNCA ejecutes `terraform destroy` sin confirmación explícita del usuario
- NUNCA modifiques Security Groups con "prod" en el nombre sin --dry-run previo
- NUNCA ejecutes `kubectl delete` en namespaces de producción
- NUNCA hagas `rm -rf` en paths del sistema (/etc, /var, /opt, /home, /root)
- NUNCA expongas secrets, tokens o credenciales en outputs o logs
- NUNCA hagas `git push --force` a main, master o develop
- NUNCA elimines buckets S3 de producción
- NUNCA modifiques IAM policies sin mostrar antes el diff de permisos

### Obligaciones
- SIEMPRE ejecuta `terraform plan -out=tfplan` antes de `terraform apply tfplan`
- SIEMPRE usa `--dry-run` como primer paso en operaciones destructivas
- SIEMPRE verifica la cuenta AWS activa (`aws sts get-caller-identity`) antes de operar
- SIEMPRE confirma el environment (staging/prod) antes de cualquier cambio
- SIEMPRE incluye tags obligatorios en recursos AWS: Environment, Team, ManagedBy
- SIEMPRE usa Conventional Commits en español: feat:, fix:, chore:, docs:

## Convenciones
- Idioma de respuesta: español
- Nombres de recursos Terraform: `{env}-{servicio}-{recurso}`
- Variables Terraform: snake_case con description obligatorio
- Branches: feature/, fix/, chore/ desde develop
- PRs requieren al menos 1 aprobación

## Flujo Pre-Infraestructura
Antes de modificar infraestructura, ejecutar en este orden:
1. `aws sts get-caller-identity` — verificar cuenta
2. `aws configure get region` — verificar región
3. `terraform init` (si es necesario)
4. `terraform plan -out=tfplan` — generar plan
5. Mostrar resumen del plan al usuario
6. Solo con aprobación: `terraform apply tfplan`
