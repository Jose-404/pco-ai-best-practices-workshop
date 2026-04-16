# Módulo 06: Integración VSCode + GitHub Copilot (Codex y Claude)

**Duración:** 10 minutos | **Dinámica:** Demo

---

## El Panorama: Múltiples Modelos, Un Solo IDE

Con GitHub Copilot Business/Pro+/Enterprise en VSCode puedes usar varios modelos desde el mismo chat:

- **GPT-5.3-Codex** (OpenAI) — el que hemos configurado en este taller
- **Claude Sonnet 4.6** (Anthropic) — rápido, excelente para código y revisiones
- **Claude Opus 4.6** (Anthropic) — máxima capacidad de razonamiento
- **Gemini** (Google) — opción adicional

La pregunta clave del módulo es: **¿cómo evito repetir la misma configuración en cada repositorio?** La respuesta es entender qué vive a nivel global (VSCode) y qué vive a nivel de proyecto (repo).

```
┌─────────────────────────────────────────────────────────────────┐
│  NIVEL GLOBAL — VSCode (aplica a TODOS los repos)               │
│  • MCPs: MCP: Open User Configuration → user mcp.json           │
│  • Instrucciones: settings.json de usuario + Settings Sync      │
│  • Modelos habilitados: settings.json de usuario                │
├─────────────────────────────────────────────────────────────────┤
│  NIVEL PROYECTO — Repo (aplica a este repo, se versiona con Git) │
│  • MCPs adicionales: .vscode/mcp.json                           │
│  • Instrucciones del proyecto: .github/copilot-instructions.md  │
│  • Skills: agents/openai.yaml + skills/*/SKILL.md               │
│  • Reglas por tipo de archivo: .github/instructions/*.md        │
│  • Gobierno del agente: AGENTS.md, AGENTS.override.md           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Paso 1: Instalar y autenticar GitHub Copilot

1. Abre VSCode → **Extensions** (`Cmd+Shift+X` / `Ctrl+Shift+X`)
2. Busca `GitHub Copilot` → **Install**
3. Autentícate con tu cuenta de GitHub cuando lo pida
4. Verifica: en la barra inferior de VSCode debe aparecer el ícono de Copilot (✓)

---

## Paso 2: Habilitar Claude como agente (configuración global)

Claude no viene habilitado por defecto. Se activa en el `settings.json` de **usuario** (global, no por repo):

1. `Cmd+Shift+P` → `Preferences: Open User Settings (JSON)`
2. Agrega:

```json
{
    "github.copilot.chat.claudeAgent.enabled": true,
    "chat.mcp.discovery.enabled": true
}
```

> **Ubicación del settings.json de usuario:**
> - macOS: `~/Library/Application Support/Code/User/settings.json`
> - Windows: `%APPDATA%\Code\User\settings.json`
> - Linux: `~/.config/Code/User/settings.json`

Este archivo **no se versiona con Git** — es personal de tu máquina. Para compartirlo con el equipo, usa **Settings Sync** (ver Paso 6).

---

## Paso 3: Configurar MCPs Globales

Esta es la respuesta a tu pregunta: **sí existe configuración global de MCPs en VSCode**. Los servidores que configures aquí estarán disponibles en **todos tus repositorios**, sin tener que repetir nada.

### Abrir la configuración global de MCPs

```
Cmd+Shift+P → MCP: Open User Configuration
```

Esto abre el archivo `mcp.json` de usuario (equivalente global de `.vscode/mcp.json`). Configura aquí los MCPs que uses en todos tus proyectos:

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
        "aws-staging": {
            "command": "npx",
            "args": ["-y", "mcp-server-aws"],
            "env": {
                "AWS_PROFILE": "staging",
                "AWS_REGION": "us-east-1"
            }
        },
        "slack": {
            "command": "npx",
            "args": ["-y", "@anthropic/mcp-server-slack"],
            "env": {
                "SLACK_BOT_TOKEN": "${SLACK_BOT_TOKEN}"
            }
        }
    }
}
```

> **Importante:** La clave raíz debe ser `"servers"` — no `"mcpServers"`. Error muy común.

> **Variables de entorno:** `${GITHUB_TOKEN}` lee la variable de entorno del sistema. Nunca escribas el token directamente en el archivo.

### MCPs por repo (adicionales)

Si un repo específico necesita un MCP adicional que no tienen los demás, agrégalo en `.vscode/mcp.json` dentro del proyecto. VSCode combina ambas fuentes automáticamente:

```json
// .vscode/mcp.json — solo lo que es específico de este repo
{
    "servers": {
        "datadog": {
            "command": "npx",
            "args": ["-y", "mcp-server-datadog"],
            "env": {
                "DD_API_KEY": "${DD_API_KEY}",
                "DD_APP_KEY": "${DD_APP_KEY}"
            }
        }
    }
}
```

> **Regla práctica:** MCPs que usas en todos lados → global. MCPs específicos de un proyecto → `.vscode/mcp.json`.

### Descubrimiento automático desde Claude Desktop

Si ya tienes MCPs en Claude Desktop, VSCode puede importarlos automáticamente (sin reconfigurar):

```json
// settings.json de usuario
{
    "chat.mcp.discovery.enabled": true
}
```

---

## Paso 4: Configurar Skills en VSCode

Los Skills funcionan **igual en VSCode que en Codex CLI**. Copilot escanea el repositorio buscando el archivo `agents/openai.yaml` y carga las descripciones de los skills disponibles. Cuando escribes una solicitud en el chat, Copilot determina si algún skill aplica y carga sus instrucciones completas.

### Cómo Copilot descubre los skills

El mecanismo es idéntico al de Codex CLI (progressive disclosure):

```
1. Copilot lee agents/openai.yaml → obtiene nombre y descripción de cada skill
2. Compara la descripción con tu solicitud
3. Si hay match → carga el SKILL.md completo
4. Ejecuta el procedimiento del skill usando los MCPs disponibles
```

### Usar un skill desde el chat

Simplemente escribe lo que necesitas — Copilot activa el skill automáticamente:

```
Tú: "revisa los security groups de la cuenta de staging"
→ Copilot activa el skill aws-sg-audit automáticamente

Tú: "valida el plan de terraform antes de aplicar"
→ Copilot activa el skill terraform-safety

Tú: "hay una alerta de alta latencia en el servicio de pagos"
→ Copilot activa el skill incident-response
```

También puedes invocar un skill explícitamente con `@`:

```
@aws-sg-audit revisa los security groups de la VPC vpc-0abc123
```

### Skills globales vs skills por repo

A diferencia de los MCPs, **los Skills no tienen una ubicación global en VSCode** — siempre viven en el repositorio (`agents/openai.yaml` + `skills/*/SKILL.md`). La estrategia para no repetirlos en cada repo es:

**Opción 1 — Repositorio de configuración compartida (recomendado):**
Crear un repo central con todos los skills del equipo (como este workshop):

```bash
# En cada proyecto, clonar o submodule el repo de skills
git submodule add git@github.com:tu-org/devops-skills.git skills
```

**Opción 2 — Copiar con un script de bootstrap:**
Un script de onboarding que cada persona ejecuta una vez:

```bash
# bootstrap-codex.sh — ejecutar al configurar un proyecto nuevo
cp -r ~/devops-skills/skills ./skills
cp ~/devops-skills/agents/openai.yaml ./agents/openai.yaml
```

**Opción 3 — GitHub Organization Skills (Enterprise):**
Con GitHub Enterprise, los Skills pueden definirse a nivel de organización y estar disponibles en todos los repos automáticamente.

---

## Paso 5: Instrucciones para el equipo (por repo)

Las instrucciones de Copilot para el proyecto van en `.github/copilot-instructions.md`. Este archivo aplica a todos los modelos (Codex, Claude, Gemini):

```bash
mkdir -p .github
```

```markdown
# .github/copilot-instructions.md

## Idioma
Responde siempre en español.

## Contexto
Equipo DevOps-SRE — AWS (EKS, RDS, S3), Terraform 1.8+, GitHub Actions.

## Reglas
- Nunca sugieras comandos destructivos sin advertencia explícita
- Siempre incluye --dry-run cuando el comando lo soporte
- Usa Conventional Commits en español
- Incluye tags AWS obligatorios: Environment, Team, ManagedBy
```

### Instrucciones globales: alternativas para no repetir por repo

No existe un equivalente global de `.github/copilot-instructions.md` directamente en VSCode, pero hay tres alternativas:

**A) GitHub Organization-level instructions (Business/Enterprise):**
En GitHub → Settings de la organización → Copilot → se pueden definir instrucciones que aplican automáticamente a todos los repos de la org sin tocar ningún archivo.

**B) Settings Sync + archivo de instrucciones local:**
En el `settings.json` de usuario puedes apuntar a un archivo de instrucciones en tu máquina:

```json
// settings.json de usuario
{
    "github.copilot.chat.codeGeneration.instructions": [
        {
            "file": "/Users/tu-usuario/.codex/global-instructions.md"
        }
    ]
}
```

Crea ese archivo una vez y aplica a todos los repos sin que esté en Git:

```bash
cat > ~/.codex/global-instructions.md << 'EOF'
## Instrucciones globales DevOps-SRE
- Responde siempre en español
- Stack: AWS, Terraform, EKS, GitHub Actions
- Nunca ejecutes comandos destructivos sin confirmar
- Usa Conventional Commits
EOF
```

**C) VSCode Profiles:**
Crea un perfil "DevOps-SRE" en VSCode con toda la configuración del equipo (settings, extensions, MCPs). Los perfiles se sincronizan con Settings Sync y cualquier miembro del equipo puede importarlo en segundos.

```
Cmd+Shift+P → Profiles: Create Profile → "DevOps-SRE"
```

---

## Paso 6: Settings Sync — compartir configuración con el equipo

Settings Sync sincroniza tu configuración de VSCode (settings, extensiones, MCPs de usuario, perfiles) a tu cuenta de GitHub o Microsoft. El equipo puede usar el mismo perfil:

```
Cmd+Shift+P → Settings Sync: Turn On
```

Selecciona qué sincronizar:
- ✅ Settings
- ✅ Extensions
- ✅ Profiles
- ✅ MCP Servers (user-level)

Cada miembro activa Settings Sync una vez y hereda toda la configuración base del equipo.

---

## Paso 7: Settings.json del proyecto (config compartida del repo)

El `.vscode/settings.json` que vive **en el repo** aplica a cualquiera que abra ese proyecto. Se versiona con Git y es ideal para configuración específica del proyecto:

```json
// .vscode/settings.json (versionar con Git)
{
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

## Paso 8: Seleccionar modelo en el chat

Con todo configurado, cambiar de modelo es inmediato:

1. Abre Copilot Chat: `Cmd+Ctrl+I` (Mac) / `Ctrl+Alt+I` (Windows/Linux)
2. Haz clic en el selector de modelo (esquina inferior del chat)
3. Elige el modelo para la tarea

| Tarea | Modelo recomendado |
|-------|-------------------|
| Ejecutar comandos y modificar archivos | Codex |
| Revisión y análisis de código | Claude Sonnet 4.6 |
| Decisiones de arquitectura complejas | Claude Opus 4.6 |
| Troubleshooting largo y profundo | Claude Opus 4.6 |
| Refactoring rápido | Codex / Claude Sonnet |

---

## Resumen: qué va dónde

```
GLOBAL (una vez, aplica a todos los repos):
  ~/.codex/global-instructions.md       → Instrucciones globales personales
  settings.json de usuario              → Habilitar Claude, discovery de MCPs
  MCP: Open User Configuration          → MCPs que usas en todos los repos
  VSCode Profile "DevOps-SRE"           → Config del equipo (compartir via Sync)

POR REPO (versionado con Git, heredado por todo el equipo):
  .github/copilot-instructions.md       → Instrucciones del proyecto (todos los modelos)
  .github/instructions/*.instructions.md → Instrucciones por tipo de archivo
  .vscode/settings.json                 → Config de VSCode del proyecto
  .vscode/mcp.json                      → MCPs adicionales del proyecto
  AGENTS.md / AGENTS.override.md        → Gobierno del agente (Codex + Copilot)
  CLAUDE.md                             → Instrucciones específicas para Claude
  agents/openai.yaml + skills/          → Skills disponibles para todos los modelos
```

> **Nota importante:** Los hooks de Codex CLI **no aplican** en Copilot VSCode — solo en la terminal. Por eso las instrucciones en `.github/copilot-instructions.md` y `AGENTS.md` son la capa de gobierno universal para el IDE.

---

**← Volver al [índice](../README.md)**
