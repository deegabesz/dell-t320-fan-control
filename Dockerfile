# =============================================================================
# Dell T320 Fan Control – Alpine alapú Docker image
# Multi-arch: linux/arm64 (RB5009), linux/amd64 (általános)
# =============================================================================

FROM alpine:3.20

LABEL org.opencontainers.image.source="https://github.com/deegabesz/dell-t320-fan-control"
LABEL org.opencontainers.image.description="Dell T320 iDRAC7 dynamic fan control via IPMI LAN"
LABEL org.opencontainers.image.licenses="MIT"

# Csomagok – ipmitool (fan control), openssh (távoli hozzáférés), tzdata (időzóna)
RUN apk add --no-cache \
        ipmitool \
        openssh \
        tzdata \
        ca-certificates \
    && rm -rf /var/cache/apk/*

# SSH konfig: root login + password auth előkészítése
RUN sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#*UsePAM.*/UsePAM no/' /etc/ssh/sshd_config

# Szkriptek bemásolása
COPY fan_control.sh /usr/local/bin/fan_control.sh
COPY entrypoint.sh  /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/fan_control.sh /usr/local/bin/entrypoint.sh

# Időzóna alapértelmezett (env-ből felülírható)
ENV TZ=Europe/Budapest

# SSH port
EXPOSE 22

# Healthcheck: IPMI elérhető-e
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD ipmitool -I lanplus -H "$IDRAC_HOST" -U "$IDRAC_USER" -P "$IDRAC_PASS" chassis status > /dev/null 2>&1 || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
