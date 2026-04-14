---
name: terraform-safety
description: Valida planes de Terraform detectando cambios destructivos, recursos de producción afectados y cambios en IAM policies antes del apply.
---

# Validación Pre-Apply de Terraform

## Cuándo usar este skill
Antes de cualquier `terraform apply`, o cuando el usuario pida
validar o revisar un plan de Terraform.

## Archivos disponibles

```
skills/terraform-safety/
├── SKILL.md                        # Este archivo
├── scripts/
│   └── validate-tfplan.sh          # Script de análisis del plan
└── templates/
    └── tf-report.md                # Plantilla para el reporte final
```

## Procedimiento

### Paso 1: Generar el plan de Terraform

Si no existe un plan previo, generarlo primero:

```bash
terraform plan -out=tfplan -detailed-exitcode
```

Exit codes de Terraform: `0` = sin cambios | `1` = error | `2` = hay cambios pendientes

### Paso 2: Ejecutar la validación

```bash
# Validar un plan existente
bash skills/terraform-safety/scripts/validate-tfplan.sh tfplan

# Generar plan automáticamente y validar
bash skills/terraform-safety/scripts/validate-tfplan.sh --auto

# Guardar reporte en markdown
bash skills/terraform-safety/scripts/validate-tfplan.sh tfplan \
  --output /tmp/tf-validation.md
```

El script analiza el plan y clasifica cada cambio:

| Nivel | Criterio | Acción |
|-------|----------|--------|
| CRITICO | Delete/replace en recursos de producción | DETENER — revisión manual |
| ALTO | Replace en recursos con estado, cambios IAM o SG | Advertir, revisar detalle |
| BAJO | Create, updates sin recreación, cambios de tags | Proceder normalmente |

El script también devuelve **exit codes útiles para CI/CD**:
- `0` = Riesgo bajo (pipeline puede continuar)
- `1` = Riesgo alto (advertencia, requiere revisión)
- `2` = Riesgo crítico (bloquea el pipeline)

### Paso 3: Revisar el resultado con el usuario

Mostrar siempre:
1. Resumen: cuántos recursos se crean, modifican, reemplazan, eliminan
2. Detalle de cada recurso de riesgo alto o crítico
3. Recomendación explícita: proceder / revisar / abortar

### Paso 4: Proceder con apply solo si es seguro

```bash
# Solo si la validación devuelve riesgo bajo o alto revisado:
terraform apply tfplan
```

**Nunca ejecutar** `terraform apply` sin el archivo de plan (`tfplan`).
Esto garantiza que lo que se aplica es exactamente lo que se validó.

## Integración con CI/CD (GitHub Actions)

```yaml
# .github/workflows/terraform.yml
- name: Validar plan
  run: |
    bash skills/terraform-safety/scripts/validate-tfplan.sh tfplan \
      --output reports/tf-validation.md
  # Exit code 2 = falla el pipeline automáticamente
```

## Restricciones
- **NUNCA** ejecutar `terraform apply` si el riesgo es CRITICO
- **SIEMPRE** mostrar el plan al usuario antes de aplicar
- Si hay duda sobre el impacto de un cambio, clasificar como riesgo alto
- No ejecutar apply en modo automático bajo ninguna circunstancia
