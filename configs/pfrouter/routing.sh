#!/bin/bash

# pfRouter routing configuration script
# This script sets up IP forwarding and routing

echo "Starting pfRouter configuration..."

# Enable IP forwarding if writable
if [ -w /proc/sys/net/ipv4/ip_forward ]; then
	echo 1 > /proc/sys/net/ipv4/ip_forward && echo "IP forwarding enabled"
else
	echo "Warning: /proc/sys/net/ipv4/ip_forward is not writable; skipping sysctl write"
fi

# Configure routing
# Ensure default route goes to BGP router (docker-compose assigned IP 192.168.100.10)
# Remove any existing default and add the correct one via the internal interface (eth1)
ip route del default 2>/dev/null || true
ip route add default via 192.168.100.10 dev eth1 || ip route add default via 192.168.100.10 || echo "Failed to add default route"

# Add specific routes if needed
# ip route add 10.1.1.0/24 via 192.168.100.10
# ip route add 10.2.2.0/24 via 192.168.100.10

# Forwarding rules (pfrouter should forward client traffic to the internal/BGP side)
# Note: NAT (MASQUERADE) is intentionally left to the ISP container to be more realistic.
iptables -A FORWARD -i eth0 -o eth1 -j ACCEPT || true
iptables -A FORWARD -i eth1 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT || true

echo "Routing configuration completed"
echo "Routes:"
ip route show
echo ""
echo "Interfaces:"
ip addr show
echo ""
echo "pfRouter is ready!"
