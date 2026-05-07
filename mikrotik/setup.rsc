# ============================================================================
# Dell T320 Fan Control – RouterOS telepítés (Docker Hub image)
# Image: deegabesz/dell-t320-fan-control:latest
#
# HASZNÁLAT:
#   1. Másold a credentials.rsc.example fájlt credentials.rsc néven
#   2. Töltsd ki a credentials.rsc-t a saját adataiddal
#   3. Töltsd fel mindkét fájlt a routerre (pl. usb1/ alá)
#   4. /import file=usb1/setup.rsc
#
# A credentials.rsc külön fájl mert .gitignore-ban van – nem kerül a repo-ba.
# ============================================================================

# Credentials betöltése külön fájlból
:do {
    /import file=usb1/credentials.rsc
} on-error={
    :put "HIBA: usb1/credentials.rsc nem található vagy hibás!"
    :put "Készíts egyet a credentials.rsc.example alapján és tölts fel a routerre."
    :error "Credentials missing"
}

# ============================================================================
# Statikus paraméterek (ezek nem érzékenyek)
# ============================================================================

:local imageName    "deegabesz/dell-t320-fan-control:latest"
:local vethIp       "10.1.3.3/24"
:local vethGateway  "10.1.3.1"
:local sshForwardPort "2222"

# ============================================================================

:log info "=== Fan control telepítés (Docker Hub image) ==="

# --- 1. veth ----------------------------------------------------------------
:if ([:len [/interface/veth/find where name=veth_fan]] = 0) do={
    /interface/veth/add name=veth_fan address=$vethIp gateway=$vethGateway gateway6=""
    :log info "veth_fan létrehozva"
}

# --- 2. Bridge port ---------------------------------------------------------
:if ([:len [/interface/bridge/port/find where interface=veth_fan]] = 0) do={
    /interface/bridge/port/add bridge=bridge_container interface=veth_fan
    :log info "veth_fan bridge-hez adva"
}

# --- 3. Environment változók -----------------------------------------------
:if ([:len [/container/envs/find where list=fan_env]] = 0) do={
    /container/envs/add list=fan_env key=IDRAC_HOST     value=$idracHost
    /container/envs/add list=fan_env key=IDRAC_USER     value=$idracUser
    /container/envs/add list=fan_env key=IDRAC_PASS     value=$idracPass
    /container/envs/add list=fan_env key=SSH_ROOT_PASS  value=$sshRootPass
    /container/envs/add list=fan_env key=TEMP_QUIET     value=$tempQuiet
    /container/envs/add list=fan_env key=TEMP_MAX       value=$tempMax
    /container/envs/add list=fan_env key=SPEED_QUIET    value=$speedQuiet
    /container/envs/add list=fan_env key=SPEED_MEDIUM   value=$speedMedium
    /container/envs/add list=fan_env key=CHECK_INTERVAL value=$checkInterval
    :log info "fan_env létrehozva"
}

# --- 4. Konténer (saját image, NINCS mount) ---------------------------------
:if ([:len [/container/find where name=fan_control]] = 0) do={
    /container/add \
        name=fan_control \
        remote-image=$imageName \
        interface=veth_fan \
        root-dir=/usb1/fan_control_root \
        envlists=fan_env \
        dns=8.8.8.8,1.1.1.1 \
        start-on-boot=yes \
        logging=yes
    :log info "fan_control konténer létrehozva (image: $imageName)"
    :put "Image pull folyamatban..."
    :delay 15s
}

# --- 5. NAT (LAN -> SSH) ---------------------------------------------------
:if ([:len [/ip/firewall/nat/find where comment="SSH to fan_control container"]] = 0) do={
    /ip/firewall/nat/add \
        chain=dstnat \
        dst-port=$sshForwardPort \
        protocol=tcp \
        action=dst-nat \
        to-addresses=10.1.3.3 \
        to-ports=22 \
        in-interface-list=LAN \
        comment="SSH to fan_control container"
    :log info "SSH NAT (port $sshForwardPort)"
}

# --- 6. Delayed start scheduler --------------------------------------------
:if ([:len [/system/scheduler/find where name=fan_control_delayed_start]] = 0) do={
    /system/scheduler/add \
        name=fan_control_delayed_start \
        start-time=startup \
        on-event=":delay 60s; :if ([/container/get [find name=fan_control] status] != \"running\") do={/container/start [find name=fan_control]}" \
        comment="USB mount után indítja a fan_control containert"
    :log info "Delayed start scheduler"
}

# --- 7. Indítás -------------------------------------------------------------
:put ""
:put "Telepítés kész. Konténer indítása..."
/container/start [find name=fan_control]
:delay 10s

:put ""
:put "=== Állapot ==="
/container/print where name=fan_control

:put ""
:put "Logok:    /log/print where topics~\"container\" and message~\"fan_control\""
:put "SSH:      ssh root@10.1.1.1 -p $sshForwardPort"
:put "Image frissítés:"
:put "  /container/stop [find name=fan_control]; :delay 3s;"
:put "  /container/repull [find name=fan_control]; :delay 30s;"
:put "  /container/start [find name=fan_control]"
