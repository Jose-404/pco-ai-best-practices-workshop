# Validación de Plan Terraform

**Fecha:** {{FECHA}}
**Directorio:** {{DIRECTORIO}}
**Ejecutado por:** {{USUARIO}}

## Recomendación

{{RECOMENDACION}}

## Resumen de Cambios

| Acción | Cantidad | Detalle |
|--------|----------|---------|
| Crear | {{CREATES}} | Recursos nuevos |
| Modificar | {{UPDATES}} | Cambios in-place |
| Reemplazar | {{REPLACES}} | Destruir + crear (posible downtime) |
| Eliminar | {{DELETES}} | Recursos que se eliminarán |
| **Total** | **{{TOTAL}}** | — |

## Clasificación de Riesgo

| Nivel | Cantidad | Criterio |
|-------|----------|----------|
| Crítico | {{CRITICOS}} | Eliminación en producción, cambios IAM amplios |
| Alto | {{ALTOS}} | Reemplazos, cambios en SGs de producción |
| Bajo | {{BAJOS}} | Creación, cambios en tags, updates sin recreación |

## Recursos Afectados

### Riesgo Crítico

| Recurso | Acción | Razón |
|---------|--------|-------|
| {{ADDRESS}} | {{ACCION}} | {{RAZON}} |

### Riesgo Alto

| Recurso | Acción | Razón |
|---------|--------|-------|
| {{ADDRESS}} | {{ACCION}} | {{RAZON}} |

## Tipos de Recursos de Alto Riesgo (referencia)

Estos tipos de recursos siempre reciben escrutinio adicional:

| Tipo | Razón |
|------|-------|
| `aws_iam_*` | Escalamiento de privilegios |
| `aws_security_group*` | Exposición de red |
| `aws_s3_bucket` | Pérdida de datos |
| `aws_rds_*` | Downtime, pérdida de datos |
| `aws_eks_*` | Interrupción de servicios |
| `aws_route53_*` | Impacto DNS global |
| `aws_dynamodb_table` | Pérdida de datos |
| `aws_kms_key` | Pérdida de acceso a datos cifrados |
| `aws_vpc` / `aws_subnet` | Pérdida de conectividad |

## Comando para Aplicar

```bash
# Solo si la validación es OK o ALTO con revisión completada:
terraform apply tfplan
```

> Este reporte fue generado por el skill `terraform-safety`.
> Ningún recurso fue modificado durante la validación.
