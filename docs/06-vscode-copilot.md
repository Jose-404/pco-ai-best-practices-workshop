# Módulo 06: Integración VSCode + GitHub Copilot (Codex y Claude)

**Duración:** 10 minutos | **Dinámica:** Demo

---

## El Panorama: Múltiples Modelos, Un Solo IDE

Con GitHub Copilot Business/Pro+/Enterprise en VSCode, puedes alternar entre:

- **GPT-5.3-Codex** (OpenAI) — el que hemos configurado en este taller
- **Claude Sonnet 4.6** (Anthropic) — rápido, excelente para código y revisiones
- **Claude Opus 4.6** (Anthropic) — máxima capacidad de razonamiento
- **Gemini** (Google) — opción adicional disponible

La buena noticia: **las configuraciones de instrucciones y MCPs funcionan con todos los modelos**. El gobierno que establezcas aplica independientemente del modelo que elija cada miembro del equipo.

---

## Paso 1: Verificar que tienes GitHub Copilot activo en VSCode

Antes de cualquier configuración, confirma que la extensión está instalada y autenticada:

1. Abre VSCode
2. Ve a **Extensions** (`Cmd+Shift+X` / `Ctrl+Shift+X`)
3. Busca `GitHub Copilot` — debe aparecer como instalada y activa
4. En la barra inferior de VSCode debes ver el ícono de Copilot (✓ o la animación)

Si no está instalada:
```
Extensions → Buscar "GitHub Copilot" → Install
```
Luego autentícate con tu cuenta de GitHub cuando te lo pida.

---

## Paso 2: Habilitar Claude en Copilot

Claude no viene habilitado por defecto como agente en Copilot. Hay que activarlo explícitamente.

### Opción A: Desde la UI (recomendado para la primera vez)

1. Abre el panel de Copilot Chat con `Cmd+Ctrl+I` (Mac) o `Ctrl+Alt+I` (Windows/Linux)
2. En el selector de modelo (esquina inferior del chat), haz clic en el nombre del modelo actual
3. Si ves `Claude Sonnet 4.6` o `Claude Opus 4.6` en la lista, ya está disponible — selecciónalo
4. Si no aparece, continúa con la Opción B

### Opción B: Via settings.json

Abre tu `settings.json` de usuario en VSCode:

1. `Cmd+Shift+P` (Mac) / `Ctrl+Shift+P` (Windows/Linux)
2. Escribe: `Preferences: Open User Settings (JSON)`
3. Se abre el archivo `settings.json` de tu usuario
4. Agrega esta línea dentro del objeto JSON:

```json
{
    "github.copilot.chat.claudeAgent.enabled": true
}
```

> **¿Dónde queda este archivo?**
> - macOS: `~/Library/Application Support/Code/User/settings.json`
> - Windows: `%APPDATA%\Code\User\settings.json`
> - Linux: `~/.config/Code/User/settings.json`

---

## Paso 3: Configurar MCPs en VSCode

Los MCPs se configuran en un archivo dentro de tu repositorio: `.vscode/mcp.json`. Este archivo **sí se versiona con Git** para que todo el equipo comparta las mismas conexiones.

### Crear el archivo `.vscode/mcp.json`

Si la carpeta `.vscode/` no existe en tu proyecto, créala:

```bash
mkdir -p .vscode
```

Luego crea el archivo `.vscode/mcp.json`:

```json
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
        }
    }
}
```

> **Importante:** La clave raíz debe ser `"servers"` — no `"mcpServers"`. Este es un error muy común.

> **Sobre las variables de entorno:** `${GITHUB_TOKEN}` toma el valor de la variable de entorno del sistema. No pongas el token directamente en el archivo.

### Agregar un MCP desde la Command Palette (alternativa)

1. `Cmd+Shift+P` → escribe `MCP: Add Server`
2. Selecciona el tipo de transporte: `stdio` (la mayoría) o `SSE`
3. Ingresa el comando (ej: `npx`) y los argumentos
4. VSCode escribe la entrada en `.vscode/mcp.json` automáticamente

### Habilitar descubrimiento automático desde Claude Desktop

Si usas Claude Desktop y ya tienes MCPs configurados allí, puedes hacer que VSCode los detecte automáticamente. Agrega esto a tu `settings.json` de usuario:

```json
{
    "github.copilot.chat.claudeAgent.enabled": true,
    "chat.mcp.discovery.enabled": true
}
```

---

## Paso 4: Configurar el settings.json compartido del equipo

Además del `settings.json` de usuario (personal, no se versiona), existe el `.vscode/settings.json` del proyecto, que **sí se versiona** y aplica a todos los miembros del equipo.

### Crear `.vscode/settings.json` del proyecto

```bash
# En la raíz del repositorio
touch .vscode/settings.json
```

Contenido recomendado para equipos DevOps-SRE:

```json
{
    "github.copilot.chat.claudeAgent.enabled": true,
    "chat.mcp.discovery.enabled": true,

    "github.copilot.chat.codeGeneration.instructions": [
        { "file": ".github/copilot-instructions.md" }
    ],

    "editor.formatOnSave": true,
    "editor.rulers": [120],

    "files.associations": {
        "*.tf": "terraform",
        "*.tfvars": "terraform",
        "*.hcl": "hcl",
        "Dockerfile*": "dockerfile"
    },

    "files.exclude": {
        "**/.terraform": true,
        "**/tfplan": true,
        "**/.codex/audit-logs": true
    }
}
```

---

## Paso 5: Configurar instrucciones de Copilot para todo el equipo

Crea el archivo `.github/copilot-instructions.md` en la raíz del repo. Este archivo es **leído por todos los modelos** (Codex, Claude, Gemini) cuando se usan desde Copilot en VSCode.

```bash
mkdir -p .github
```

Ejemplo para un equipo DevOps-SRE:

```markdown
# Instrucciones para GitHub Copilot — Equipo DevOps-SRE

## Idioma
Responde siempre en español.

## Contexto
Somos un equipo DevOps-SRE trabajando con AWS, Terraform y EKS.

## Reglas
- Nunca sugieras comandos destructivos sin advertencia explícita
- Siempre incluye `--dry-run` cuando el comando lo soporte
- Usa Conventional Commits en español para mensajes de commit
- Incluye siempre tags AWS en recursos Terraform: Environment, Team, ManagedBy
```

---

## Paso 6: Instrucciones por contexto de archivo

Para reglas que solo aplican a ciertos tipos de archivos, usa `.github/instructions/`:

```bash
mkdir -p .github/instructions
```

Ejemplo para archivos Terraform:

```markdown
---
# .github/instructions/terraform.instructions.md
applyTo: "**/*.tf"
---

Al trabajar con archivos Terraform:
- Siempre valida con `terraform plan` antes de sugerir `apply`
- Incluye tags obligatorios: Environment, Team, ManagedBy
- Usa módulos del directorio `modules/` cuando existan
- Sigue la convención de nombres: `{env}-{servicio}-{recurso}`
```

La propiedad `applyTo` hace que estas instrucciones se activen automáticamente **solo cuando estás editando archivos `.tf`**, sin afectar al resto del proyecto.

---

## Paso 7: Seleccionar modelo en el chat

Con todo configurado, cambiar de modelo es inmediato:

1. Abre Copilot Chat: `Cmd+Ctrl+I` / `Ctrl+Alt+I`
2. Haz clic en el selector de modelo (ícono ⚙️ o el nombre del modelo actual)
3. Selecciona el modelo que quieras usar

```
┌──────────────────────────────────────────────┐
│  Copilot Chat                                │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │ ¿Cómo puedo ayudarte?               │    │
│  │                          [⚙ Codex ▼] │    │  ← Click aquí
│  └──────────────────────────────────────┘    │
│                                              │
│  Modelos disponibles:                        │
│  ✓ GPT-5.3-Codex                            │
│  ○ Claude Sonnet 4.6                        │
│  ○ Claude Opus 4.6                          │
│  ○ Gemini                                   │
└──────────────────────────────────────────────┘
```

---

## Cuándo usar cada modelo

| Tarea | Modelo recomendado | Por qué |
|-------|-------------------|---------|
| Ejecutar comandos y modificar archivos | Codex | Sandbox nativo, hooks, approval system |
| Revisión y análisis de código | Claude Sonnet 4.6 | Razonamiento rápido y preciso |
| Decisiones de arquitectura complejas | Claude Opus 4.6 | Máxima profundidad de razonamiento |
| Troubleshooting largo y profundo | Claude Opus 4.6 | Mantiene el hilo en problemas complejos |
| Refactoring rápido | Codex / Claude Sonnet | Ambos son rápidos y precisos |

---

## Resumen: Archivos del equipo en VSCode

```
tu-proyecto/
├── .github/
│   ├── copilot-instructions.md           # Instrucciones globales (todos los modelos)
│   └── instructions/
│       └── terraform.instructions.md    # Instrucciones solo para archivos .tf
├── .vscode/
│   ├── settings.json                     # Config compartida del equipo (versionar)
│   └── mcp.json                          # MCPs disponibles en VSCode (versionar)
├── AGENTS.md                             # Para Codex CLI + Copilot agents
├── AGENTS.override.md                    # Reglas inamovibles
└── CLAUDE.md                             # Instrucciones específicas para Claude
```

> **Nota:** Los hooks de Codex CLI **no aplican** cuando usas Claude o Codex desde Copilot en VSCode — solo funcionan en el CLI. Por eso las instrucciones en `.github/copilot-instructions.md` y `AGENTS.md` son la capa de gobierno universal para el IDE.

---

**← Volver al [índice](../README.md)**
