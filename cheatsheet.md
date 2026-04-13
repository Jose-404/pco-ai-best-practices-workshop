# Cheatsheet — Referencia Rápida Post-Taller

## Archivos de Configuración

| Archivo | Ubicación | Propósito |
|---------|-----------|-----------|
| `~/.codex/config.toml` | Home (global) | Defaults personales de Codex CLI |
| `~/.codex/AGENTS.md` | Home (global) | Instrucciones globales para Codex |
| `.codex/config.toml` | Raíz del repo | Config de proyecto (modelo, sandbox, MCPs) |
| `.codex/hooks.json` | Raíz del repo | Registro de hooks de seguridad |
| `.codex/hooks/*.sh` | Raíz del repo | Scripts de hooks |
| `AGENTS.md` | Raíz del repo | Instrucciones del proyecto para Codex + Copilot |
| `AGENTS.override.md` | Raíz del repo | Reglas inamovibles (máxima prioridad) |
| `CLAUDE.md` | Raíz del repo | Instrucciones solo para Claude |
| `.github/copilot-instructions.md` | Repo | Instrucciones para todos los modelos en Copilot |
| `.github/instructions/*.instructions.md` | Repo | Instrucciones por contexto/path |
| `.vscode/mcp.json` | Repo | MCPs accesibles desde VSCode |
| `agents/openai.yaml` | Repo | Registro de skills para Codex |

## Modos de Aprobación

```bash
codex --approval-mode suggest     # Pide aprobación para TODO (recomendado infra)
codex --approval-mode auto-edit   # Auto-edita archivos, pide aprobación para shell
codex --approval-mode full-auto   # Todo automático (NUNCA en producción)
```

## Copiar Configuración a un Proyecto Nuevo

```bash
# Desde la raíz de este repo de workshop
cp examples/AGENTS.md ~/mi-proyecto/
cp examples/AGENTS.override.md ~/mi-proyecto/
cp -r examples/.codex ~/mi-proyecto/
cp -r examples/skills ~/mi-proyecto/
cp -r examples/agents ~/mi-proyecto/
chmod +x ~/mi-proyecto/.codex/hooks/*.sh
```

## Crear un Skill Nuevo

```bash
mkdir -p skills/mi-skill
cat > skills/mi-skill/SKILL.md << 'EOF'
---
name: mi-skill
description: Descripción corta de qué hace
---
# Nombre del Skill
## Cuándo usar
[trigger]
## Procedimiento
1. [pasos]
## Restricciones
- [límites]
EOF
```

Registrar en `agents/openai.yaml`:
```yaml
  - name: mi-skill
    description: Descripción corta
    path: skills/mi-skill/SKILL.md
```

## Crear un Hook Nuevo

```bash
cat > .codex/hooks/mi-hook.sh << 'HOOK'
#!/bin/bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.command // .arguments.command // empty')
# Tu lógica aquí
# exit 0 = permitir | exit 1 = bloquear
exit 0
HOOK
chmod +x .codex/hooks/mi-hook.sh
```

Registrar en `.codex/hooks.json`:
```json
{
  "event": "pre-tool-call",
  "command": ".codex/hooks/mi-hook.sh",
  "description": "Descripción del hook",
  "timeout_ms": 5000
}
```

## Configurar MCP en VSCode

`.vscode/mcp.json`:
```json
{
    "servers": {
        "nombre": {
            "command": "npx",
            "args": ["-y", "paquete-mcp"],
            "env": { "TOKEN": "${MI_TOKEN}" }
        }
    }
}
```

## Modelo en VSCode/Copilot

```
Cmd+Shift+P → "Copilot: Change Model" → Seleccionar modelo
```

| Tarea | Modelo sugerido |
|-------|----------------|
| Ejecutar comandos | Codex |
| Revisar código | Claude Sonnet 4.6 |
| Arquitectura compleja | Claude Opus 4.6 |

## Defensa en Profundidad (capas de seguridad)

```
Capa 1: AGENTS.md / AGENTS.override.md  → Instrucciones al modelo
Capa 2: Hooks (pre-tool-call)           → Bloqueo programático
Capa 3: Approval mode (suggest)         → Control manual
Capa 4: Sandbox del OS                  → Restricción de sistema
Capa 5: IAM roles readonly             → Permisos mínimos en AWS
```
