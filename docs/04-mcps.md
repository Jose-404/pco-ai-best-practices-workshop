# Módulo 04: MCPs (Model Context Protocol)

**Duración:** 20 minutos | **Dinámica:** Demo

---

## ¿Qué es MCP?

**Model Context Protocol (MCP)** es un estándar abierto que permite a los agentes de IA conectarse con herramientas y servicios externos de forma segura. Piénsalo como una "API universal" que conecta a Codex con el mundo exterior.

```
Sin MCP:                           Con MCP:
┌────────┐                         ┌────────┐
│ Codex  │──"no puedo acceder     │ Codex  │──┬── AWS (boto3)
│        │   a eso"               │        │  ├── Jira/Linear
└────────┘                         │        │  ├── Slack
                                   │        │  ├── Datadog
                                   │        │  ├── GitHub
                                   └────────┘  └── PagerDuty
                                       vía MCP servers
```

Mientras que los **Skills** le dicen a Codex *cómo* hacer algo, los **MCPs** le dan acceso a las *herramientas* para hacerlo.

## Arquitectura de MCP

```
┌──────────────┐     stdio/SSE     ┌──────────────┐     API calls     ┌──────────────┐
│  Codex CLI   │◄────────────────▶│  MCP Server  │◄──────────────────▶│  Servicio    │
│  (cliente)   │                   │  (puente)    │                    │  Externo     │
└──────────────┘                   └──────────────┘                    └──────────────┘
                                   Ejemplo:
                                   - @modelcontextprotocol/server-github
                                   - mcp-server-aws
                                   - mcp-server-slack
```

Un **MCP server** es un proceso local que:
1. Expone "tools" (funciones) que Codex puede llamar
2. Se comunica con Codex vía stdio o SSE
3. Hace las llamadas reales a la API externa
4. Devuelve los resultados a Codex

## Configuración de MCPs en Codex CLI

Los MCPs se configuran en `.codex/config.toml` a nivel de proyecto:

```toml
# .codex/config.toml

[mcp]

[mcp.servers.github]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-github"]
env = { GITHUB_PERSONAL_ACCESS_TOKEN = "${GITHUB_TOKEN}" }

[mcp.servers.aws]
command = "npx"
args = ["-y", "mcp-server-aws"]
env = { AWS_PROFILE = "staging", AWS_REGION = "us-east-1" }

[mcp.servers.slack]
command = "npx"
args = ["-y", "@anthropic/mcp-server-slack"]
env = { SLACK_BOT_TOKEN = "${SLACK_BOT_TOKEN}" }
```

> **⚠️ Nota de seguridad:** Nunca hardcodees tokens en el archivo de configuración. Usa referencias a variables de entorno con `${VAR_NAME}`.

## MCPs Relevantes para DevOps-SRE

### GitHub MCP

Permite a Codex interactuar directamente con GitHub: crear PRs, revisar issues, leer archivos del repo, gestionar releases.

```toml
[mcp.servers.github]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-github"]
env = { GITHUB_PERSONAL_ACCESS_TOKEN = "${GITHUB_TOKEN}" }
```

**Ejemplo de uso:**
```
> "Crea un PR con los cambios actuales describiendo qué se modificó en el security group"
> "¿Qué issues hay abiertos con label 'incident'?"
> "Revisa los comentarios del PR #142"
```

### AWS MCP

Conecta Codex directamente con servicios AWS sin necesidad de que ejecute comandos de CLI:

```toml
[mcp.servers.aws]
command = "npx"
args = ["-y", "mcp-server-aws"]
env = { AWS_PROFILE = "${AWS_PROFILE}", AWS_REGION = "${AWS_REGION}" }
```

**Ejemplo de uso:**
```
> "¿Cuántas instancias EC2 están corriendo en staging?"
> "Muéstrame los últimos errores en CloudWatch para el servicio de pagos"
> "¿Qué alarmas están activas ahora?"
```

> **⚠️ Importante:** Configura el MCP de AWS apuntando siempre a la cuenta de staging por defecto. Cambiar a producción debe ser un acto consciente.

### Slack MCP

Para notificaciones y comunicación durante incidentes:

```toml
[mcp.servers.slack]
command = "npx"
args = ["-y", "@anthropic/mcp-server-slack"]
env = { SLACK_BOT_TOKEN = "${SLACK_BOT_TOKEN}" }
```

**Ejemplo de uso:**
```
> "Envía un resumen del incidente al canal #sre-incidents"
> "¿Qué mensajes hay recientes en #alerts?"
```

### Datadog MCP

Para observabilidad integrada:

```toml
[mcp.servers.datadog]
command = "npx"
args = ["-y", "mcp-server-datadog"]
env = { DD_API_KEY = "${DD_API_KEY}", DD_APP_KEY = "${DD_APP_KEY}" }
```

## MCP + Skills: La Combinación Poderosa

La magia real ocurre cuando combinas Skills (el "cómo") con MCPs (las "herramientas"):

```
Skill: incident-response          MCPs disponibles:
┌────────────────────┐            ┌─────────────┐
│ 1. Verificar       │───────────▶│ AWS MCP     │ (CloudWatch, EC2)
│    estado           │            └─────────────┘
│                    │            ┌─────────────┐
│ 2. Diagnosticar   │───────────▶│ Datadog MCP │ (métricas, logs)
│                    │            └─────────────┘
│                    │            ┌─────────────┐
│ 3. Notificar      │───────────▶│ Slack MCP   │ (canales)
│    equipo          │            └─────────────┘
│                    │            ┌─────────────┐
│ 4. Crear ticket   │───────────▶│ GitHub MCP  │ (issues)
│                    │            └─────────────┘
└────────────────────┘
```

Ejemplo real: durante un incidente, le dices a Codex *"investiga la alerta de alta latencia en el servicio de pagos"* y:

1. El **skill** de incident-response se activa (sabe el procedimiento)
2. Usa el **MCP de AWS** para revisar CloudWatch
3. Usa el **MCP de Datadog** para ver métricas detalladas
4. Usa el **MCP de Slack** para notificar al canal de incidentes
5. Usa el **MCP de GitHub** para crear el issue de seguimiento

Todo esto orquestado por el skill, usando las herramientas vía MCP.

## Seguridad en MCPs

### Principio de mínimo privilegio

Configura cada MCP con los permisos mínimos necesarios:

```toml
# MAL: Token con permisos amplios
[mcp.servers.github]
env = { GITHUB_PERSONAL_ACCESS_TOKEN = "${GITHUB_ADMIN_TOKEN}" }

# BIEN: Token con scope limitado
[mcp.servers.github]
env = { GITHUB_PERSONAL_ACCESS_TOKEN = "${GITHUB_READONLY_TOKEN}" }
```

### Perfiles AWS separados

```bash
# ~/.aws/config
[profile codex-staging]
region = us-east-1
role_arn = arn:aws:iam::STAGING_ACCOUNT:role/codex-readonly

[profile codex-prod]
region = us-east-1
role_arn = arn:aws:iam::PROD_ACCOUNT:role/codex-readonly
# Nota: el rol de prod es READONLY
```

```toml
# .codex/config.toml — apunta a staging por defecto
[mcp.servers.aws]
env = { AWS_PROFILE = "codex-staging" }
```

### Recomendaciones de seguridad para MCPs

1. **Tokens con scope mínimo:** Solo los permisos que el MCP necesita
2. **Cuentas de staging por defecto:** Producción solo bajo demanda explícita
3. **Roles readonly para producción:** El MCP de AWS en prod solo puede leer
4. **Variables de entorno, nunca hardcoded:** Usa `${VAR}` en config.toml
5. **Rotación de tokens:** Incluir recordatorio en el runbook del equipo

## Demo en vivo

```bash
# 1. Instalar un MCP server
npm install -g @modelcontextprotocol/server-github

# 2. Configurar en .codex/config.toml
# (mostrar el archivo de configuración)

# 3. Iniciar Codex y verificar que detecta los MCPs
codex "¿Qué herramientas externas tienes disponibles?"

# 4. Usar un MCP
codex "Usando GitHub, muéstrame los PRs abiertos en este repo"
```

## Puntos clave

1. **MCPs = herramientas externas** accesibles para Codex de forma segura
2. Se configuran en `.codex/config.toml` por proyecto
3. **MCP + Skills = automatización completa**: el skill define el flujo, los MCPs proveen las herramientas
4. **Seguridad**: tokens mínimos, staging por defecto, readonly en producción
5. Nunca hardcodear credenciales — siempre variables de entorno

---

**Siguiente:** [Módulo 05 - Hooks y Guardrails →](05-hooks-guardrails.md)
