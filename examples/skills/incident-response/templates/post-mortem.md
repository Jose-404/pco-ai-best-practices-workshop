# Post-Mortem: {{TITULO_INCIDENTE}}

**Fecha del incidente:** {{FECHA}}
**Duración:** {{HORA_INICIO}} — {{HORA_FIN}} ({{DURACION_TOTAL}})
**Severidad:** SEV-{{SEVERIDAD}}
**Impacto:** {{DESCRIPCION_IMPACTO}}
**Autor del post-mortem:** {{AUTOR}}

## Resumen Ejecutivo

{{RESUMEN — 2-3 oraciones describiendo qué pasó, el impacto, y cómo se resolvió}}

## Timeline

| Hora (UTC) | Evento | Quién |
|------------|--------|-------|
| {{HH:MM}} | Alerta disparada: {{detalle}} | Sistema |
| {{HH:MM}} | Equipo notificado vía {{canal}} | {{persona}} |
| {{HH:MM}} | Inicio de investigación | {{persona}} |
| {{HH:MM}} | Causa raíz identificada: {{causa}} | {{persona}} |
| {{HH:MM}} | Mitigación aplicada: {{acción}} | {{persona}} |
| {{HH:MM}} | Servicio restaurado | {{persona}} |
| {{HH:MM}} | Monitoreo post-resolución completado | {{persona}} |

## Detección

- **Cómo se detectó:** {{alerta automática / reporte de usuario / monitoreo manual}}
- **Tiempo hasta detección:** {{minutos desde inicio hasta primera alerta}}
- **Alertas que se dispararon:** {{lista de alarmas CloudWatch, Datadog, etc.}}

## Causa Raíz

{{Descripción detallada de la causa raíz. Incluir la cadena causal completa:
qué cambió → qué efecto tuvo → por qué causó el incidente}}

### Los 5 Por Qué

1. **¿Por qué falló el servicio?** {{respuesta}}
2. **¿Por qué {{lo anterior}}?** {{respuesta}}
3. **¿Por qué {{lo anterior}}?** {{respuesta}}
4. **¿Por qué {{lo anterior}}?** {{respuesta}}
5. **¿Por qué {{lo anterior}}?** {{respuesta — causa raíz más profunda}}

## Impacto

- **Usuarios afectados:** {{número o porcentaje}}
- **Servicios afectados:** {{lista}}
- **Duración del impacto:** {{tiempo}}
- **Datos perdidos:** {{sí/no, detalle}}
- **SLA comprometido:** {{sí/no, cuál}}

## Acciones de Mitigación Realizadas

| # | Acción | Resultado | Ejecutada por |
|---|--------|-----------|---------------|
| 1 | {{acción}} | {{resultado}} | {{persona}} |
| 2 | {{acción}} | {{resultado}} | {{persona}} |

## Qué salió bien

- {{Qué funcionó correctamente durante la respuesta}}
- {{Herramientas o procesos que ayudaron}}
- {{Comunicación efectiva}}

## Qué salió mal

- {{Qué dificultó la respuesta}}
- {{Gaps en monitoreo o alertas}}
- {{Documentación faltante}}

## Lecciones Aprendidas

1. {{Lección 1}}
2. {{Lección 2}}
3. {{Lección 3}}

## Acciones de Seguimiento

| # | Acción | Prioridad | Responsable | Fecha límite | Ticket |
|---|--------|-----------|-------------|-------------|--------|
| 1 | {{Acción preventiva}} | {{Alta/Media/Baja}} | {{persona}} | {{fecha}} | {{link}} |
| 2 | {{Mejora en monitoreo}} | {{Alta/Media/Baja}} | {{persona}} | {{fecha}} | {{link}} |
| 3 | {{Actualizar runbook}} | {{Alta/Media/Baja}} | {{persona}} | {{fecha}} | {{link}} |
| 4 | {{Agregar test/validación}} | {{Alta/Media/Baja}} | {{persona}} | {{fecha}} | {{link}} |

---

> Generado con el skill `incident-response`.
> Este documento debe ser revisado por el equipo en la reunión de post-mortem.
