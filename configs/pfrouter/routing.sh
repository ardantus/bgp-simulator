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

# Set up NAT (optional - for internet access simulation)
# Note: eth0 is the client-facing interface (192.168.200.0/24)
#       eth1 is the internal/external interface toward the BGP router (192.168.100.0/24)
# We want to masquerade traffic leaving via eth1 and allow forwarding from eth0 -> eth1
iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE || echo "Failed to add POSTROUTING rule"
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
