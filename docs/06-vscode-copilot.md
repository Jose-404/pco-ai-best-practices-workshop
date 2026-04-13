# Módulo 06: Integración VSCode + GitHub Copilot (Codex y Claude)

**Duración:** 10 minutos | **Dinámica:** Demo

---

## El Panorama: Múltiples Modelos, Un Solo IDE

Con GitHub Copilot Business/Pro+/Enterprise en VSCode, ya no estás limitado a un solo modelo. Puedes alternar entre:

- **GPT-5.3-Codex** (OpenAI) — el que hemos configurado en este taller
- **Claude Sonnet 4.6** (Anthropic) — rápido, excelente para código y revisiones
- **Claude Opus 4.6** (Anthropic) — máxima capacidad de razonamiento
- **Gemini** (Google) — opción adicional

La buena noticia: **las configuraciones de instrucciones y MCPs funcionan con todos los modelos**. El gobierno que establezcas aplica independientemente del modelo que elija cada miembro del equipo.

## Selección de Modelo en VSCode

En el panel de Copilot Chat, el model picker está disponible en la esquina del input:

```
┌──────────────────────────────────────────┐
│  Copilot Chat                            │
│                                          │
│  ┌────────────────────────────────────┐  │
│  │ Escribe tu mensaje...              │  │
│  │                            [⚙️ GPT] │  │ ← Click aquí para cambiar modelo
│  └────────────────────────────────────┘  │
│                                          │
│  Modelos disponibles:                    │
│  ☑ GPT-5.3-Codex                        │
│  ○ Claude Sonnet 4.6                    │
│  ○ Claude Opus 4.6                      │
│  ○ Gemini                               │
└──────────────────────────────────────────┘
```

Para habilitar Claude como agente en Copilot:

```json
// settings.json de VSCode
{
    "github.copilot.chat.claudeAgent.enabled": true
}
```

## Sistema de Instrucciones en VSCode: Arquitectura Unificada

VSCode/Copilot soporta múltiples archivos de instrucciones que funcionan con **todos** los modelos:

```
tu-proyecto/
├── .github/
│   ├── copilot-instructions.md              # Instrucciones globales del proyecto
│   └── instructions/
│       ├── terraform.instructions.md        # Instrucciones por contexto (Terraform)
│       ├── kubernetes.instructions.md       # Instrucciones por contexto (K8s)
│       └── aws.instructions.md              # Instrucciones por contexto (AWS)
├── AGENTS.md                                # Leído por Codex Y por Copilot
├── CLAUDE.md                                # Instrucciones específicas para Claude
└── .codex/
    └── config.toml                          # Configuración específica de Codex CLI
```

### Jerarquía de instrucciones en VSCode

| Archivo | Quién lo lee | Propósito |
|---------|-------------|-----------|
| `.github/copilot-instructions.md` | Todos los modelos en Copilot | Instrucciones globales del proyecto |
| `.github/instructions/*.instructions.md` | Todos los modelos en Copilot | Instrucciones por contexto/path |
| `AGENTS.md` | Codex CLI + Copilot agents | Instrucciones para agentes |
| `CLAUDE.md` | Solo Claude (en Copilot y CLI) | Instrucciones específicas para Claude |
| `.codex/config.toml` | Solo Codex CLI | Configuración técnica de Codex |

### Instrucciones por contexto con YAML frontmatter

Los archivos `.instructions.md` permiten definir **a qué paths aplican**:

```markdown
---
# .github/instructions/terraform.instructions.md
applyTo: "**/*.tf"
excludeAgent: ["gemini"]
---

# Instrucciones para archivos Terraform

## Reglas
- Siempre incluir tags obligatorios: Environment, Team, ManagedBy
- Usar módulos internos de `modules/` antes de crear recursos directamente
- Nunca hardcodear valores — usar variables con defaults seguros
- Todo recurso debe tener un `description` en su variable

## Naming convention
- Recursos: `{env}-{servicio}-{recurso}`
- Variables: snake_case descriptivo
- Outputs: `{recurso}_{atributo}`
```

```markdown
---
# .github/instructions/aws.instructions.md
applyTo: "scripts/aws/**"
---

# Instrucciones para scripts AWS

## Seguridad
- Siempre verificar la cuenta activa antes de ejecutar
- Usar `--dry-run` cuando esté disponible
- Logs de operaciones van a `.codex/audit-logs/`
- Nunca ejecutar en producción sin confirmación explícita
```

La propiedad `excludeAgent` permite excluir modelos específicos si alguna instrucción no aplica para cierto agente.

## MCPs en VSCode: .vscode/mcp.json

Los MCPs se configuran en `.vscode/mcp.json` y están disponibles para **todos los modelos** en Copilot:

```json
// .vscode/mcp.json
{
    "servers": {
        "github": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-github"],
            "env": {
                "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
            }
        },
        "aws": {
            "command": "npx",
            "args": ["-y", "mcp-server-aws"],
            "env": {
                "AWS_PROFILE": "${AWS_PROFILE}",
                "AWS_REGION": "${AWS_REGION}"
            }
        },
        "playwright": {
            "command": "npx",
            "args": ["-y", "@anthropic/mcp-server-playwright"]
        }
    }
}
```

> **Nota:** La key raíz es `"servers"` (no `"mcpServers"`). Este es un error común.

### Agregar MCP servers desde la Command Palette

También puedes agregar servers desde la UI:

1. Abre la Command Palette (`Ctrl+Shift+P` / `Cmd+Shift+P`)
2. Busca: `MCP: Add Server`
3. Selecciona el tipo (stdio, SSE)
4. Configura el comando y argumentos

### Descubrir MCPs desde Claude Desktop

Si usas Claude Desktop, puedes habilitar el descubrimiento automático de MCPs:

```json
// settings.json de VSCode
{
    "chat.mcp.discovery.enabled": true
}
```

Esto permite que VSCode detecte y reutilice los MCP servers que ya tienes configurados en Claude Desktop.

## Claude en VSCode: Consideraciones Específicas

### CLAUDE.md: Instrucciones solo para Claude

Si necesitas instrucciones específicas para Claude (por su estilo de razonamiento diferente), usa `CLAUDE.md`:

```markdown
# CLAUDE.md — Instrucciones específicas para Claude

## Razonamiento
- Usa razonamiento paso a paso para operaciones de infraestructura
- Antes de ejecutar, explica qué harás y por qué
- Si hay ambigüedad, pregunta en vez de asumir

## Formato de respuesta
- Muestra los comandos que ejecutarás antes de hacerlo
- Para Terraform, siempre muestra el diff esperado
- Incluye el output relevante en tu respuesta

## Seguridad (complementa a AGENTS.md)
- Las mismas reglas de AGENTS.md aplican aquí
- Adicionalmente: para operaciones complejas, desglosa en pasos
  y confirma cada paso antes de continuar
```

### El comando `/delegate`

Desde Copilot Chat puedes delegar tareas a agentes específicos:

```
/delegate @codex "ejecuta terraform plan y muéstrame el resumen"
/delegate @claude "revisa este security group y dime si hay riesgos"
```

Esto es útil para aprovechar las fortalezas de cada modelo: Codex para ejecución de comandos, Claude para análisis y revisión.

## Configuración Recomendada para el Equipo

### settings.json compartido del equipo

```json
// .vscode/settings.json (versionado con el repo)
{
    "github.copilot.chat.claudeAgent.enabled": true,
    "chat.mcp.discovery.enabled": true,
    "github.copilot.chat.codeGeneration.instructions": [
        { "file": ".github/copilot-instructions.md" }
    ]
}
```

### Estructura completa recomendada

```
tu-proyecto/
├── .github/
│   ├── copilot-instructions.md           # Instrucciones para todos los modelos en Copilot
│   └── instructions/
│       ├── terraform.instructions.md     # Contexto: archivos .tf
│       ├── kubernetes.instructions.md    # Contexto: archivos K8s
│       └── aws.instructions.md           # Contexto: scripts AWS
├── .vscode/
│   ├── settings.json                     # Config compartida del equipo
│   └── mcp.json                          # MCPs accesibles desde VSCode
├── AGENTS.md                             # Para Codex CLI + Copilot agents
├── AGENTS.override.md                    # Reglas inamovibles (Codex)
├── CLAUDE.md                             # Instrucciones específicas Claude
├── .codex/
│   ├── config.toml                       # Config de Codex CLI
│   ├── hooks.json                        # Hooks (solo Codex CLI)
│   └── hooks/
│       └── safety-check.sh
├── skills/                               # Skills para Codex
│   └── .../SKILL.md
└── agents/
    └── openai.yaml                       # Registro de skills
```

## Cuándo usar cada modelo

| Tarea | Modelo recomendado | Por qué |
|-------|-------------------|---------|
| Ejecutar comandos y modificar archivos | Codex (CLI o Copilot) | Sandbox nativo, hooks, approval system |
| Revisión de código y análisis de seguridad | Claude Sonnet 4.6 | Excelente razonamiento sobre código |
| Arquitectura y decisiones complejas | Claude Opus 4.6 | Máxima capacidad de razonamiento |
| Refactoring rápido | Codex / Claude Sonnet | Ambos son rápidos y precisos |
| Investigación y troubleshooting | Claude Opus 4.6 | Razonamiento profundo y metódico |

## Puntos clave

1. **Un gobierno, múltiples modelos**: `.github/copilot-instructions.md` y `AGENTS.md` aplican a todos
2. **MCPs compartidos** vía `.vscode/mcp.json` — cualquier modelo puede usar las mismas herramientas
3. **`CLAUDE.md`** para instrucciones específicas de Claude, sin afectar a Codex
4. **Instrucciones por contexto** (`.instructions.md`) para reglas que solo aplican a ciertos archivos
5. Hooks de Codex CLI **no aplican en Copilot** — por eso las instrucciones en archivos son la capa de gobierno universal

---

**← Volver al [índice](../README.md)**
