# Dell T320 Fan Control

Dynamic IPMI-based fan control for Dell PowerEdge T320 servers running ESXi (or any other hypervisor/OS) where the iDRAC7 firmware does not support the `Custom` thermal profile.

Runs as a Docker container, designed for **MikroTik RouterOS containers** (RB5009 ARM64) but works on any Docker host (linux/amd64, linux/arm64).

## Why this exists

The Dell T320 with iDRAC7 firmware 2.65.65.65 (the latest available) does not support the `Custom` thermal profile. The minimum fan PWM with `Minimum Power` profile is **30%**, which results in ~1920 RPM — noisy for a home lab even at 15°C ambient.

This container uses IPMI raw commands to:
- Disable iDRAC's automatic fan control
- Set a manual PWM value as low as 2% (~600 RPM) when CPU is cool
- Step up to a configurable medium PWM when temperature rises
- Hand control back to the iDRAC at a configurable safety threshold

## Features

- **Tiny footprint**: Alpine-based, ~30MB image
- **Multi-arch**: `linux/amd64` and `linux/arm64`
- **Read-only operation**: minimal writes to host storage (only initial SSH host keys)
- **Built-in SSH**: troubleshoot the container directly without docker exec
- **Healthcheck**: container marked unhealthy if iDRAC unreachable
- **Safety**: on container stop or temp >= TEMP_MAX, control returns to iDRAC

## Image

```
docker pull deegabesz/dell-t320-fan-control:latest
```

## Configuration

All configuration via environment variables:

| Variable | Default | Description |
|---|---|---|
| `IDRAC_HOST` | (required) | iDRAC IP address |
| `IDRAC_USER` | (required) | iDRAC username |
| `IDRAC_PASS` | (required) | iDRAC password |
| `SSH_ROOT_PASS` | (none, SSH disabled) | Root password for container SSH |
| `TEMP_QUIET` | `70` | Below this °C → quiet mode |
| `TEMP_MAX` | `85` | Above this °C → return to iDRAC auto |
| `SPEED_QUIET` | `0x02` | PWM hex value for quiet mode (~2%) |
| `SPEED_MEDIUM` | `0x08` | PWM hex value for medium mode (~8%) |
| `CHECK_INTERVAL` | `30` | Seconds between temperature checks |
| `TZ` | `Europe/Budapest` | Container timezone |

## PWM reference (T320, single fan)

| PWM | RPM | Notes |
|---|---|---|
| `0x02` (2%) | ~600 | Stable minimum |
| `0x05` (5%) | ~720 | |
| `0x08` (8%) | ~840 | Recommended medium |
| `0x0a` (10%) | ~960 | |
| `0x19` (25%) | ~1400 | Old default medium |
| `0x1e` (30%) | ~1920 | iDRAC default minimum |

Lower critical threshold: 360 RPM. Below this, the iDRAC may raise a warning.

## Usage

### Generic Docker

```bash
docker run -d \
  --name fan_control \
  --restart unless-stopped \
  -e IDRAC_HOST=10.1.1.8 \
  -e IDRAC_USER=xd \
  -e IDRAC_PASS='your-password' \
  -e SSH_ROOT_PASS='ssh-password' \
  -p 2222:22 \
  deegabesz/dell-t320-fan-control:latest
```

### MikroTik RouterOS

See [`mikrotik/setup.rsc`](mikrotik/setup.rsc). Edit credentials at the top of the file, then:

```
/import file=setup.rsc
```

Prerequisites:
- `bridge_container` bridge with `10.1.3.0/24` subnet
- USB/persistent storage mounted at `/usb1`
- NAT masquerade for `10.1.3.0/24`
- IPMI over LAN enabled on the iDRAC

## Building locally

```bash
docker buildx create --use --name multiarch
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t deegabesz/dell-t320-fan-control:dev \
  --push .
```

## CI/CD

GitHub Actions workflow at [`.github/workflows/build.yml`](.github/workflows/build.yml) builds and pushes on every push to `main`.

Required secrets:
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN` (Docker Hub PAT with Read & Write permission)

## Sensor IDs

The container reads the CPU1 temperature from sensor `0Eh`. If your hardware uses a different sensor ID:

```bash
ssh root@<container-ip>
ipmitool -I lanplus -H "$IDRAC_HOST" -U "$IDRAC_USER" -P "$IDRAC_PASS" sdr type temperature
```

Find your CPU sensor row, note the ID (`XXh`), and edit `fan_control.sh` line containing `grep "0Eh"`.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `IPMI kapcsolat ellenőrzése...` then exit | Wrong credentials or IPMI LAN disabled |
| `Hőmérséklet nem olvasható` | Wrong sensor ID for your board |
| `iDRAC auto` mode logged repeatedly | Sensor reading temporarily unavailable |
| Container constantly restarts | Healthcheck fails – check IDRAC_HOST reachability |

## License

MIT — see [LICENSE](LICENSE)

## Disclaimer

Setting PWM values too low may cause inadequate cooling. **Always monitor temperatures** after deploying. The container falls back to iDRAC auto control above `TEMP_MAX`, but this is your responsibility to configure appropriately for your environment.

The original need for this project came from the limitations of iDRAC7 firmware 2.65.65.65 on the T320. Newer Dell servers (12G+) running iDRAC8/9 should use the built-in Custom thermal profile instead.
