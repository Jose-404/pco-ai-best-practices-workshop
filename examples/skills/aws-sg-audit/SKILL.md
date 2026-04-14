---
name: aws-sg-audit
description: Audita Security Groups de AWS buscando reglas demasiado permisivas (0.0.0.0/0, puertos críticos abiertos) y genera un reporte de seguridad.
---

# Auditoría de Security Groups AWS

## Cuándo usar este skill
Cuando el usuario pida revisar, auditar o validar Security Groups,
o cuando se detecte la creación de reglas de ingress demasiado permisivas.

## Archivos disponibles

```
skills/aws-sg-audit/
├── SKILL.md                        # Este archivo
├── scripts/
│   └── audit-security-groups.sh   # Script principal de auditoría
└── templates/
    └── sg-report.md                # Plantilla para el reporte final
```

## Procedimiento

### Paso 1: Ejecutar el script de auditoría

El script se encarga de conectarse a AWS, analizar todos los Security Groups
y clasificar los hallazgos por severidad.

```bash
# Auditoría básica (salida en terminal)
bash skills/aws-sg-audit/scripts/audit-security-groups.sh

# Especificando región y perfil AWS
bash skills/aws-sg-audit/scripts/audit-security-groups.sh \
  --region us-east-1 \
  --profile staging

# Generando reporte markdown
bash skills/aws-sg-audit/scripts/audit-security-groups.sh \
  --region us-east-1 \
  --output /tmp/sg-report.md
```

### Paso 2: Revisar hallazgos con el usuario

El script clasifica automáticamente los hallazgos:

| Nivel | Criterio |
|-------|----------|
| CRITICO | Base de datos (MySQL, Postgres, Redis, etc.) abierta a `0.0.0.0/0` |
| ALTO | SSH (22) o RDP (3389) abierto a `0.0.0.0/0` |
| MEDIO | Rango de más de 100 puertos abierto a `0.0.0.0/0` |
| BAJO | Security Group sin uso (no asociado a ninguna ENI) |

### Paso 3: Generar reporte formal

Si el usuario pide un reporte, usar la plantilla en `templates/sg-report.md`
y completarla con los hallazgos del script. El propio script puede generarlo
directamente con `--output`.

### Paso 4: Recomendar remediación

Para cada hallazgo, sugerir:
- **CRITICO:** Restringir a IP interna o eliminar regla inmediatamente
- **ALTO:** Usar bastion host o VPN para SSH/RDP, nunca exposición directa
- **MEDIO:** Revisar si el rango amplio es necesario y reducirlo
- **BAJO:** Eliminar el Security Group si no está en uso

## Restricciones
- Este skill es de **SOLO LECTURA**. Nunca modificar Security Groups.
- Si se encuentran hallazgos críticos, notificar inmediatamente al usuario.
- No asumir que un puerto abierto es "intencional" — siempre reportar.
- Verificar siempre la cuenta y región AWS antes de ejecutar.
