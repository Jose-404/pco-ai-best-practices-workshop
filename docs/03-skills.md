# Módulo 03: Skills

**Duración:** 20 minutos | **Dinámica:** Demo + Hands-on

---

## ¿Qué es un Skill?

Un Skill es un paquete reutilizable de instrucciones especializadas que le enseña a Codex **cómo** hacer una tarea específica. Piénsalo como un runbook que el agente sabe ejecutar.

A diferencia de `AGENTS.md` (que son reglas generales permanentes), los Skills se activan **solo cuando son relevantes**. Codex usa un mecanismo llamado **progressive disclosure**: lee solo el nombre y la descripción del skill, y carga las instrucciones completas únicamente cuando decide que necesita usarlo.

```
AGENTS.md = "Reglas que siempre aplican"
Skill     = "Instrucciones para una tarea específica, activadas bajo demanda"
```

## Anatomía de un Skill

Cada skill vive en su propio directorio y contiene al menos un `SKILL.md`:

```
skills/
└── aws-sg-audit/
    ├── SKILL.md              # Instrucciones del skill (obligatorio)
    ├── templates/            # Archivos de apoyo (opcional)
    │   └── sg-report.md
    └── scripts/              # Scripts auxiliares (opcional)
        └── check-open-ports.sh
```

### Estructura del SKILL.md

```markdown
---
name: aws-sg-audit
description: Audita Security Groups de AWS buscando reglas demasiado permisivas (0.0.0.0/0, puertos abiertos innecesarios)
---

# Auditoría de Security Groups AWS

## Cuándo usar este skill
Cuando el usuario pida revisar, auditar o validar Security Groups,
o cuando se detecte la creación de reglas de ingress demasiado permisivas.

## Procedimiento

1. Obtener la lista de Security Groups:
   ```bash
   aws ec2 describe-security-groups --output json
   ```

2. Para cada Security Group, verificar:
   - ¿Tiene reglas de ingress con `0.0.0.0/0`?
   - ¿Hay puertos abiertos que no deberían estarlo?
   - Puertos que NUNCA deben estar abiertos al público:
     - 22 (SSH), 3389 (RDP), 3306 (MySQL), 5432 (PostgreSQL)
     - 6379 (Redis), 27017 (MongoDB), 9200 (Elasticsearch)

3. Generar un reporte con:
   - Security Groups problemáticos
   - Regla específica que es riesgosa
   - Recomendación de corrección
   - Nivel de severidad (crítico/alto/medio)

## Formato del reporte
Usar la plantilla en `templates/sg-report.md`

## Restricciones
- Este skill es de SOLO LECTURA. No modificar Security Groups.
- Si se encuentra algo crítico, notificar inmediatamente al usuario.
```

## Registro de Skills en `agents/openai.yaml`

Para que Codex descubra tus skills, necesitas registrarlos en `agents/openai.yaml`:

```yaml
# agents/openai.yaml
skills:
  - name: aws-sg-audit
    description: >
      Audita Security Groups de AWS buscando reglas
      demasiado permisivas y genera reportes de seguridad.
    path: skills/aws-sg-audit/SKILL.md

  - name: terraform-safety
    description: >
      Valida planes de Terraform antes de apply, detectando
      cambios destructivos y recursos de producción afectados.
    path: skills/terraform-safety/SKILL.md

  - name: incident-response
    description: >
      Guía paso a paso para respuesta a incidentes en AWS,
      incluyendo diagnóstico, mitigación y documentación.
    path: skills/incident-response/SKILL.md
```

### Progressive Disclosure en acción

```
Usuario: "revisa los security groups de staging"

Codex (internamente):
  1. Lee agents/openai.yaml → ve 3 skills disponibles
  2. Lee solo nombre + descripción de cada uno
  3. "aws-sg-audit" coincide → carga SKILL.md completo
  4. Sigue las instrucciones del skill paso a paso
```

Esto es eficiente porque Codex no carga instrucciones que no necesita. Los skills pesados (con muchos pasos) no afectan el rendimiento hasta que se activan.

## Ejemplo Práctico: Skill de Terraform Safety

```markdown
---
name: terraform-safety
description: Valida planes de Terraform detectando cambios destructivos, recursos de producción afectados, y cambios en IAM policies antes del apply.
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
- Exit code 0 = sin cambios
- Exit code 1 = error
- Exit code 2 = hay cambios pendientes

### Paso 2: Convertir plan a JSON para análisis
```bash
terraform show -json tfplan > tfplan.json
```

### Paso 3: Analizar cambios destructivos
Buscar en el JSON:
- Acciones `"delete"` o `"replace"` (recrear = downtime potencial)
- Recursos con `"prod"` en el nombre
- Cambios en `aws_iam_policy`, `aws_iam_role` (escalamiento de privilegios)
- Cambios en `aws_security_group` o `aws_security_group_rule`
- Eliminación de `aws_s3_bucket` (datos irrecuperables)
- Cambios en `aws_rds_instance` (posible downtime)

### Paso 4: Clasificar el riesgo
| Nivel | Criterio | Acción |
|-------|----------|--------|
| 🔴 Crítico | Delete en producción, cambios IAM amplios | DETENER. Requiere revisión manual |
| 🟡 Alto | Replace en recursos con estado, cambios en SG | Advertir, mostrar impacto detallado |
| 🟢 Bajo | Add, cambios en tags, updates sin recreación | Proceder con confirmación normal |

### Paso 5: Reportar al usuario
Mostrar:
1. Resumen: X recursos creados, Y modificados, Z eliminados
2. Detalle de cada recurso de riesgo alto/crítico
3. Recomendación explícita: proceder, revisar, o abortar

## Restricciones
- NUNCA ejecutar `terraform apply` automáticamente si el riesgo es 🔴 o 🟡
- SIEMPRE mostrar el plan completo al usuario antes de apply
- Si hay duda sobre el impacto, clasificar como riesgo alto
```

## Ejemplo Práctico: Skill de Incident Response

```markdown
---
name: incident-response
description: Runbook de respuesta a incidentes en AWS. Guía el diagnóstico, recolección de evidencia, mitigación y documentación post-mortem.
---

# Respuesta a Incidentes AWS

## Cuándo usar este skill
Cuando el usuario reporte un incidente, una alerta, o pida
investigar un problema en los servicios AWS.

## Procedimiento

### Fase 1: Triage (2 min)
1. ¿Qué servicio está afectado?
2. ¿Hay impacto a usuarios finales?
3. ¿Desde cuándo ocurre?

```bash
# Verificar estado general
aws health describe-events --filter "eventStatusCodes=open"

# Verificar CloudWatch alarms activas
aws cloudwatch describe-alarms --state-value ALARM
```

### Fase 2: Diagnóstico (5-10 min)
Según el servicio afectado:

**EKS:**
```bash
kubectl get pods --all-namespaces | grep -v Running
kubectl get events --sort-by='.lastTimestamp' | tail -20
```

**RDS:**
```bash
aws rds describe-events --duration 60
aws cloudwatch get-metric-statistics --namespace AWS/RDS \
  --metric-name CPUUtilization --period 300 --statistics Average \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S)
```

**Lambda:**
```bash
aws logs filter-log-events --log-group-name /aws/lambda/FUNCTION_NAME \
  --start-time $(date -d '30 minutes ago' +%s000) \
  --filter-pattern "ERROR"
```

### Fase 3: Mitigación
- Proponer la acción de mitigación menos invasiva
- SIEMPRE confirmar con el usuario antes de ejecutar
- Documentar cada acción tomada con timestamp

### Fase 4: Post-mortem
Generar documento con:
- Timeline de eventos
- Causa raíz (o hipótesis si no se confirma)
- Acciones tomadas
- Items de seguimiento

## Restricciones
- NUNCA reiniciar servicios de producción sin confirmación
- Priorizar la recolección de evidencia ANTES de la mitigación
- No eliminar logs ni evidencia durante la investigación
```

## Hands-on (8 min)

Cada participante crea un skill básico para su área:

```bash
# Crear estructura de un skill nuevo
mkdir -p skills/mi-skill
cat > skills/mi-skill/SKILL.md << 'EOF'
---
name: mi-skill
description: [Describir qué hace en una línea]
---

# [Nombre del Skill]

## Cuándo usar
[Cuándo Codex debe activar este skill]

## Procedimiento
1. [Paso 1]
2. [Paso 2]
3. [Paso 3]

## Restricciones
- [Qué NO debe hacer este skill]
EOF

# Registrar en openai.yaml
cat >> agents/openai.yaml << 'EOF'
  - name: mi-skill
    description: [Describir qué hace]
    path: skills/mi-skill/SKILL.md
EOF
```

Ideas para skills del equipo:

- **cost-estimator**: Estimar costos antes de crear recursos AWS
- **log-analyzer**: Analizar CloudWatch Logs buscando patrones de error
- **iam-reviewer**: Revisar políticas IAM para detectar permisos excesivos
- **dns-troubleshoot**: Diagnosticar problemas de Route53 y resolución DNS
- **backup-validator**: Verificar que los backups de RDS/S3 están configurados correctamente

## Puntos clave

1. **Skills = runbooks ejecutables** que Codex activa bajo demanda
2. **Progressive disclosure** mantiene el contexto limpio — solo se carga lo necesario
3. Cada skill debe tener **restricciones claras** — especialmente si involucra infraestructura
4. Registra todos tus skills en `agents/openai.yaml` para que Codex los descubra
5. Un buen skill es **específico, paso a paso, y con restricciones explícitas**

---

**Siguiente:** [☕ Break → Módulo 04 - MCPs →](04-mcps.md)
