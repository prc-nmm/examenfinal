#!/usr/bin/env bash
# ==============================================================================
# Universidad - Curso: Network Management and Monitoring
# Script de Autoevaluación - Examen Final Práctico (Ubuntu Server 26.04)
# ==============================================================================

# Colores para salida en consola
VERDE="\e[32m"
ROJO="\e[31m"
AMARILLO="\e[33m"
CIAN="\e[36m"
NEGRITA="\e[1m"
RESET="\e[0m"

# Parámetros de configuración base
COMMUNITY_ESPERADO="prcNMM2026"
LOCATION_ESPERADO="Oficina Remota PRC"
REFRESH_SECONDS=5
MUESTRAS_POR_OID=3      # Lecturas cada 5 segundos (t=0s, t=5s, t=10s)
MAX_PUNTEO_FASE2=50     # Tope máximo de 50 puntos (5 gráficas x 10 pts)

#Limpiar pantalla
clear

#Mensaje de inicio
echo "=============================================================================="
echo "Universidad - Curso: Network Management and Monitoring"
echo "Script de Autoevaluación - Examen Final Práctico (Ubuntu Server 26.04)"
echo "=============================================================================="

# Verificar dependencia de herramientas cliente SNMP
if ! command -v snmpget &> /dev/null || ! command -v snmpwalk &> /dev/null; then
    echo -e "${ROJO}[ERROR] El paquete 'snmp' no está instalado. Ejecute: sudo apt install -y snmp${RESET}"
    exit 1
fi

# Solicitar Nombre, Carné e IP (por argumentos CLI o de forma interactiva)
NOMBRE_ESTUDIANTE="$1"
CARNE="$2"
SERVER_IP="$3"

if [[ -z "$NOMBRE_ESTUDIANTE" ]]; then
    read -rp "Ingrese el nombre completo del estudiante: " NOMBRE_ESTUDIANTE
fi

if [[ -z "$NOMBRE_ESTUDIANTE" ]]; then
    echo -e "${ROJO}[ERROR] El nombre del estudiante no puede estar vacío.${RESET}"
    exit 1
fi

if [[ -z "$CARNE" ]]; then
    read -rp "Ingrese el número de carné del alumno: " CARNE
fi

if [[ -z "$SERVER_IP" ]]; then
    read -rp "Ingrese la dirección IP del servidor SNMP: " SERVER_IP
fi

# Validar formato numérico y extraer últimos 4 dígitos del carné
CARNE_LIMPIO=$(echo "$CARNE" | tr -cd '0-9')
if [[ ${#CARNE_LIMPIO} -lt 4 ]]; then
    echo -e "${ROJO}[ERROR] El carné debe contener al menos 4 dígitos numéricos.${RESET}"
    exit 1
fi

YYYY="${CARNE_LIMPIO: -4}"
SYSNAME_ESPERADO="prcNMM-${YYYY}"

# Parámetros opcionales para evaluación de SNMPv3 (+15 pts extra)
V3_USER="$4"
V3_AUTH="$5"
V3_PRIV="$6"

if [[ -z "$V3_USER" ]]; then
    read -rp "¿Implementó SNMPv3 para los 15 puntos extra? (s/n): " RESP_V3
    if [[ "$RESP_V3" =~ ^[sS]$ ]]; then
        read -rp "  Usuario SNMPv3: " V3_USER
        read -rsp "  Contraseña de Autenticación (SHA): " V3_AUTH
        echo ""
        read -rsp "  Contraseña de Cifrado (AES): " V3_PRIV
        echo ""
    fi
fi

clear
echo -e "${NEGRITA}${CIAN}======================================================================${RESET}"
echo -e "${NEGRITA}${CIAN}   EVALUACIÓN FINAL PRÁCTICA - NETWORK MANAGEMENT AND MONITORING      ${RESET}"
echo -e "${NEGRITA}${CIAN}======================================================================${RESET}"
echo -e " Estudiante         : ${NEGRITA}${NOMBRE_ESTUDIANTE}${RESET}"
echo -e " Carné              : ${NEGRITA}${CARNE}${RESET} (Sufijo esperado: ${NEGRITA}${YYYY}${RESET})"
echo -e " Servidor Objetivo  : ${NEGRITA}${SERVER_IP}${RESET}"
echo -e " Fecha de Ejecución : $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "${CIAN}----------------------------------------------------------------------${RESET}\n"

# ==============================================================================
# FASE 1: VALIDACIÓN DE PARÁMETROS BASE SNMP (50 PTS + 15 PTS EXTRA)
# ==============================================================================
echo -e "${NEGRITA}${AMARILLO}>>> INICIANDO FASE 1: AUDITORÍA DE CONFIGURACIÓN SNMP <<<${RESET}\n"

PUNTEO_FASE1=0
PUNTEO_EXTRA=0

# 1. Evaluación de Community String (15 pts)
TEST_COMM=$(snmpget -v2c -c "$COMMUNITY_ESPERADO" -t 2 -r 1 -Oqv "$SERVER_IP" .1.3.6.1.2.1.1.1.0 2>/dev/null)
if [[ $? -eq 0 && -n "$TEST_COMM" ]]; then
    echo -e "[${VERDE}OK${RESET}] Community String ('${COMMUNITY_ESPERADO}') válido y operativo.  -> ${VERDE}+15 pts${RESET}"
    ((PUNTEO_FASE1+=15))
else
    echo -e "[${ROJO}FAIL${RESET}] No se obtuvo respuesta usando Community String '${COMMUNITY_ESPERADO}'. -> ${ROJO}0 pts${RESET}"
    echo -e "${ROJO}Abortando evaluación: Verifique conectividad UDP/161 o el community string en snmpd.conf.${RESET}"
    exit 1
fi

# 2. Evaluación de sysName (20 pts)
SYSNAME_OBTENIDO=$(snmpget -v2c -c "$COMMUNITY_ESPERADO" -Oqv "$SERVER_IP" .1.3.6.1.2.1.1.5.0 2>/dev/null | tr -d '"')
if [[ "$SYSNAME_OBTENIDO" == "$SYSNAME_ESPERADO" ]]; then
    echo -e "[${VERDE}OK${RESET}] sysName correcto ('${SYSNAME_OBTENIDO}').                      -> ${VERDE}+20 pts${RESET}"
    ((PUNTEO_FASE1+=20))
else
    echo -e "[${ROJO}FAIL${RESET}] sysName incorrecto. Esperado: '${SYSNAME_ESPERADO}' | Obtenido: '${SYSNAME_OBTENIDO}' -> ${ROJO}0 pts${RESET}"
fi

# 3. Evaluación de sysLocation (15 pts)
SYSLOC_OBTENIDO=$(snmpget -v2c -c "$COMMUNITY_ESPERADO" -Oqv "$SERVER_IP" .1.3.6.1.2.1.1.6.0 2>/dev/null | tr -d '"')
if [[ "$SYSLOC_OBTENIDO" == "$LOCATION_ESPERADO" ]]; then
    echo -e "[${VERDE}OK${RESET}] sysLocation correcto ('${SYSLOC_OBTENIDO}').             -> ${VERDE}+15 pts${RESET}"
    ((PUNTEO_FASE1+=15))
else
    echo -e "[${ROJO}FAIL${RESET}] sysLocation incorrecto. Esperado: '${LOCATION_ESPERADO}' | Obtenido: '${SYSLOC_OBTENIDO}' -> ${ROJO}0 pts${RESET}"
fi

# 4. Evaluación Extra: SNMPv3 (15 pts adicionales)
if [[ -n "$V3_USER" ]]; then
    V3_CHECK=$(snmpget -v3 -l authPriv -u "$V3_USER" -a SHA -A "$V3_AUTH" -x AES -X "$V3_PRIV" -t 2 -r 1 -Oqv "$SERVER_IP" .1.3.6.1.2.1.1.5.0 2>/dev/null | tr -d '"')
    if [[ $? -eq 0 && "$V3_CHECK" == "$SYSNAME_ESPERADO" ]]; then
        echo -e "[${VERDE}BONUS${RESET}] SNMPv3 (authPriv SHA/AES) verificado con usuario '${V3_USER}'. -> ${VERDE}+15 pts EXTRA${RESET}"
        ((PUNTEO_EXTRA+=15))
    else
        echo -e "[${ROJO}FAIL${RESET}] Falló la autenticación/cifrado SNMPv3 para '${V3_USER}'.          -> ${ROJO}0 pts EXTRA${RESET}"
    fi
fi

TOTAL_FASE1=$((PUNTEO_FASE1 + PUNTEO_EXTRA))
echo -e "\n${NEGRITA}Subtotal Fase 1:${RESET} ${PUNTEO_FASE1}/50 pts base | ${PUNTEO_EXTRA}/15 pts extra | ${NEGRITA}${CIAN}Total Fase 1: ${TOTAL_FASE1} pts${RESET}"
echo -e "${CIAN}----------------------------------------------------------------------${RESET}\n"

# ==============================================================================
# FASE 2: EVALUACIÓN INDIVIDUAL DE OIDS EN VIVO (REFRESH: 5s | MÁX: 50 PTS)
# ==============================================================================
echo -e "${NEGRITA}${AMARILLO}>>> INICIANDO FASE 2: MONITOREO EN VIVO POR OID (REFRESH: ${REFRESH_SECONDS}s) <<<${RESET}"
echo -e "Criterio: +10 pts por cada métrica con delta tras ${REFRESH_SECONDS}s (Máximo ${MAX_PUNTEO_FASE2} pts).\n"

# Detectar automáticamente el índice de la primera interfaz activa distinta de 'lo'
IF_INDEX=$(snmpwalk -v2c -c "$COMMUNITY_ESPERADO" -On "$SERVER_IP" .1.3.6.1.2.1.2.2.1.2 2>/dev/null \
    | grep -v "STRING: lo" | head -n 1 | awk -F'[. ]' '{print $12}')
IF_INDEX=${IF_INDEX:-2}
IF_NAME=$(snmpget -v2c -c "$COMMUNITY_ESPERADO" -Oqv "$SERVER_IP" ".1.3.6.1.2.1.2.2.1.2.${IF_INDEX}" 2>/dev/null | tr -d '"')

echo -e "Interfaz de red detectada para tráfico: ${NEGRITA}${IF_NAME}${RESET} (ifIndex = ${IF_INDEX})\n"

PUNTEO_FASE2=0
OIDS_CON_DELTA=0

# Función para evaluar cada OID de forma independiente cada 5 segundos
evaluar_oid_en_vivo() {
    local NOMBRE="$1"
    local OID="$2"
    local ES_NUMERICO="$3"
    local VALOR_ANTERIOR=""
    local HUBO_DELTA=false

    echo -e "${NEGRITA}${CIAN}[OID] Evaluando: ${NOMBRE}${RESET} (${OID})"

    for (( i=1; i<=MUESTRAS_POR_OID; i++ )); do
        HORA=$(date '+%H:%M:%S')
        LECTURA=$(snmpget -v2c -c "$COMMUNITY_ESPERADO" -Oqv "$SERVER_IP" "$OID" 2>/dev/null)

        if [[ $? -ne 0 || -z "$LECTURA" || "$LECTURA" == *"No Such"* ]]; then
            echo -e "  [${HORA}] Muestra ${i}/${MUESTRAS_POR_OID}: ${ROJO}ERROR - OID no disponible o sin vista MIB${RESET}"
            break
        fi

        if [[ $i -eq 1 ]]; then
            echo -e "  [${HORA}] Muestra ${i}/${MUESTRAS_POR_OID}: Valor inicial = ${NEGRITA}${LECTURA}${RESET}"
        else
            if [[ "$ES_NUMERICO" == "true" && "$LECTURA" =~ ^[0-9]+$ && "$VALOR_ANTERIOR" =~ ^[0-9]+$ ]]; then
                DELTA=$((LECTURA - VALOR_ANTERIOR))
                if [[ $DELTA -gt 0 ]]; then
                    HUBO_DELTA=true
                    echo -e "  [${HORA}] Muestra ${i}/${MUESTRAS_POR_OID}: Valor actual  = ${NEGRITA}${LECTURA}${RESET} (${VERDE}Δ +${DELTA}${RESET})"
                elif [[ $DELTA -lt 0 ]]; then
                    HUBO_DELTA=true
                    echo -e "  [${HORA}] Muestra ${i}/${MUESTRAS_POR_OID}: Valor actual  = ${NEGRITA}${LECTURA}${RESET} (${VERDE}Δ ${DELTA}${RESET})"
                else
                    echo -e "  [${HORA}] Muestra ${i}/${MUESTRAS_POR_OID}: Valor actual  = ${NEGRITA}${LECTURA}${RESET} (${AMARILLO}Δ 0 - Sin cambio${RESET})"
                fi
            else
                if [[ "$LECTURA" != "$VALOR_ANTERIOR" ]]; then
                    HUBO_DELTA=true
                    echo -e "  [${HORA}] Muestra ${i}/${MUESTRAS_POR_OID}: Valor actual  = ${NEGRITA}${LECTURA}${RESET} (${VERDE}Δ Detectado${RESET})"
                    else
                    echo -e "  [${HORA}] Muestra ${i}/${MUESTRAS_POR_OID}: Valor actual  = ${NEGRITA}${LECTURA}${RESET} (${AMARILLO}Sin cambio${RESET})"
                fi
            fi
        fi

        VALOR_ANTERIOR="$LECTURA"

        # Esperar 5 segundos entre consultas (excepto después de la última muestra)
        if [[ $i -lt $MUESTRAS_POR_OID ]]; then
            sleep "$REFRESH_SECONDS"
        fi
    done

    # Asignación de puntaje por variación detectada en la métrica
    if [[ "$HUBO_DELTA" == "true" ]]; then
        ((OIDS_CON_DELTA++))
        if [[ $PUNTEO_FASE2 -lt $MAX_PUNTEO_FASE2 ]]; then
            ((PUNTEO_FASE2+=10))
            echo -e "  -> Resultado métrica: ${VERDE}Delta verificado (+10 pts)${RESET} | Acumulado Fase 2: ${NEGRITA}${PUNTEO_FASE2}/${MAX_PUNTEO_FASE2} pts${RESET}\n"
        else
            echo -e "  -> Resultado métrica: ${VERDE}Delta verificado${RESET} | ${AMARILLO}Tope máximo de ${MAX_PUNTEO_FASE2} pts ya alcanzado (+0 pts)${RESET}\n"
        fi
    else
        echo -e "  -> Resultado métrica: ${ROJO}No presentó delta en ${REFRESH_SECONDS}s (+0 pts)${RESET} | Acumulado Fase 2: ${NEGRITA}${PUNTEO_FASE2}/${MAX_PUNTEO_FASE2} pts${RESET}\n"
    fi
}

# Evaluación secuencial e independiente de los 6 OIDs definidos
evaluar_oid_en_vivo "ifInOctets (${IF_NAME})"          ".1.3.6.1.2.1.2.2.1.10.${IF_INDEX}" "true"
evaluar_oid_en_vivo "ifOutOctets (${IF_NAME})"         ".1.3.6.1.2.1.2.2.1.16.${IF_INDEX}" "true"
evaluar_oid_en_vivo "icmpInMsgs"                       ".1.3.6.1.2.1.5.1.0"                "true"
evaluar_oid_en_vivo "icmpOutMsgs"                      ".1.3.6.1.2.1.5.14.0"               "true"
evaluar_oid_en_vivo "System Uptime (sysUpTime)"        ".1.3.6.1.2.1.1.3.0"                "false"
evaluar_oid_en_vivo "Current Users (hrSystemNumUsers)" ".1.3.6.1.2.1.25.1.5.0"             "true"

# ==============================================================================
# RESUMEN FINAL DE CALIFICACIÓN
# ==============================================================================
PUNTEO_TOTAL=$((TOTAL_FASE1 + PUNTEO_FASE2))

echo -e "${NEGRITA}${CIAN}======================================================================${RESET}"
echo -e "${NEGRITA}${CIAN}                    RESUMEN FINAL DE CALIFICACIÓN                     ${RESET}"
echo -e "${NEGRITA}${CIAN}======================================================================${RESET}"
echo -e " Nombre del Estudiante        : ${NEGRITA}${NOMBRE_ESTUDIANTE}${RESET}"
echo -e " Carné                        : ${NEGRITA}${CARNE}${RESET}"
echo -e " Servidor Evaluado            : ${NEGRITA}${SERVER_IP}${RESET}"
echo -e "${CIAN}----------------------------------------------------------------------${RESET}"
echo -e " Puntuación Fase 1            : ${NEGRITA}${CIAN}${TOTAL_FASE1} pts${RESET} (Base: ${PUNTEO_FASE1}/50 | Extra SNMPv3: ${PUNTEO_EXTRA}/15)"
echo -e " Puntuación Fase 2 (${OIDS_CON_DELTA}/6 OIDs) : ${NEGRITA}${CIAN}${PUNTEO_FASE2} / ${MAX_PUNTEO_FASE2} pts${RESET}"
echo -e "${CIAN}======================================================================${RESET}"
echo -e " ${NEGRITA}${VERDE}TOTAL                        : ${PUNTEO_TOTAL} pts${RESET} (Base: 100 pts + 15 pts extra)"
echo -e "${NEGRITA}${CIAN}======================================================================${RESET}"
                     
 
