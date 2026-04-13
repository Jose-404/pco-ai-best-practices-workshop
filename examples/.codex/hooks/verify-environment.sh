#!/bin/bash
# ============================================================
# verify-environment.sh — Hook session-start
# Verifica el entorno AWS al iniciar una sesión de Codex.
# ============================================================

set -uo pipefail

echo "--- Verificando entorno de trabajo ---"

# Verificar cuenta AWS activa
AWS_ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "ADVERTENCIA: No hay sesión AWS activa." >&2
    echo "Ejecuta 'aws sso login' o configura tus credenciales." >&2
    exit 0  # No bloqueamos, solo advertimos
fi

AWS_ALIAS=$(aws iam list-account-aliases --query 'AccountAliases[0]' --output text 2>/dev/null || echo "sin-alias")
AWS_REGION=$(aws configure get region 2>/dev/null || echo "no configurada")

echo "  Cuenta AWS: $AWS_ACCOUNT ($AWS_ALIAS)"
echo "  Región:     $AWS_REGION"

# ── Advertir si es cuenta de producción ────────────────────
# IMPORTANTE: Reemplaza estos IDs con los de tu organización
PROD_ACCOUNTS=("123456789012" "987654321098")

for PROD_ACCOUNT in "${PROD_ACCOUNTS[@]}"; do
    if [ "$AWS_ACCOUNT" = "$PROD_ACCOUNT" ]; then
        echo "" >&2
        echo "ATENCION: Estás conectado a la cuenta de PRODUCCION ($AWS_ALIAS)." >&2
        echo "Todas las operaciones destructivas requerirán confirmación extra." >&2
        echo "" >&2
    fi
done

# Verificar herramientas necesarias
for tool in terraform kubectl jq; do
    if command -v "$tool" &>/dev/null; then
        echo "  $tool: $(command -v $tool)"
    else
        echo "  $tool: no encontrado (puede no ser necesario)"
    fi
done

echo "--- Verificación completada ---"
exit 0
