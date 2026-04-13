# Módulo 01: Fundamentos y Setup de Codex CLI

**Duración:** 15 minutos | **Dinámica:** Demo

---

## ¿Qué es Codex CLI?

Codex CLI es un agente de código que corre en tu terminal. A diferencia de un autocompletado o un chatbot, Codex puede leer tu codebase, ejecutar comandos, editar archivos y orquestar tareas complejas de forma autónoma — todo bajo tu supervisión.

El modelo subyacente actual es **GPT-5.3-Codex** (o superior, según la versión disponible). La herramienta se instala como un paquete npm global:

```bash
npm install -g @openai/codex
```

Para verificar la instalación:

```bash
codex --version
```

## Arquitectura: Cómo funciona por dentro

```
┌─────────────────────────────────────────────────┐
│                   TU TERMINAL                    │
│                                                  │
│  ┌──────────┐    ┌──────────┐    ┌───────────┐  │
│  │ AGENTS.md│───▶│ Codex CLI│───▶│ Sandbox   │  │
│  │ Skills   │    │ (agente) │    │ (aislado) │  │
│  │ Hooks    │    │          │    │           │  │
│  │ MCPs     │───▶│  GPT-5.3 │───▶│ filesystem│  │
│  └──────────┘    │  -Codex  │    │ network   │  │
│   Configuración  └──────────┘    └───────────┘  │
│                       │                          │
│                       ▼                          │
│              ┌──────────────┐                    │
│              │  Approval    │                    │
│              │  System      │                    │
│              └──────────────┘                    │
└─────────────────────────────────────────────────┘
```

Codex opera en un **sandbox aislado por el sistema operativo**:

- **macOS:** Seatbelt policies (sandbox-exec)
- **Linux:** seccomp + landlock
- **Windows:** sandbox nativo o WSL

Esto significa que incluso en modo `full-auto`, Codex tiene restricciones a nivel de OS sobre qué puede tocar.

## Los 3 Modos de Aprobación

Este es el concepto más importante para la seguridad de tu equipo:

### `suggest` (Recomendado para producción)

```bash
codex --approval-mode suggest
```

Codex **propone** cada acción (lectura, escritura, comando) y espera tu aprobación explícita. Es el modo más seguro y el recomendado para cualquier operación que toque infraestructura.

### `auto-edit`

```bash
codex --approval-mode auto-edit
```

Codex puede leer archivos y hacer ediciones automáticamente, pero **pide aprobación para ejecutar comandos de shell**. Útil para refactoring de código donde confías en las ediciones pero quieres controlar qué se ejecuta.

### `full-auto`

```bash
codex --approval-mode full-auto
```

Codex ejecuta todo sin pedir aprobación. **Nunca usar en contextos de producción o infraestructura.** Incluso en este modo, el sandbox limita el alcance, pero el riesgo es significativamente mayor.

> **⚠️ Regla del equipo:** Para cualquier tarea que involucre AWS, Terraform, kubectl, o cualquier herramienta que modifique infraestructura, usamos **siempre** `suggest` o como máximo `auto-edit`.

## Configuración: Global vs. Proyecto

Codex tiene dos niveles de configuración:

### Global (`~/.codex/config.toml`)

Aplica a **todos** los proyectos. Ideal para preferencias personales y defaults de seguridad:

```toml
# ~/.codex/config.toml
model = "gpt-5.3-codex"
approval_mode = "suggest"        # Default seguro para todo

[sandbox]
allow_network = false            # Sin acceso a red por defecto
```

### Proyecto (`.codex/config.toml`)

Vive en la raíz de tu repositorio. Aplica solo a ese proyecto y se puede versionar con Git:

```toml
# .codex/config.toml
model = "gpt-5.3-codex"
approval_mode = "auto-edit"

[sandbox]
allow_network = true             # Este proyecto necesita red
allowed_hosts = [                # Solo estos hosts
    "registry.npmjs.org",
    "api.github.com"
]
```

La configuración de **proyecto sobreescribe la global**, lo que permite tener un default seguro y relajarlo solo donde sea necesario.

## Demo en vivo

```bash
# 1. Verificar instalación
codex --version

# 2. Ver configuración actual
codex config show

# 3. Iniciar una sesión en modo seguro
codex --approval-mode suggest

# 4. Ejemplo: pedir algo simple
# > "lista los archivos en el directorio actual"
# Codex propondrá: ls -la
# Tú apruebas o rechazas
```

## Puntos clave de este módulo

1. Codex CLI es un **agente autónomo** que opera dentro de un sandbox del OS
2. El modo de aprobación es tu **primera línea de defensa** — `suggest` para infraestructura, siempre
3. La configuración tiene dos capas: global (tus defaults) y proyecto (versionable con Git)
4. El sandbox limita acceso a filesystem y red incluso en modo `full-auto`

---

**Siguiente:** [Módulo 02 - AGENTS.md y Gobierno de Instrucciones →](02-agents-md-gobierno.md)
