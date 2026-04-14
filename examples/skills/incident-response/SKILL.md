---
name: incident-response
description: Runbook de respuesta a incidentes en AWS. Guía el diagnóstico, recolección de evidencia, mitigación y documentación post-mortem.
---

# Respuesta a Incidentes AWS

## Cuándo usar este skill
Cuando el usuario reporte un incidente, una alerta, o pida
investigar un problema en los servicios AWS.

## Archivos disponibles

```
skills/incident-response/
├── SKILL.md                    # Este archivo
├── scripts/
│   └── triage.sh               # Script de triage multi-servicio
└── templates/
    └── post-mortem.md          # Plantilla de post-mortem
```

## Procedimiento

### Fase 1: Triage rápido (2 min)

Antes de cualquier diagnóstico, recopilar:
1. ¿Qué servicio está afectado?
2. ¿Hay impacto a usuarios finales?
3. ¿Desde cuándo ocurre?
4. ¿Qué cambios recientes se realizaron?

Ejecutar el script de triage para obtener un panorama general:

```bash
# Triage general (CloudWatch alarms + AWS Health)
bash skills/incident-response/scripts/triage.sh

# Triage de un servicio específico
bash skills/incident-response/scripts/triage.sh --service eks
bash skills/incident-response/scripts/triage.sh --service rds
bash skills/incident-response/scripts/triage.sh --service lambda --name mi-funcion
bash skills/incident-response/scripts/triage.sh --service ec2

# Triage completo de todos los servicios con reporte
bash skills/incident-response/scripts/triage.sh --all \
  --output /tmp/triage-$(date +%Y%m%d-%H%M).md
```

### Fase 2: Diagnóstico profundo (5–10 min)

Según el servicio afectado identificado en el triage:

**EKS / Kubernetes:**
```bash
kubectl get pods --all-namespaces | grep -v Running
kubectl get events --sort-by='.lastTimestamp' | tail -20
kubectl describe pod <pod-problemático> -n <namespace>
kubectl logs <pod> -n <namespace> --previous   # Logs del contenedor anterior
```

**RDS:**
```bash
aws rds describe-events --duration 60
aws rds describe-db-instances \
  --query 'DBInstances[].{ID:DBInstanceIdentifier,Status:DBInstanceStatus}'
```

**Lambda:**
```bash
aws logs filter-log-events \
  --log-group-name /aws/lambda/FUNCTION_NAME \
  --start-time $(date -d '30 minutes ago' +%s000) \
  --filter-pattern "ERROR"
```

**EC2:**
```bash
aws ec2 describe-instance-status \
  --filters "Name=instance-status.status,Values=impaired"
```

### Fase 3: Mitigación

- Proponer siempre la acción **menos invasiva** primero
- **SIEMPRE** confirmar con el usuario antes de ejecutar cualquier mitigación
- Documentar cada acción tomada con timestamp
- Si se requiere rollback, verificar el estado anterior antes de proceder
- Preferir rollback sobre fixes ad-hoc cuando sea posible

### Fase 4: Documentación Post-Mortem

Una vez resuelto el incidente, generar el post-mortem usando la plantilla:

```bash
cp skills/incident-response/templates/post-mortem.md \
   docs/post-mortems/$(date +%Y-%m-%d)-titulo-incidente.md
```

Completar la plantilla con:
- Timeline detallado de eventos
- Causa raíz (usar los 5 Por Qué)
- Acciones tomadas y su resultado
- Items de seguimiento con responsable y fecha

## Clasificación de Severidad

| SEV | Criterio | Tiempo de respuesta |
|-----|----------|---------------------|
| SEV-1 | Servicio de producción completamente caído | Inmediato |
| SEV-2 | Degradación severa en producción | 15 minutos |
| SEV-3 | Impacto parcial o en staging | 1 hora |
| SEV-4 | Problema menor, sin impacto inmediato | Próximo día hábil |

## Restricciones
- **NUNCA** reiniciar servicios de producción sin confirmación del usuario
- **PRIORIZAR** la recolección de evidencia antes de la mitigación
- No eliminar logs ni evidencia durante la investigación
- SEV-1 y SEV-2 requieren escalar al equipo inmediatamente
- Toda acción de mitigación debe quedar documentada con timestamp
