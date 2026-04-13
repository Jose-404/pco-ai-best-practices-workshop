#!/bin/bash
# ============================================================
# audit-log.sh — Hook post-tool-call
# Registra cada acción ejecutada para auditoría.
# ============================================================

set -uo pipefail

INPUT=$(cat)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
LOG_DIR=".codex/audit-logs"
LOG_FILE="$LOG_DIR/$(date +%Y-%m-%d).log"

mkdir -p "$LOG_DIR"

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
COMMAND=$(echo "$INPUT" | jq -r '.command // .arguments.command // "N/A"')
EXIT_CODE=$(echo "$INPUT" | jq -r '.exit_code // "N/A"')
USER=$(whoami 2>/dev/null || echo "unknown")

# Formato: timestamp | usuario | tool | comando | exit_code
echo "[$TIMESTAMP] user=$USER tool=$TOOL_NAME exit_code=$EXIT_CODE command=\"$COMMAND\"" >> "$LOG_FILE"

# No bloquear nunca — este hook solo registra
exit 0
