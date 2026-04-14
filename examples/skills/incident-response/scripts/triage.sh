#!/bin/bash
# ============================================================
# triage.sh
# Script de triage rápido para respuesta a incidentes en AWS.
# Recopila información de diagnóstico de múltiples servicios.
#
# Uso:
#   ./triage.sh                           # Triage general
#   ./triage.sh --service eks             # Triage de EKS
#   ./triage.sh --service rds             # Triage de RDS
#   ./triage.sh --service lambda --name mi-funcion
#   ./triage.sh --all --output /tmp/triage-report.md
#
# Requisitos: aws-cli, jq, kubectl (para EKS)
# ============================================================

set -uo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Parámetros ─────────────────────────────────────────────
SERVICE=""
RESOURCE_NAME=""
OUTPUT_FILE=""
RUN_ALL=false
REGION="${AWS_REGION:-us-east-1}"
PROFILE="${AWS_PROFILE:-}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --service)  SERVICE="$2"; shift 2 ;;
        --name)     RESOURCE_NAME="$2"; shift 2 ;;
        --output)   OUTPUT_FILE="$2"; shift 2 ;;
        --region)   REGION="$2"; shift 2 ;;
        --profile)  PROFILE="$2"; shift 2 ;;
        --all)      RUN_ALL=true; shift ;;
        --help)
            echo "Uso: $0 [--service SERVICE] [--name NAME] [--all] [--output FILE]"
            echo ""
            echo "Servicios: eks, rds, lambda, ec2, general"
            exit 0 ;;
        *) echo "Opción desconocida: $1"; exit 1 ;;
    esac
done

AWS_CMD="aws --region $REGION"
[[ -n "$PROFILE" ]] && AWS_CMD="$AWS_CMD --profile $PROFILE"

TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
REPORT=""

# ── Funciones auxiliares ───────────────────────────────────
log_section() {
    echo ""
    echo -e "${CYAN}━━━ $1 ━━━${NC}"
    REPORT+="\n### $1\n\n"
}

log_finding() {
    local level=$1
    local msg=$2
    case $level in
        critical) echo -e "${RED}[CRITICO] ${msg}${NC}" ;;
        warning)  echo -e "${YELLOW}[WARN] ${msg}${NC}" ;;
        ok)       echo -e "${GREEN}[OK] ${msg}${NC}" ;;
        info)     echo -e "${CYAN}[INFO] ${msg}${NC}" ;;
    esac
    REPORT+="- **${level^^}**: ${msg}\n"
}

log_cmd_output() {
    local output=$1
    REPORT+="\`\`\`\n${output}\n\`\`\`\n\n"
}

# ── Triage General ─────────────────────────────────────────
triage_general() {
    log_section "Estado General AWS"

    # Identidad
    local identity
    identity=$($AWS_CMD sts get-caller-identity 2>/dev/null || echo '{"error":"no credentials"}')
    local account=$(echo "$identity" | jq -r '.Account // "error"')
    log_finding info "Cuenta AWS: $account"

    # Eventos de salud AWS
    local health_events
    health_events=$($AWS_CMD health describe-events \
        --filter "eventStatusCodes=open" \
        --query 'events | length(@)' \
        --output text 2>/dev/null || echo "N/A")

    if [ "$health_events" != "N/A" ] && [ "$health_events" -gt 0 ] 2>/dev/null; then
        log_finding critical "Hay $health_events eventos de salud AWS abiertos"
        local events_detail
        events_detail=$($AWS_CMD health describe-events \
            --filter "eventStatusCodes=open" \
            --query 'events[].{Service:service,Category:eventTypeCategory,Description:eventTypeCode}' \
            --output table 2>/dev/null || echo "No disponible")
        log_cmd_output "$events_detail"
    else
        log_finding ok "Sin eventos de salud AWS activos"
    fi

    # Alarmas CloudWatch
    log_section "Alarmas CloudWatch Activas"
    local alarms
    alarms=$($AWS_CMD cloudwatch describe-alarms \
        --state-value ALARM \
        --query 'MetricAlarms[].{Nombre:AlarmName,Metrica:MetricName,Namespace:Namespace}' \
        --output table 2>/dev/null || echo "Error al obtener alarmas")

    local alarm_count
    alarm_count=$($AWS_CMD cloudwatch describe-alarms \
        --state-value ALARM \
        --query 'MetricAlarms | length(@)' \
        --output text 2>/dev/null || echo "0")

    if [ "$alarm_count" -gt 0 ] 2>/dev/null; then
        log_finding warning "$alarm_count alarmas en estado ALARM"
        echo "$alarms"
        log_cmd_output "$alarms"
    else
        log_finding ok "Sin alarmas activas"
    fi
}

# ── Triage EKS ─────────────────────────────────────────────
triage_eks() {
    log_section "Triage EKS / Kubernetes"

    if ! command -v kubectl &>/dev/null; then
        log_finding warning "kubectl no está instalado, saltando diagnóstico de K8s"
        return
    fi

    # Pods problemáticos
    log_finding info "Pods con problemas:"
    local bad_pods
    bad_pods=$(kubectl get pods --all-namespaces --field-selector='status.phase!=Running,status.phase!=Succeeded' 2>/dev/null || echo "No se pudo conectar al cluster")
    echo "$bad_pods"
    log_cmd_output "$bad_pods"

    # Eventos recientes
    log_finding info "Últimos 15 eventos del cluster:"
    local events
    events=$(kubectl get events --all-namespaces --sort-by='.lastTimestamp' 2>/dev/null | tail -15 || echo "No disponible")
    echo "$events"
    log_cmd_output "$events"

    # Uso de recursos
    log_finding info "Uso de recursos por nodo:"
    local node_usage
    node_usage=$(kubectl top nodes 2>/dev/null || echo "Metrics server no disponible")
    echo "$node_usage"
    log_cmd_output "$node_usage"

    # Pods con alto consumo
    log_finding info "Top 10 pods por memoria:"
    local top_pods
    top_pods=$(kubectl top pods --all-namespaces --sort-by=memory 2>/dev/null | head -11 || echo "No disponible")
    echo "$top_pods"
    log_cmd_output "$top_pods"
}

# ── Triage RDS ─────────────────────────────────────────────
triage_rds() {
    log_section "Triage RDS"

    # Eventos recientes
    log_finding info "Eventos RDS en la última hora:"
    local rds_events
    rds_events=$($AWS_CMD rds describe-events \
        --duration 60 \
        --query 'Events[].{Fuente:SourceIdentifier,Tipo:SourceType,Mensaje:Message,Fecha:Date}' \
        --output table 2>/dev/null || echo "Error al obtener eventos")
    echo "$rds_events"
    log_cmd_output "$rds_events"

    # Instancias con problemas
    log_finding info "Estado de instancias RDS:"
    local rds_status
    rds_status=$($AWS_CMD rds describe-db-instances \
        --query 'DBInstances[].{Nombre:DBInstanceIdentifier,Estado:DBInstanceStatus,Clase:DBInstanceClass,Engine:Engine}' \
        --output table 2>/dev/null || echo "Error al obtener estado")
    echo "$rds_status"
    log_cmd_output "$rds_status"

    # CPU de las instancias (últimos 30 min)
    log_finding info "CPU de instancias RDS (últimos 30 min):"
    local instances
    instances=$($AWS_CMD rds describe-db-instances \
        --query 'DBInstances[].DBInstanceIdentifier' \
        --output text 2>/dev/null)

    for instance in $instances; do
        local cpu
        cpu=$($AWS_CMD cloudwatch get-metric-statistics \
            --namespace AWS/RDS \
            --metric-name CPUUtilization \
            --dimensions "Name=DBInstanceIdentifier,Value=$instance" \
            --period 300 \
            --statistics Average Maximum \
            --start-time "$(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -v-30M +%Y-%m-%dT%H:%M:%S)" \
            --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
            --query 'Datapoints | sort_by(@, &Timestamp) | [-1]' \
            --output json 2>/dev/null || echo '{}')

        local avg_cpu=$(echo "$cpu" | jq -r '.Average // "N/A"' 2>/dev/null)
        local max_cpu=$(echo "$cpu" | jq -r '.Maximum // "N/A"' 2>/dev/null)

        if [ "$avg_cpu" != "N/A" ] && [ "$(echo "$avg_cpu > 80" | bc -l 2>/dev/null)" = "1" ]; then
            log_finding critical "$instance: CPU avg=${avg_cpu}%, max=${max_cpu}%"
        elif [ "$avg_cpu" != "N/A" ] && [ "$(echo "$avg_cpu > 60" | bc -l 2>/dev/null)" = "1" ]; then
            log_finding warning "$instance: CPU avg=${avg_cpu}%, max=${max_cpu}%"
        else
            log_finding ok "$instance: CPU avg=${avg_cpu}%, max=${max_cpu}%"
        fi
    done
}

# ── Triage Lambda ──────────────────────────────────────────
triage_lambda() {
    log_section "Triage Lambda"

    local func_name="${RESOURCE_NAME:-}"

    if [ -n "$func_name" ]; then
        # Errores recientes de una función específica
        log_finding info "Errores recientes en $func_name (últimos 30 min):"
        local log_group="/aws/lambda/$func_name"
        local errors
        errors=$($AWS_CMD logs filter-log-events \
            --log-group-name "$log_group" \
            --start-time "$(date -d '30 minutes ago' +%s000 2>/dev/null || echo $(( $(date +%s) - 1800 ))000)" \
            --filter-pattern "ERROR" \
            --limit 20 \
            --query 'events[].message' \
            --output text 2>/dev/null || echo "No se encontraron logs")
        echo "$errors" | head -30
        log_cmd_output "$(echo "$errors" | head -30)"

        # Invocaciones y errores
        log_finding info "Métricas de $func_name (última hora):"
        for metric in Invocations Errors Throttles Duration; do
            local val
            val=$($AWS_CMD cloudwatch get-metric-statistics \
                --namespace AWS/Lambda \
                --metric-name "$metric" \
                --dimensions "Name=FunctionName,Value=$func_name" \
                --period 3600 \
                --statistics Sum Average \
                --start-time "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -v-1H +%Y-%m-%dT%H:%M:%S)" \
                --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
                --query 'Datapoints[0]' \
                --output json 2>/dev/null || echo '{}')

            local sum=$(echo "$val" | jq -r '.Sum // "N/A"')
            local avg=$(echo "$val" | jq -r '.Average // "N/A"')
            echo "  $metric: sum=$sum, avg=$avg"
        done
    else
        # Funciones con errores recientes
        log_finding info "Funciones Lambda con errores en la última hora:"
        local functions
        functions=$($AWS_CMD lambda list-functions \
            --query 'Functions[].FunctionName' \
            --output text 2>/dev/null)

        for func in $functions; do
            local err_count
            err_count=$($AWS_CMD cloudwatch get-metric-statistics \
                --namespace AWS/Lambda \
                --metric-name Errors \
                --dimensions "Name=FunctionName,Value=$func" \
                --period 3600 \
                --statistics Sum \
                --start-time "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -v-1H +%Y-%m-%dT%H:%M:%S)" \
                --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
                --query 'Datapoints[0].Sum' \
                --output text 2>/dev/null || echo "0")

            if [ "$err_count" != "None" ] && [ "$err_count" != "0" ] && [ "$err_count" != "null" ]; then
                log_finding warning "$func: $err_count errores en la última hora"
            fi
        done
    fi
}

# ── Triage EC2 ─────────────────────────────────────────────
triage_ec2() {
    log_section "Triage EC2"

    # Instancias con problemas
    log_finding info "Instancias EC2 con status check fallido:"
    local impaired
    impaired=$($AWS_CMD ec2 describe-instance-status \
        --filters "Name=instance-status.status,Values=impaired" \
        --query 'InstanceStatuses[].{ID:InstanceId,Sistema:SystemStatus.Status,Instancia:InstanceStatus.Status}' \
        --output table 2>/dev/null || echo "Ninguna")
    echo "$impaired"
    log_cmd_output "$impaired"

    # Instancias detenidas recientemente
    log_finding info "Instancias detenidas:"
    local stopped
    stopped=$($AWS_CMD ec2 describe-instances \
        --filters "Name=instance-state-name,Values=stopped" \
        --query 'Reservations[].Instances[].{ID:InstanceId,Nombre:Tags[?Key==`Name`].Value|[0],Tipo:InstanceType,Detenida:StateTransitionReason}' \
        --output table 2>/dev/null || echo "Ninguna")
    echo "$stopped"
    log_cmd_output "$stopped"
}

# ── Ejecutar ───────────────────────────────────────────────
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Triage de Incidente — ${TIMESTAMP}${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

REPORT="# Reporte de Triage\n\n**Fecha:** ${TIMESTAMP}\n**Región:** ${REGION}\n"

if [ "$RUN_ALL" = true ] || [ -z "$SERVICE" ]; then
    triage_general
    [ "$RUN_ALL" = true ] && triage_eks
    [ "$RUN_ALL" = true ] && triage_rds
    [ "$RUN_ALL" = true ] && triage_lambda
    [ "$RUN_ALL" = true ] && triage_ec2
else
    triage_general
    case "$SERVICE" in
        eks|kubernetes|k8s) triage_eks ;;
        rds|database|db)    triage_rds ;;
        lambda)             triage_lambda ;;
        ec2|instances)      triage_ec2 ;;
        *)
            echo -e "${RED}Servicio no reconocido: $SERVICE${NC}"
            echo "Servicios disponibles: eks, rds, lambda, ec2"
            exit 1 ;;
    esac
fi

# ── Generar reporte ────────────────────────────────────────
if [ -n "$OUTPUT_FILE" ]; then
    echo -e "$REPORT" > "$OUTPUT_FILE"
    echo ""
    echo -e "Reporte guardado en: ${CYAN}${OUTPUT_FILE}${NC}"
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Triage completado${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
exit 0
