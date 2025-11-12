#!/bin/bash

# pfRouter routing configuration script
# This script sets up IP forwarding and routing

echo "Starting pfRouter configuration..."

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "IP forwarding enabled"

# Configure routing
# Default route to BGP router
ip route add default via 192.168.100.1

# Add specific routes if needed
# ip route add 10.1.1.0/24 via 192.168.100.1
# ip route add 10.2.2.0/24 via 192.168.100.1

# Set up NAT (optional - for internet access simulation)
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth0 -o eth1 -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "Routing configuration completed"
echo "Routes:"
ip route show
echo ""
echo "Interfaces:"
ip addr show
echo ""
echo "pfRouter is ready!"
