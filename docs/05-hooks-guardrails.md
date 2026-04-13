# Módulo 05: Hooks y Guardrails de Seguridad

**Duración:** 20 minutos | **Dinámica:** Demo + Hands-on

---

## ¿Qué son los Hooks?

Los Hooks son **comandos de shell que se ejecutan automáticamente** en momentos específicos del ciclo de vida del agente. Son tu red de seguridad programática: mientras que `AGENTS.md` le *pide* al agente que no haga algo, los Hooks *impiden* que lo haga.

```
AGENTS.md        = "Por favor, no hagas esto"    (instrucción suave)
Hooks            = "No PUEDES hacer esto"         (bloqueo técnico)
Approval mode    = "Necesitas mi permiso"         (control manual)
Sandbox          = "No tienes acceso"             (restricción de OS)
```

Los Hooks son la capa que faltaba entre las instrucciones suaves y las restricciones del sistema operativo. Son programables, auditables y versionables con Git.

## Eventos del Ciclo de Vida

Codex dispara hooks en estos momentos:

```
Sesión inicia
    │
    ▼
┌──────────────┐
│ session-start│ ← Hook: validar entorno, verificar cuenta AWS
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  pre-prompt  │ ← Hook: inyectar contexto adicional antes de cada prompt
└──────┬───────┘
       │
       ▼  (por cada acción del agente)
┌──────────────────┐
│ pre-tool-call    │ ← Hook: INTERCEPTAR y validar cada comando/tool ANTES de ejecutar
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ post-tool-call   │ ← Hook: auditar/logear resultado después de ejecutar
└──────┬───────────┘
       │
       ▼
┌──────────────┐
│ per-turn      │ ← Hook: ejecutar al final de cada turno del agente
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ session-end  │ ← Hook: cleanup, generar resumen de auditoría
└──────────────┘
```

El hook más poderoso para seguridad es **`pre-tool-call`** porque puede **bloquear una acción antes de que se ejecute**.

## Configuración: hooks.json

Los hooks se definen en `.codex/hooks.json`:

```json
{
  "hooks": [
    {
      "event": "pre-tool-call",
      "command": ".codex/hooks/safety-check.sh",
      "description": "Valida comandos destructivos antes de ejecución",
      "timeout_ms": 5000
    },
    {
      "event": "session-start",
      "command": ".codex/hooks/verify-environment.sh",
      "description": "Verifica cuenta AWS y contexto al iniciar sesión",
      "timeout_ms": 10000
    },
    {
      "event": "post-tool-call",
      "command": ".codex/hooks/audit-log.sh",
      "description": "Registra cada acción en log de auditoría",
      "timeout_ms": 3000
    }
  ]
}
```

### Anatomía de un hook `pre-tool-call`

Cuando se dispara un `pre-tool-call`, Codex pasa información sobre la acción pendiente vía stdin (JSON). El hook puede:

- **Exit code 0** → Acción permitida, continuar
- **Exit code distinto de 0** → Acción bloqueada, Codex recibe el stderr como explicación

```bash
#!/bin/bash
# .codex/hooks/safety-check.sh
# Hook pre-tool-call: valida comandos antes de ejecución

# Leer la información del tool call desde stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.command // .arguments.command // empty')

# Si no hay comando que verificar, permitir
if [ -z "$COMMAND" ]; then
    exit 0
fi

# ============================================
# REGLA 1: Bloquear terraform destroy
# ============================================
if echo "$COMMAND" | grep -qiE 'terraform\s+destroy'; then
    echo "🚫 BLOQUEADO: 'terraform destroy' no está permitido vía Codex." >&2
    echo "   Ejecuta este comando manualmente con la supervisión del equipo." >&2
    exit 1
fi

# ============================================
# REGLA 2: Bloquear rm -rf en paths críticos
# ============================================
if echo "$COMMAND" | grep -qiE 'rm\s+(-[a-z]*f[a-z]*\s+|.*-rf\s+)(/|/etc|/var|/opt|/home|/root|\.\.)'; then
    echo "🚫 BLOQUEADO: 'rm -rf' en path crítico detectado." >&2
    echo "   Path protegido. Operación no permitida." >&2
    exit 1
fi

# ============================================
# REGLA 3: Bloquear kubectl delete en prod
# ============================================
if echo "$COMMAND" | grep -qiE 'kubectl\s+delete' && echo "$COMMAND" | grep -qiE '(prod|production)'; then
    echo "🚫 BLOQUEADO: 'kubectl delete' en namespace de producción." >&2
    echo "   Requiere ejecución manual con verificación del equipo." >&2
    exit 1
fi

# ============================================
# REGLA 4: Bloquear operaciones S3 destructivas en prod
# ============================================
if echo "$COMMAND" | grep -qiE 'aws\s+s3\s+(rm|rb)' && echo "$COMMAND" | grep -qiE '(prod|production)'; then
    echo "🚫 BLOQUEADO: Operación destructiva en bucket S3 de producción." >&2
    exit 1
fi

# ============================================
# REGLA 5: Bloquear force-push
# ============================================
if echo "$COMMAND" | grep -qiE 'git\s+push.*--force'; then
    echo "🚫 BLOQUEADO: 'git push --force' no está permitido." >&2
    echo "   Usa 'git push --force-with-lease' si es necesario." >&2
    exit 1
fi

# ============================================
# REGLA 6: Advertir sobre apply sin plan previo
# ============================================
if echo "$COMMAND" | grep -qiE 'terraform\s+apply' && ! echo "$COMMAND" | grep -q 'tfplan'; then
    echo "⚠️  BLOQUEADO: 'terraform apply' sin archivo de plan." >&2
    echo "   Primero ejecuta: terraform plan -out=tfplan" >&2
    echo "   Luego: terraform apply tfplan" >&2
    exit 1
fi

# Si llegamos aquí, el comando es permitido
exit 0
```

## Hook de Verificación de Entorno

```bash
#!/bin/bash
# .codex/hooks/verify-environment.sh
# Hook session-start: verifica el entorno antes de comenzar

echo "🔍 Verificando entorno de trabajo..."

# Verificar cuenta AWS activa
AWS_ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "⚠️  ADVERTENCIA: No hay sesión AWS activa." >&2
    echo "   Ejecuta 'aws sso login' o configura tus credenciales." >&2
    # No bloqueamos, solo advertimos
    exit 0
fi

AWS_ALIAS=$(aws iam list-account-aliases --query 'AccountAliases[0]' --output text 2>/dev/null)
AWS_REGION=$(aws configure get region 2>/dev/null || echo "no configurada")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Cuenta AWS: $AWS_ACCOUNT ($AWS_ALIAS)"
echo "  Región:     $AWS_REGION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Advertir si es cuenta de producción
PROD_ACCOUNTS=("123456789012" "987654321098")  # Reemplazar con tus cuentas
for PROD_ACCOUNT in "${PROD_ACCOUNTS[@]}"; do
    if [ "$AWS_ACCOUNT" = "$PROD_ACCOUNT" ]; then
        echo "" >&2
        echo "🔴 ¡ATENCIÓN! Estás conectado a la cuenta de PRODUCCIÓN." >&2
        echo "   Todas las operaciones destructivas requerirán confirmación extra." >&2
        echo "" >&2
    fi
done

exit 0
```

## Hook de Auditoría

```bash
#!/bin/bash
# .codex/hooks/audit-log.sh
# Hook post-tool-call: registra cada acción para auditoría

INPUT=$(cat)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
LOG_DIR=".codex/audit-logs"
LOG_FILE="$LOG_DIR/$(date +%Y-%m-%d).log"

mkdir -p "$LOG_DIR"

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
COMMAND=$(echo "$INPUT" | jq -r '.command // .arguments.command // "N/A"')
EXIT_CODE=$(echo "$INPUT" | jq -r '.exit_code // "N/A"')

echo "[$TIMESTAMP] tool=$TOOL_NAME command=\"$COMMAND\" exit_code=$EXIT_CODE" >> "$LOG_FILE"

exit 0
```

## Estructura Completa de Hooks

```
.codex/
├── config.toml
├── hooks.json                     # Registro de hooks
├── hooks/
│   ├── safety-check.sh            # pre-tool-call: bloqueo de comandos destructivos
│   ├── verify-environment.sh      # session-start: verificación de cuenta AWS
│   ├── audit-log.sh               # post-tool-call: log de auditoría
│   └── inject-context.sh          # pre-prompt: inyectar contexto adicional
└── audit-logs/                    # Generado automáticamente
    ├── 2026-04-13.log
    └── ...
```

## Hands-on (8 min)

Configurar el hook de seguridad básico:

```bash
# 1. Crear directorio de hooks
mkdir -p .codex/hooks

# 2. Copiar el safety-check.sh del ejemplo
cp examples/.codex/hooks/safety-check.sh .codex/hooks/

# 3. Hacerlo ejecutable
chmod +x .codex/hooks/safety-check.sh

# 4. Crear hooks.json
cat > .codex/hooks.json << 'EOF'
{
  "hooks": [
    {
      "event": "pre-tool-call",
      "command": ".codex/hooks/safety-check.sh",
      "description": "Valida comandos destructivos antes de ejecución",
      "timeout_ms": 5000
    }
  ]
}
EOF

# 5. Probar el hook directamente
echo '{"tool_name":"shell","command":"terraform destroy"}' | .codex/hooks/safety-check.sh
echo "Exit code: $?"
# Debería imprimir el mensaje de bloqueo y exit code 1

echo '{"tool_name":"shell","command":"terraform plan"}' | .codex/hooks/safety-check.sh
echo "Exit code: $?"
# Debería salir con exit code 0 (permitido)
```

## Receta: Hooks para el Equipo DevOps-SRE

Aquí un resumen de los hooks recomendados para el equipo:

| Hook | Evento | Propósito |
|------|--------|-----------|
| `safety-check.sh` | pre-tool-call | Bloquear comandos destructivos (terraform destroy, rm -rf, kubectl delete prod) |
| `verify-environment.sh` | session-start | Verificar cuenta AWS y advertir si es producción |
| `audit-log.sh` | post-tool-call | Registrar cada acción para auditoría y post-mortems |
| `dry-run-enforcer.sh` | pre-tool-call | Forzar --dry-run en comandos que lo soporten |
| `secrets-scanner.sh` | post-tool-call | Detectar si el output contiene secrets expuestos |

## Puntos clave

1. **Hooks = seguridad programática**: no dependen de que el modelo "obedezca", bloquean a nivel de proceso
2. **`pre-tool-call` es el más crítico**: intercepta y valida antes de ejecutar
3. Los hooks son **scripts de shell estándar** — puedes usar cualquier lógica que necesites
4. **Exit code 0 = permitir**, cualquier otro = bloquear (con mensaje en stderr)
5. Combina hooks con `AGENTS.md` y approval mode para **defensa en profundidad**
6. Los hooks se **versionan con Git** — todo el equipo tiene la misma protección

---

**Siguiente:** [Módulo 06 - Integración VSCode + GitHub Copilot →](06-vscode-copilot.md)
