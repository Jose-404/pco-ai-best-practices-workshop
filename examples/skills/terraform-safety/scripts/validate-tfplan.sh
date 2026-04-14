#!/bin/bash
# ============================================================
# validate-tfplan.sh
# Analiza un plan de Terraform y clasifica el riesgo antes de apply.
#
# Uso:
#   terraform plan -out=tfplan
#   ./validate-tfplan.sh tfplan
#   ./validate-tfplan.sh tfplan --output /tmp/tf-report.md
#   ./validate-tfplan.sh --auto   # genera el plan automáticamente
#
# Requisitos: terraform, jq
# ============================================================

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Parámetros ─────────────────────────────────────────────
PLAN_FILE=""
OUTPUT_FILE=""
AUTO_PLAN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --output) OUTPUT_FILE="$2"; shift 2 ;;
        --auto)   AUTO_PLAN=true; shift ;;
        --help)
            echo "Uso: $0 [PLAN_FILE] [--output FILE] [--auto]"
            echo ""
            echo "  PLAN_FILE    Archivo de plan binario de Terraform"
            echo "  --auto       Ejecuta 'terraform plan' automáticamente"
            echo "  --output     Genera reporte markdown en el archivo indicado"
            exit 0 ;;
        *)
            if [ -z "$PLAN_FILE" ]; then
                PLAN_FILE="$1"
            fi
            shift ;;
    esac
done

# ── Generar plan si --auto ─────────────────────────────────
if [ "$AUTO_PLAN" = true ]; then
    echo -e "${CYAN}Generando plan de Terraform...${NC}"
    terraform plan -out=tfplan -detailed-exitcode 2>&1 || true
    PLAN_FILE="tfplan"
fi

if [ -z "$PLAN_FILE" ] || [ ! -f "$PLAN_FILE" ]; then
    echo -e "${RED}Error: Archivo de plan no encontrado: ${PLAN_FILE:-'(no especificado)'}${NC}"
    echo "Uso: $0 <plan-file> | $0 --auto"
    exit 1
fi

# ── Convertir plan a JSON ──────────────────────────────────
echo -e "${CYAN}Analizando plan...${NC}"
PLAN_JSON=$(terraform show -json "$PLAN_FILE" 2>/dev/null)

if [ -z "$PLAN_JSON" ]; then
    echo -e "${RED}Error: No se pudo parsear el plan de Terraform.${NC}"
    exit 1
fi

# ── Recursos de alto riesgo ────────────────────────────────
HIGH_RISK_TYPES=(
    "aws_iam_policy"
    "aws_iam_role"
    "aws_iam_role_policy"
    "aws_iam_role_policy_attachment"
    "aws_iam_user"
    "aws_iam_group"
    "aws_security_group"
    "aws_security_group_rule"
    "aws_s3_bucket"
    "aws_rds_instance"
    "aws_rds_cluster"
    "aws_db_instance"
    "aws_eks_cluster"
    "aws_eks_node_group"
    "aws_route53_record"
    "aws_route53_zone"
    "aws_elasticache_cluster"
    "aws_elasticache_replication_group"
    "aws_dynamodb_table"
    "aws_kms_key"
    "aws_vpc"
    "aws_subnet"
    "aws_nat_gateway"
    "aws_internet_gateway"
)

# ── Extraer cambios ───────────────────────────────────────
CHANGES=$(echo "$PLAN_JSON" | jq -c '
    .resource_changes[]? |
    select(.change.actions | . != ["no-op"]) |
    {
        address: .address,
        type: .type,
        name: .name,
        actions: .change.actions,
        provider: .provider_name
    }
')

# Contadores
CREATES=0
UPDATES=0
DELETES=0
REPLACES=0
RISK_CRITICAL=0
RISK_HIGH=0
RISK_LOW=0
CRITICAL_DETAILS=""
HIGH_DETAILS=""

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Análisis de Plan de Terraform${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ -z "$CHANGES" ]; then
    echo -e "${GREEN}Sin cambios. El estado está sincronizado.${NC}"
    exit 0
fi

# ── Analizar cada cambio ──────────────────────────────────
echo "$CHANGES" | while read -r change; do
    ADDRESS=$(echo "$change" | jq -r '.address')
    TYPE=$(echo "$change" | jq -r '.type')
    ACTIONS=$(echo "$change" | jq -r '.actions | join(", ")')

    IS_HIGH_RISK=false
    for hrt in "${HIGH_RISK_TYPES[@]}"; do
        if [ "$TYPE" = "$hrt" ]; then
            IS_HIGH_RISK=true
            break
        fi
    done

    IS_PROD=false
    if echo "$ADDRESS" | grep -qiE '(prod|production)'; then
        IS_PROD=true
    fi

    # Clasificar por acción
    case "$ACTIONS" in
        *delete*)
            if [ "$IS_PROD" = true ]; then
                echo -e "${RED}[CRITICO] ELIMINAR (prod):${NC} $ADDRESS"
                CRITICAL_DETAILS+="- **ELIMINAR** \`${ADDRESS}\` — recurso de producción\n"
                RISK_CRITICAL=$((RISK_CRITICAL + 1))
            elif [ "$IS_HIGH_RISK" = true ]; then
                echo -e "${RED}[ALTO] ELIMINAR:${NC} $ADDRESS"
                HIGH_DETAILS+="- **ELIMINAR** \`${ADDRESS}\` — tipo de alto riesgo\n"
                RISK_HIGH=$((RISK_HIGH + 1))
            else
                echo -e "${YELLOW}[BAJO] ELIMINAR:${NC} $ADDRESS"
                RISK_LOW=$((RISK_LOW + 1))
            fi
            DELETES=$((DELETES + 1))
            ;;
        *create*delete*|*delete*create*)
            echo -e "${RED}[ALTO] REEMPLAZAR (recrear):${NC} $ADDRESS"
            HIGH_DETAILS+="- **REEMPLAZAR** \`${ADDRESS}\` — se destruirá y recreará (posible downtime)\n"
            RISK_HIGH=$((RISK_HIGH + 1))
            REPLACES=$((REPLACES + 1))
            ;;
        *create*)
            echo -e "${GREEN}[BAJO] CREAR:${NC} $ADDRESS"
            RISK_LOW=$((RISK_LOW + 1))
            CREATES=$((CREATES + 1))
            ;;
        *update*)
            if [ "$IS_HIGH_RISK" = true ] && [ "$IS_PROD" = true ]; then
                echo -e "${YELLOW}[ALTO] MODIFICAR (prod, alto riesgo):${NC} $ADDRESS"
                HIGH_DETAILS+="- **MODIFICAR** \`${ADDRESS}\` — producción, tipo de alto riesgo\n"
                RISK_HIGH=$((RISK_HIGH + 1))
            else
                echo -e "${GREEN}[BAJO] MODIFICAR:${NC} $ADDRESS"
                RISK_LOW=$((RISK_LOW + 1))
            fi
            UPDATES=$((UPDATES + 1))
            ;;
    esac
done

# ── Resumen ────────────────────────────────────────────────
TOTAL=$((CREATES + UPDATES + DELETES + REPLACES))

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Resumen${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${GREEN}Crear:      ${CREATES}${NC}"
echo -e "  ${CYAN}Modificar:  ${UPDATES}${NC}"
echo -e "  ${YELLOW}Reemplazar: ${REPLACES}${NC}"
echo -e "  ${RED}Eliminar:   ${DELETES}${NC}"
echo -e "  Total:     ${TOTAL}"
echo ""
echo -e "  Riesgo ${RED}CRITICO: ${RISK_CRITICAL}${NC}"
echo -e "  Riesgo ${YELLOW}ALTO:    ${RISK_HIGH}${NC}"
echo -e "  Riesgo ${GREEN}BAJO:    ${RISK_LOW}${NC}"
echo ""

# ── Recomendación ──────────────────────────────────────────
if [ "$RISK_CRITICAL" -gt 0 ]; then
    echo -e "${RED}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  DETENER — Se detectaron cambios CRITICOS.      ║${NC}"
    echo -e "${RED}║  Requiere revisión manual antes de apply.       ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════╝${NC}"
    RECOMMENDATION="DETENER — Revisión manual obligatoria"
elif [ "$RISK_HIGH" -gt 0 ]; then
    echo -e "${YELLOW}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  PRECAUCIÓN — Se detectaron cambios de alto     ║${NC}"
    echo -e "${YELLOW}║  riesgo. Revisar el detalle antes de apply.     ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════╝${NC}"
    RECOMMENDATION="PRECAUCION — Revisar detalle antes de apply"
else
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  OK — Cambios de bajo riesgo.                   ║${NC}"
    echo -e "${GREEN}║  Seguro para aplicar con confirmación normal.   ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    RECOMMENDATION="OK — Seguro para aplicar"
fi

# ── Reporte markdown ───────────────────────────────────────
if [ -n "$OUTPUT_FILE" ]; then
    cat > "$OUTPUT_FILE" << REPORT
# Validación de Plan Terraform

**Fecha:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Directorio:** $(pwd)
**Recomendación:** ${RECOMMENDATION}

## Resumen de Cambios

| Acción | Cantidad |
|--------|----------|
| Crear | ${CREATES} |
| Modificar | ${UPDATES} |
| Reemplazar | ${REPLACES} |
| Eliminar | ${DELETES} |
| **Total** | **${TOTAL}** |

## Clasificación de Riesgo

| Nivel | Cantidad |
|-------|----------|
| Crítico | ${RISK_CRITICAL} |
| Alto | ${RISK_HIGH} |
| Bajo | ${RISK_LOW} |

## Detalle de Riesgos Críticos

$(echo -e "${CRITICAL_DETAILS:-Ninguno}")

## Detalle de Riesgos Altos

$(echo -e "${HIGH_DETAILS:-Ninguno}")

## Próximos Pasos

$(if [ "$RISK_CRITICAL" -gt 0 ]; then
    echo "1. **NO ejecutar** \`terraform apply\` sin revisión del equipo"
    echo "2. Revisar cada recurso marcado como CRITICO"
    echo "3. Confirmar que la eliminación de recursos de producción es intencional"
    echo "4. Considerar ejecutar en horario de mantenimiento"
elif [ "$RISK_HIGH" -gt 0 ]; then
    echo "1. Revisar los recursos marcados como ALTO riesgo"
    echo "2. Verificar que los reemplazos no causen downtime"
    echo "3. Ejecutar \`terraform apply tfplan\` con supervisión"
else
    echo "1. Ejecutar \`terraform apply tfplan\`"
    echo "2. Verificar el estado post-apply"
fi)
REPORT

    echo ""
    echo -e "Reporte guardado en: ${CYAN}${OUTPUT_FILE}${NC}"
fi

# Exit code basado en riesgo (útil para CI/CD)
if [ "$RISK_CRITICAL" -gt 0 ]; then
    exit 2  # Crítico — bloquear pipeline
elif [ "$RISK_HIGH" -gt 0 ]; then
    exit 1  # Alto — advertencia
else
    exit 0  # Bajo — ok
fi
