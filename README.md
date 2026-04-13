# Workshop: Buenas Prácticas con Codex CLI para Equipos DevOps-SRE

## Objetivo

Capacitar al equipo DevOps-SRE en la configuración avanzada de **Codex CLI** (modelo GPT-5.3-Codex) para maximizar productividad y, sobre todo, **prevenir errores destructivos** en entornos cloud (AWS).

## Duración: 2 horas

## Audiencia

Equipo técnico DevOps-SRE con experiencia en AWS. Algunos usan Codex por CLI, otros desde VSCode vía GitHub Copilot.

---

## Agenda

| Tiempo | Módulo | Dinámica |
|--------|--------|----------|
| 15 min | [01 - Fundamentos y Setup](docs/01-fundamentos-setup.md) | Demo |
| 25 min | [02 - AGENTS.md y Gobierno de Instrucciones](docs/02-agents-md-gobierno.md) | Demo + Hands-on |
| 20 min | [03 - Skills](docs/03-skills.md) | Demo + Hands-on |
| 15 min | ☕ Break | — |
| 20 min | [04 - MCPs (Model Context Protocol)](docs/04-mcps.md) | Demo |
| 20 min | [05 - Hooks y Guardrails de Seguridad](docs/05-hooks-guardrails.md) | Demo + Hands-on |
| 10 min | [06 - Integración VSCode + GitHub Copilot](docs/06-vscode-copilot.md) | Demo |
| 5 min  | Cierre y Q&A | — |

## Estructura del Repositorio

```
pco-ai-best-practices-workshop/
├── README.md                              # Este archivo - índice general
├── docs/                                  # Material del taller por módulo
│   ├── 01-fundamentos-setup.md
│   ├── 02-agents-md-gobierno.md
│   ├── 03-skills.md
│   ├── 04-mcps.md
│   ├── 05-hooks-guardrails.md
│   └── 06-vscode-copilot.md
├── examples/                              # Archivos de configuración listos para usar
│   ├── AGENTS.md                          # AGENTS.md modelo para equipos DevOps-SRE
│   ├── AGENTS.override.md                 # Override para proyectos específicos
│   ├── .codex/
│   │   ├── config.toml                    # Configuración de proyecto Codex
│   │   └── hooks.json                     # Hooks de seguridad pre-configurados
│   ├── skills/
│   │   ├── aws-sg-audit/SKILL.md          # Skill: auditoría de Security Groups
│   │   ├── terraform-safety/SKILL.md      # Skill: validación pre-apply de Terraform
│   │   └── incident-response/SKILL.md     # Skill: runbook de respuesta a incidentes
│   └── agents/
│       └── openai.yaml                    # Registro de skills para Codex
└── cheatsheet.md                          # Referencia rápida post-taller
```

## Requisitos Previos

- Codex CLI instalado (`npm install -g @openai/codex`) o acceso vía GitHub Copilot en VSCode
- Cuenta OpenAI con acceso a Codex o GitHub Copilot Business/Pro+/Enterprise
- AWS CLI configurado (para los ejemplos prácticos)
- Git configurado en la máquina local

## Quick Start Post-Taller

```bash
# Copiar la configuración base a tu proyecto
cp examples/AGENTS.md ~/tu-proyecto/AGENTS.md
cp -r examples/.codex ~/tu-proyecto/.codex
cp -r examples/skills ~/tu-proyecto/skills

# Configurar Codex con aprobación para comandos destructivos
codex --approval-mode suggest
```
