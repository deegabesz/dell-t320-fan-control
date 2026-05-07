#!/bin/sh
# =============================================================================
# Dell T320 iDRAC7 dinamikus fan kontrol – ipmitool alapú
# Env változók használata (list=fan_env)
# =============================================================================

: "${IDRAC_HOST:=10.1.1.8}"
: "${IDRAC_USER:=xd}"
: "${IDRAC_PASS:?IDRAC_PASS nincs beállítva!}"

: "${TEMP_QUIET:=70}"
: "${TEMP_MAX:=80}"
: "${SPEED_QUIET:=0x07}"
: "${SPEED_MEDIUM:=0x19}"
: "${CHECK_INTERVAL:=30}"

IPMI="ipmitool -I lanplus -H $IDRAC_HOST -U $IDRAC_USER -P $IDRAC_PASS"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

get_cpu_temp() {
    # CPU1 Temp sensor ID = 0Eh a T320-on
    $IPMI sdr type temperature 2>/dev/null \
        | grep "0Eh" \
        | awk -F'|' '{print $5}' \
        | grep -oE '[0-9]+' \
        | head -1
}

fan_manual() {
    # 0x00 = manuális (mi irányítunk), 0x01 = iDRAC auto
    $IPMI raw 0x30 0x30 0x01 "$1" >/dev/null 2>&1
}

fan_speed() {
    $IPMI raw 0x30 0x30 0x02 0xff "$1" >/dev/null 2>&1
}

cleanup() {
    log "LEÁLLÍTÁS – iDRAC auto mód visszaállítva"
    fan_manual 0x01
    exit 0
}

trap cleanup INT TERM

log "Dell T320 fan kontrol indítva (ipmitool)"
log "iDRAC: $IDRAC_HOST | csendes <${TEMP_QUIET}°C (PWM $SPEED_QUIET) | közepes <${TEMP_MAX}°C (PWM $SPEED_MEDIUM)"

# Kapcsolat teszt
log "IPMI kapcsolat ellenőrzése..."
for i in 1 2 3 4 5; do
    if $IPMI chassis status >/dev/null 2>&1; then
        log "IPMI kapcsolat OK"
        break
    fi
    log "Kísérlet $i sikertelen, 10s múlva újra"
    sleep 10
    if [ "$i" = "5" ]; then
        log "HIBA: iDRAC nem elérhető – kilépés"
        exit 1
    fi
done

CURRENT_MODE=""

while true; do
    TEMP=$(get_cpu_temp)

    if [ -z "$TEMP" ] || [ "$TEMP" -eq 0 ] 2>/dev/null; then
        if [ "$CURRENT_MODE" != "auto" ]; then
            log "Hőmérséklet nem olvasható → iDRAC auto"
            fan_manual 0x01
            CURRENT_MODE="auto"
        fi
    elif [ "$TEMP" -ge "$TEMP_MAX" ]; then
        if [ "$CURRENT_MODE" != "auto" ]; then
            log "MAGAS HŐ ${TEMP}°C >= ${TEMP_MAX}°C → iDRAC auto"
            fan_manual 0x01
            CURRENT_MODE="auto"
        fi
    elif [ "$TEMP" -ge "$TEMP_QUIET" ]; then
        if [ "$CURRENT_MODE" != "medium" ]; then
            log "Közepes: ${TEMP}°C → PWM $SPEED_MEDIUM"
            fan_manual 0x00
            fan_speed "$SPEED_MEDIUM"
            CURRENT_MODE="medium"
        fi
    else
        if [ "$CURRENT_MODE" != "quiet" ]; then
            log "Csendes: ${TEMP}°C → PWM $SPEED_QUIET"
            fan_manual 0x00
            fan_speed "$SPEED_QUIET"
            CURRENT_MODE="quiet"
        fi
    fi

    sleep "$CHECK_INTERVAL"
done
