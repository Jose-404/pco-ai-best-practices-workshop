#!/bin/bash
# ============================================================
# safety-check.sh — Hook pre-tool-call
# Intercepta y valida comandos antes de que Codex los ejecute.
# Exit 0 = permitir | Exit 1 = bloquear
# ============================================================

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.command // .arguments.command // empty')

# Si no hay comando que verificar, permitir
if [ -z "$COMMAND" ]; then
    exit 0
fi

# ── REGLA 1: Bloquear terraform destroy ────────────────────
if echo "$COMMAND" | grep -qiE 'terraform\s+destroy'; then
    echo "BLOQUEADO: 'terraform destroy' no está permitido vía Codex." >&2
    echo "Ejecuta este comando manualmente con la supervisión del equipo." >&2
    exit 1
fi

# ── REGLA 2: Bloquear terraform apply sin plan ─────────────
if echo "$COMMAND" | grep -qiE 'terraform\s+apply' && ! echo "$COMMAND" | grep -q 'tfplan'; then
    echo "BLOQUEADO: 'terraform apply' sin archivo de plan." >&2
    echo "Primero ejecuta: terraform plan -out=tfplan" >&2
    echo "Luego: terraform apply tfplan" >&2
    exit 1
fi

# ── REGLA 3: Bloquear rm -rf en paths críticos ────────────
if echo "$COMMAND" | grep -qiE 'rm\s+(-[a-z]*f[a-z]*\s+|.*-rf\s+)(/|/etc|/var|/opt|/home|/root|\.\.)'; then
    echo "BLOQUEADO: 'rm -rf' en path crítico detectado." >&2
    exit 1
fi

# ── REGLA 4: Bloquear kubectl delete en producción ────────
if echo "$COMMAND" | grep -qiE 'kubectl\s+delete' && echo "$COMMAND" | grep -qiE '(prod|production)'; then
    echo "BLOQUEADO: 'kubectl delete' en namespace de producción." >&2
    echo "Requiere ejecución manual con verificación del equipo." >&2
    exit 1
fi

# ── REGLA 5: Bloquear S3 destructivo en producción ────────
if echo "$COMMAND" | grep -qiE 'aws\s+s3\s+(rm|rb)' && echo "$COMMAND" | grep -qiE '(prod|production)'; then
    echo "BLOQUEADO: Operación destructiva en bucket S3 de producción." >&2
    exit 1
fi

# ── REGLA 6: Bloquear force push ──────────────────────────
if echo "$COMMAND" | grep -qiE 'git\s+push.*--force($|\s)'; then
    echo "BLOQUEADO: 'git push --force' no está permitido." >&2
    echo "Usa 'git push --force-with-lease' si es necesario." >&2
    exit 1
fi

# ── REGLA 7: Bloquear drop database ───────────────────────
if echo "$COMMAND" | grep -qiE '(drop\s+database|drop\s+table|truncate\s+table)'; then
    echo "BLOQUEADO: Operación destructiva de base de datos detectada." >&2
    exit 1
fi

# Si llegamos aquí, el comando es permitido
exit 0
