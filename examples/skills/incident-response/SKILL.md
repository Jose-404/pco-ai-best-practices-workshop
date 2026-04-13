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
Recopilar:
1. Qué servicio está afectado
2. Hay impacto a usuarios finales (sí/no)
3. Desde cuándo ocurre
4. Qué cambios recientes se hicieron

```bash
# Estado general de salud AWS
aws health describe-events --filter "eventStatusCodes=open"

# Alarmas activas
aws cloudwatch describe-alarms --state-value ALARM --output table
```

### Fase 2: Diagnóstico (5-10 min)

**EKS / Kubernetes:**
```bash
kubectl get pods --all-namespaces | grep -v Running
kubectl get events --sort-by='.lastTimestamp' | tail -20
kubectl top nodes
kubectl top pods --all-namespaces --sort-by=memory | head -20
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
aws logs filter-log-events \
  --log-group-name /aws/lambda/FUNCTION_NAME \
  --start-time $(date -d '30 minutes ago' +%s000) \
  --filter-pattern "ERROR"
```

**EC2 / General:**
```bash
aws ec2 describe-instance-status --filters "Name=instance-status.status,Values=impaired"
aws ec2 describe-instances --filters "Name=instance-state-name,Values=stopped" \
  --query 'Reservations[].Instances[].{ID:InstanceId,Name:Tags[?Key==`Name`].Value|[0]}'
```

### Fase 3: Mitigación
- Proponer la acción MENOS invasiva primero
- SIEMPRE confirmar con el usuario antes de ejecutar cualquier mitigación
- Documentar cada acción tomada con timestamp
- Si se requiere rollback, verificar la versión anterior antes de proceder

### Fase 4: Documentación Post-Mortem
Generar documento con:
```markdown
## Post-Mortem: [Título del incidente]
**Fecha:** [fecha]
**Duración:** [inicio] - [resolución]
**Impacto:** [descripción del impacto]
**Severidad:** SEV-[1-4]

### Timeline
- [HH:MM] Alerta disparada
- [HH:MM] Equipo notificado
- [HH:MM] Diagnóstico completado
- [HH:MM] Mitigación aplicada
- [HH:MM] Servicio restaurado

### Causa Raíz
[Descripción]

### Acciones Tomadas
1. [Acción + resultado]

### Items de Seguimiento
- [ ] [Acción preventiva]
```

## Restricciones
- NUNCA reiniciar servicios de producción sin confirmación
- PRIORIZAR recolección de evidencia ANTES de la mitigación
- No eliminar logs ni evidencia durante la investigación
- Si el incidente es SEV-1 o SEV-2, sugerir escalar inmediatamente
