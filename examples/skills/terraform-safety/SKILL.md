---
name: terraform-safety
description: Valida planes de Terraform detectando cambios destructivos, recursos de producción afectados y cambios en IAM policies antes del apply.
---

# Validación Pre-Apply de Terraform

## Cuándo usar este skill
Antes de cualquier `terraform apply` o cuando el usuario pida
validar un plan de Terraform.

## Procedimiento

### Paso 1: Generar el plan
```bash
terraform plan -out=tfplan -detailed-exitcode
```
Exit codes: 0 = sin cambios | 1 = error | 2 = cambios pendientes

### Paso 2: Convertir a JSON
```bash
terraform show -json tfplan > tfplan.json
```

### Paso 3: Analizar cambios destructivos
Buscar en el JSON:
- Acciones `"delete"` o `"replace"` en cualquier recurso
- Recursos con `"prod"` o `"production"` en el nombre
- Cambios en estos tipos de recursos (alto riesgo):
  - `aws_iam_policy`, `aws_iam_role`, `aws_iam_role_policy`
  - `aws_security_group`, `aws_security_group_rule`
  - `aws_s3_bucket` (eliminación = datos irrecuperables)
  - `aws_rds_instance`, `aws_rds_cluster` (downtime potencial)
  - `aws_eks_cluster`, `aws_eks_node_group`
  - `aws_route53_record` (impacto DNS)
  - `aws_elasticache_cluster`

### Paso 4: Clasificar riesgo
| Nivel | Criterio | Acción |
|-------|----------|--------|
| CRITICO | Delete en producción, cambios IAM amplios | DETENER. Revisión manual obligatoria |
| ALTO | Replace en recursos con estado, cambios en SG | Advertir, mostrar impacto detallado |
| BAJO | Add, cambios en tags, updates sin recreación | Proceder con confirmación normal |

### Paso 5: Reportar
Mostrar al usuario:
1. Resumen: X creados, Y modificados, Z eliminados
2. Detalle de cada recurso de riesgo alto/crítico
3. Recomendación: proceder / revisar / abortar

## Restricciones
- NUNCA ejecutar `terraform apply` si el riesgo es CRITICO
- SIEMPRE mostrar el plan completo antes de apply
- Si hay duda sobre el impacto, clasificar como riesgo alto
- No ejecutar apply en modo automático bajo ninguna circunstancia
