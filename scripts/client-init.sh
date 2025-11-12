#!/usr/bin/env bash
set -euo pipefail

echo "[client-init] Starting client init script"

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y iproute2 iputils-ping tcpdump traceroute curl wget net-tools dnsutils -qq

# Create a traceroute wrapper that defaults to ICMP probes (more likely to show final hop)
cat > /tmp/traceroute-wrapper.sh <<'TRW'
#!/bin/bash
# Wrapper: if user didn't request ICMP/TCP/UDP explicitly, use ICMP (-I)
has_flag() {
  for a in "$@"; do
    case "$a" in
      -I|-T|-U|--icmp|--tcp) return 0 ;;
    esac
  done
  return 1
}
if has_flag "$@"; then
  exec /usr/bin/traceroute "$@"
else
  exec /usr/bin/traceroute -I "$@"
fi
TRW

chmod +x /tmp/traceroute-wrapper.sh || true
mv /tmp/traceroute-wrapper.sh /usr/local/bin/traceroute || cp /tmp/traceroute-wrapper.sh /usr/local/bin/traceroute

echo "[client-init] Setting default route via pfrouter"
ip route del default || true
ip route add default via 192.168.200.254 || true

echo "[client-init] Client init complete, entering idle"
tail -f /dev/null
