---
name: aws-sg-audit
description: Audita Security Groups de AWS buscando reglas demasiado permisivas (0.0.0.0/0, puertos críticos abiertos) y genera un reporte de seguridad.
---

# Auditoría de Security Groups AWS

## Cuándo usar este skill
Cuando el usuario pida revisar, auditar o validar Security Groups,
o cuando se detecte la creación de reglas de ingress demasiado permisivas.

## Procedimiento

### Paso 1: Obtener Security Groups
```bash
aws ec2 describe-security-groups --output json > /tmp/sg-audit.json
```

### Paso 2: Analizar reglas peligrosas
Para cada Security Group, verificar:
- Reglas de ingress con source `0.0.0.0/0` o `::/0`
- Puertos que NUNCA deben estar abiertos al público:
  - 22 (SSH)
  - 3389 (RDP)
  - 3306 (MySQL)
  - 5432 (PostgreSQL)
  - 6379 (Redis)
  - 27017 (MongoDB)
  - 9200/9300 (Elasticsearch)
  - 11211 (Memcached)
- Reglas con rango de puertos demasiado amplio (ej: 0-65535)
- Security Groups sin uso (no asociados a ninguna ENI)

### Paso 3: Clasificar severidad
| Nivel | Criterio |
|-------|----------|
| CRITICO | Puerto de base de datos abierto a 0.0.0.0/0 |
| ALTO | SSH/RDP abierto a 0.0.0.0/0 |
| MEDIO | Rango amplio de puertos abierto a 0.0.0.0/0 |
| BAJO | Security Group sin uso |

### Paso 4: Generar reporte
Formato del reporte:
```
## Reporte de Auditoría - Security Groups
Fecha: [timestamp]
Cuenta: [account-id]
Región: [region]

### Hallazgos Críticos
- SG: [sg-id] ([nombre])
  - Puerto [X] abierto a 0.0.0.0/0
  - Asociado a: [recurso]
  - Recomendación: [acción]

### Resumen
- Total SGs analizados: X
- Críticos: X | Altos: X | Medios: X | Bajos: X
```

## Restricciones
- Este skill es de SOLO LECTURA. NUNCA modificar Security Groups.
- Si se encuentra algo crítico, notificar inmediatamente al usuario.
- No asumir que un puerto abierto es "intencionado" — siempre reportar.
