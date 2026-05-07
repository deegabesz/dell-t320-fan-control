#!/bin/sh
# =============================================================================
# Entrypoint script
# - SSH host kulcsok generálása ha még nincsenek (csak első indításnál ír)
# - root jelszó beállítása env változóból
# - sshd indítása háttérben
# - fan_control.sh foreground indítás
# =============================================================================

set -e

# --- SSH host kulcsok -------------------------------------------------------
if [ ! -f /etc/ssh/ssh_host_rsa_key ] || [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
    echo "[entrypoint] SSH host kulcsok generálása..."
    ssh-keygen -A
    echo "[entrypoint] SSH host kulcsok kész"
fi

# --- Root jelszó ------------------------------------------------------------
if [ -n "$SSH_ROOT_PASS" ]; then
    echo "root:$SSH_ROOT_PASS" | chpasswd
    echo "[entrypoint] root jelszó beállítva env-ből"
else
    echo "[entrypoint] FIGYELEM: SSH_ROOT_PASS nincs beállítva, SSH login nem fog működni!"
fi

# --- SSH daemon (háttér) ----------------------------------------------------
echo "[entrypoint] SSH daemon indítása (port 22)"
/usr/sbin/sshd

# --- Fan control (foreground, exec hogy a signal-ek átmenjenek) -------------
echo "[entrypoint] Fan control indítása"
exec /usr/local/bin/fan_control.sh
