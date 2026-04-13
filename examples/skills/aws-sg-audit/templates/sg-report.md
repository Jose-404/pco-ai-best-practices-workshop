# Reporte de Auditoría — Security Groups

**Fecha:** {{FECHA}}
**Cuenta AWS:** {{CUENTA}}
**Región:** {{REGION}}
**Ejecutado por:** {{USUARIO}}

## Resumen Ejecutivo

| Severidad | Cantidad | SLA de Remediación |
|-----------|----------|--------------------|
| Crítico   | {{CRITICOS}} | 24 horas |
| Alto      | {{ALTOS}} | 1 semana |
| Medio     | {{MEDIOS}} | Próximo sprint |
| Bajo      | {{BAJOS}} | Backlog |
| **Total SGs analizados** | **{{TOTAL}}** | — |

## Hallazgos Detallados

### Críticos

| SG ID | Nombre | VPC | Hallazgo | Recurso Asociado | Recomendación |
|-------|--------|-----|----------|------------------|---------------|
| {{SG_ID}} | {{SG_NAME}} | {{VPC_ID}} | {{HALLAZGO}} | {{RECURSO}} | {{RECOMENDACION}} |

### Altos

| SG ID | Nombre | VPC | Hallazgo | Recurso Asociado | Recomendación |
|-------|--------|-----|----------|------------------|---------------|
| {{SG_ID}} | {{SG_NAME}} | {{VPC_ID}} | {{HALLAZGO}} | {{RECURSO}} | {{RECOMENDACION}} |

### Medios y Bajos

| SG ID | Nombre | Hallazgo | Recomendación |
|-------|--------|----------|---------------|
| {{SG_ID}} | {{SG_NAME}} | {{HALLAZGO}} | {{RECOMENDACION}} |

## Puertos Críticos de Referencia

| Puerto | Servicio | Riesgo si está abierto a 0.0.0.0/0 |
|--------|----------|-------------------------------------|
| 22 | SSH | Acceso remoto no autorizado a servidores |
| 3389 | RDP | Acceso remoto a escritorios Windows |
| 3306 | MySQL | Exfiltración/corrupción de datos |
| 5432 | PostgreSQL | Exfiltración/corrupción de datos |
| 6379 | Redis | Acceso a cache, posible ejecución de código |
| 27017 | MongoDB | Exfiltración de datos, ransomware |
| 9200 | Elasticsearch | Exposición de índices, datos sensibles |
| 11211 | Memcached | Amplificación DDoS, fuga de datos en cache |

## Acciones de Remediación

- [ ] Revisar y cerrar puertos críticos abiertos a 0.0.0.0/0
- [ ] Restringir acceso SSH/RDP a rangos de IP del equipo o bastion hosts
- [ ] Eliminar Security Groups sin uso (verificar que no sean referenciados)
- [ ] Configurar VPC Flow Logs si no están habilitados
- [ ] Implementar AWS Config Rule `restricted-common-ports` para detección continua
- [ ] Programar auditorías periódicas (semanal recomendado)

## Notas

> Este reporte fue generado por el skill `aws-sg-audit`.
> Los hallazgos deben ser verificados manualmente antes de remediar.
> No se realizaron modificaciones a ningún recurso durante la auditoría.
