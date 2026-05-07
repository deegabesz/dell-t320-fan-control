# ============================================================================
# Dell T320 Fan Control – Régi konfiguráció takarítása
# Használat: /import file=cleanup.rsc
# ============================================================================

:log info "=== Fan control cleanup kezdődik ==="

# Konténer leállítása és eltávolítása
:if ([:len [/container/find where name=fan_control]] > 0) do={
    /container/stop [find name=fan_control]
    :delay 3s
    /container/remove [find name=fan_control]
    :log info "fan_control konténer eltávolítva"
}

# Environment változók eltávolítása
:if ([:len [/container/envs/find where list=fan_env]] > 0) do={
    /container/envs/remove [find list=fan_env]
    :log info "fan_env env változók eltávolítva"
}

# Mount eltávolítása
:if ([:len [/container/mounts/find where list=fan_scripts]] > 0) do={
    /container/mounts/remove [find list=fan_scripts]
    :log info "fan_scripts mount eltávolítva"
}

# Bridge port eltávolítása
:if ([:len [/interface/bridge/port/find where interface=veth_fan]] > 0) do={
    /interface/bridge/port/remove [find interface=veth_fan]
    :log info "veth_fan bridge port eltávolítva"
}

# veth interfész eltávolítása
:if ([:len [/interface/veth/find where name=veth_fan]] > 0) do={
    /interface/veth/remove [find name=veth_fan]
    :log info "veth_fan interfész eltávolítva"
}

# NAT szabály eltávolítása
:if ([:len [/ip/firewall/nat/find where comment="SSH to fan_control container"]] > 0) do={
    /ip/firewall/nat/remove [find comment="SSH to fan_control container"]
    :log info "SSH NAT szabály eltávolítva"
}

# Scheduler eltávolítása
:if ([:len [/system/scheduler/find where name=fan_control_delayed_start]] > 0) do={
    /system/scheduler/remove [find name=fan_control_delayed_start]
    :log info "Scheduler eltávolítva"
}

:log info "=== Fan control cleanup kész ==="
:put "Cleanup kész. Most telepítsd a setup.rsc-t."
