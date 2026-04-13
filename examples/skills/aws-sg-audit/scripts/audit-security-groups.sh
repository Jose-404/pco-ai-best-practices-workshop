#!/bin/bash
# ============================================================
# audit-security-groups.sh
# Audita Security Groups de AWS buscando reglas permisivas.
#
# Uso:
#   ./audit-security-groups.sh [--region us-east-1] [--profile staging]
#   ./audit-security-groups.sh --output /tmp/sg-report.md
#
# Requisitos: aws-cli, jq
# ============================================================

set -euo pipefail

# ── Colores ────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ── Parámetros ─────────────────────────────────────────────
REGION="${AWS_REGION:-us-east-1}"
PROFILE="${AWS_PROFILE:-}"
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --region)  REGION="$2"; shift 2 ;;
        --profile) PROFILE="$2"; shift 2 ;;
        --output)  OUTPUT_FILE="$2"; shift 2 ;;
        --help)
            echo "Uso: $0 [--region REGION] [--profile PROFILE] [--output FILE]"
            exit 0 ;;
        *) echo "Opción desconocida: $1"; exit 1 ;;
    esac
done

AWS_CMD="aws"
[[ -n "$PROFILE" ]] && AWS_CMD="aws --profile $PROFILE"

# ── Puertos críticos que nunca deben estar abiertos a 0.0.0.0/0 ──
declare -A CRITICAL_PORTS=(
    [22]="SSH"
    [3389]="RDP"
    [3306]="MySQL"
    [5432]="PostgreSQL"
    [6379]="Redis"
    [27017]="MongoDB"
    [9200]="Elasticsearch"
    [9300]="Elasticsearch Transport"
    [11211]="Memcached"
    [1433]="MSSQL"
    [1521]="Oracle DB"
    [5984]="CouchDB"
    [8529]="ArangoDB"
)

# ── Contadores ─────────────────────────────────────────────
TOTAL_SG=0
CRITICAL=0
HIGH=0
MEDIUM=0
LOW=0
FINDINGS=""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Auditoría de Security Groups${NC}"
echo -e "${CYAN}  Región: ${REGION}${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ── Obtener cuenta AWS ─────────────────────────────────────
AWS_ACCOUNT=$($AWS_CMD sts get-caller-identity --query 'Account' --output text 2>/dev/null || echo "desconocida")
echo -e "Cuenta AWS: ${CYAN}${AWS_ACCOUNT}${NC}"
echo ""

# ── Obtener Security Groups ───────────────────────────────
echo "Obteniendo Security Groups..."
SG_DATA=$($AWS_CMD ec2 describe-security-groups \
    --region "$REGION" \
    --output json 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$SG_DATA" ]; then
    echo -e "${RED}Error: No se pudieron obtener los Security Groups.${NC}"
    echo "Verifica tus credenciales AWS y la región."
    exit 1
fi

TOTAL_SG=$(echo "$SG_DATA" | jq '.SecurityGroups | length')
echo -e "Total Security Groups encontrados: ${CYAN}${TOTAL_SG}${NC}"
echo ""

# ── Obtener ENIs para detectar SGs sin uso ─────────────────
echo "Verificando asociaciones de ENI..."
USED_SGS=$($AWS_CMD ec2 describe-network-interfaces \
    --region "$REGION" \
    --query 'NetworkInterfaces[].Groups[].GroupId' \
    --output text 2>/dev/null | tr '\t' '\n' | sort -u)

# ── Analizar cada Security Group ──────────────────────────
echo "Analizando reglas..."
echo ""

echo "$SG_DATA" | jq -c '.SecurityGroups[]' | while read -r sg; do
    SG_ID=$(echo "$sg" | jq -r '.GroupId')
    SG_NAME=$(echo "$sg" | jq -r '.GroupName')
    VPC_ID=$(echo "$sg" | jq -r '.VpcId // "N/A"')

    # Verificar si el SG está en uso
    if ! echo "$USED_SGS" | grep -q "$SG_ID"; then
        echo -e "${YELLOW}[BAJO]${NC} ${SG_ID} (${SG_NAME}) — Security Group sin uso"
        FINDINGS+="| BAJO | ${SG_ID} | ${SG_NAME} | Sin asociar a ninguna ENI | Eliminar si no es necesario |\n"
        LOW=$((LOW + 1))
    fi

    # Analizar reglas de ingress
    echo "$sg" | jq -c '.IpPermissions[]?' | while read -r rule; do
        FROM_PORT=$(echo "$rule" | jq -r '.FromPort // -1')
        TO_PORT=$(echo "$rule" | jq -r '.ToPort // -1')
        PROTOCOL=$(echo "$rule" | jq -r '.IpProtocol')

        # Verificar CIDRs abiertos (0.0.0.0/0 y ::/0)
        OPEN_IPV4=$(echo "$rule" | jq -r '.IpRanges[]? | select(.CidrIp == "0.0.0.0/0") | .CidrIp')
        OPEN_IPV6=$(echo "$rule" | jq -r '.Ipv6Ranges[]? | select(.CidrIpv6 == "::/0") | .CidrIpv6')

        if [ -n "$OPEN_IPV4" ] || [ -n "$OPEN_IPV6" ]; then
            OPEN_CIDR="${OPEN_IPV4:-}${OPEN_IPV6:+ / ${OPEN_IPV6}}"

            # Caso: Todos los puertos abiertos
            if [ "$PROTOCOL" = "-1" ] || ([ "$FROM_PORT" = "0" ] && [ "$TO_PORT" = "65535" ]); then
                echo -e "${RED}[CRITICO]${NC} ${SG_ID} (${SG_NAME}) — TODOS los puertos abiertos a ${OPEN_CIDR}"
                FINDINGS+="| CRITICO | ${SG_ID} | ${SG_NAME} | Todos los puertos abiertos a ${OPEN_CIDR} | Restringir inmediatamente |\n"
                CRITICAL=$((CRITICAL + 1))
                continue
            fi

            # Caso: Puerto crítico abierto
            for port in "${!CRITICAL_PORTS[@]}"; do
                if [ "$FROM_PORT" -le "$port" ] 2>/dev/null && [ "$TO_PORT" -ge "$port" ] 2>/dev/null; then
                    SERVICE="${CRITICAL_PORTS[$port]}"

                    # DB ports = CRITICO, SSH/RDP = ALTO
                    if [ "$port" = "22" ] || [ "$port" = "3389" ]; then
                        echo -e "${RED}[ALTO]${NC} ${SG_ID} (${SG_NAME}) — Puerto ${port} (${SERVICE}) abierto a ${OPEN_CIDR}"
                        FINDINGS+="| ALTO | ${SG_ID} | ${SG_NAME} | Puerto ${port} (${SERVICE}) abierto a ${OPEN_CIDR} | Restringir a IPs específicas |\n"
                        HIGH=$((HIGH + 1))
                    else
                        echo -e "${RED}[CRITICO]${NC} ${SG_ID} (${SG_NAME}) — Puerto ${port} (${SERVICE}) abierto a ${OPEN_CIDR}"
                        FINDINGS+="| CRITICO | ${SG_ID} | ${SG_NAME} | Puerto ${port} (${SERVICE}) abierto a ${OPEN_CIDR} | Cerrar acceso público inmediatamente |\n"
                        CRITICAL=$((CRITICAL + 1))
                    fi
                fi
            done

            # Caso: Rango amplio de puertos (más de 100 puertos)
            if [ "$FROM_PORT" -ge 0 ] 2>/dev/null && [ "$TO_PORT" -ge 0 ] 2>/dev/null; then
                RANGE=$((TO_PORT - FROM_PORT))
                if [ "$RANGE" -gt 100 ]; then
                    echo -e "${YELLOW}[MEDIO]${NC} ${SG_ID} (${SG_NAME}) — Rango ${FROM_PORT}-${TO_PORT} abierto a ${OPEN_CIDR}"
                    FINDINGS+="| MEDIO | ${SG_ID} | ${SG_NAME} | Rango ${FROM_PORT}-${TO_PORT} abierto a ${OPEN_CIDR} | Reducir rango de puertos |\n"
                    MEDIUM=$((MEDIUM + 1))
                fi
            fi
        fi
    done
done

# ── Resumen ────────────────────────────────────────────────
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Resumen de Auditoría${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Total SGs analizados: ${TOTAL_SG}"
echo -e "  ${RED}Críticos: ${CRITICAL}${NC}"
echo -e "  ${RED}Altos:    ${HIGH}${NC}"
echo -e "  ${YELLOW}Medios:   ${MEDIUM}${NC}"
echo -e "  ${GREEN}Bajos:    ${LOW}${NC}"
echo ""

if [ "$CRITICAL" -gt 0 ] || [ "$HIGH" -gt 0 ]; then
    echo -e "${RED}¡Se encontraron hallazgos que requieren atención inmediata!${NC}"
fi

# ── Generar reporte en markdown si se pidió ────────────────
if [ -n "$OUTPUT_FILE" ]; then
    cat > "$OUTPUT_FILE" << REPORT
# Reporte de Auditoría — Security Groups

**Fecha:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Cuenta AWS:** ${AWS_ACCOUNT}
**Región:** ${REGION}

## Resumen

| Severidad | Cantidad |
|-----------|----------|
| Crítico   | ${CRITICAL} |
| Alto      | ${HIGH} |
| Medio     | ${MEDIUM} |
| Bajo      | ${LOW} |
| **Total SGs** | **${TOTAL_SG}** |

## Hallazgos

| Severidad | SG ID | Nombre | Hallazgo | Recomendación |
|-----------|-------|--------|----------|---------------|
$(echo -e "$FINDINGS")

## Próximos pasos

- [ ] Remediar hallazgos CRITICOS en las próximas 24 horas
- [ ] Remediar hallazgos ALTOS en la próxima semana
- [ ] Revisar hallazgos MEDIOS y BAJOS en el próximo sprint
- [ ] Configurar AWS Config Rules para detección continua
REPORT

    echo -e "Reporte guardado en: ${CYAN}${OUTPUT_FILE}${NC}"
fi

exit 0
