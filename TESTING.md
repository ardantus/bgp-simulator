# Testing Guide - BGP Simulator

## Automated Testing Steps

### Pre-flight Checks

1. **System Requirements**
   ```bash
   # Check Docker version
   docker --version
   # Should be >= 20.10
   
   # Check Docker Compose version
   docker compose version
   # Should be >= 1.29 or 2.0+
   
   # Check available memory
   free -h
   # Should have at least 2GB free
   ```

2. **Network Requirements**
   ```bash
   # Check no port conflicts
   netstat -tuln | grep -E ':(179|22|80|443)'
   # BGP port 179 should be free
   ```

### Build and Start

```bash
# Navigate to project directory
cd bgp-simulator

# Build images (first time or after changes)
docker compose build

# Start all services
docker compose up -d

# Wait for BGP convergence
echo "Waiting 30 seconds for BGP peering..."
sleep 30
```

### Test 1: Container Health

```bash
# Check all containers are running
docker compose ps

# Expected: All 5 containers in "Up" state
# - isp1
# - isp2
# - bgp-router
# - pfrouter
# - client
```

### Test 2: Network Connectivity

```bash
# Test basic connectivity from client
echo "Testing ISP1 connectivity..."
docker compose exec -T client ping -c 3 10.1.1.1

echo "Testing ISP2 connectivity..."
docker compose exec -T client ping -c 3 10.2.2.1

echo "Testing pfRouter connectivity..."
docker compose exec -T client ping -c 3 192.168.200.1

# All pings should succeed with 0% packet loss
```

### Test 3: BGP Peering Status

```bash
echo "Checking BGP peering status..."

# Check BGP protocols on main router
docker compose exec -T bgp-router birdc show protocols | grep -E "(isp1|isp2)"

# Expected output should contain:
# isp1     BGP      ---      up     <timestamp>  Established
# isp2     BGP      ---      up     <timestamp>  Established
```

### Test 4: Route Exchange

```bash
echo "Checking route exchange..."

# Check routes received from ISP1
docker compose exec -T bgp-router birdc 'show route where bgp_path ~ [= * 65001 * =]'

# Check routes received from ISP2
docker compose exec -T bgp-router birdc 'show route where bgp_path ~ [= * 65002 * =]'

# Should see routes from both ISPs
```

### Test 5: End-to-End Routing

```bash
echo "Testing end-to-end routing..."

# Check routing table on client
docker compose exec -T client ip route show

# Should have default route via 192.168.200.1

# Test traceroute
docker compose exec -T client traceroute -n -m 5 10.1.1.1
docker compose exec -T client traceroute -n -m 5 10.2.2.1

# Should see path: client -> pfrouter -> bgp-router -> ISP
```

### Test 6: IP Forwarding

```bash
echo "Checking IP forwarding..."

# BGP router
docker compose exec -T bgp-router sysctl net.ipv4.ip_forward
# Should output: net.ipv4.ip_forward = 1

# pfRouter
docker compose exec -T pfrouter sysctl net.ipv4.ip_forward
# Should output: net.ipv4.ip_forward = 1
```

### Test 7: Failover Scenario

```bash
echo "Testing BGP failover..."

# Baseline - check current routes
docker compose exec -T bgp-router birdc show route | tee /tmp/routes_before.txt

# Simulate ISP1 failure
docker compose stop isp1
sleep 10

# Check BGP status - ISP1 should be down
docker compose exec -T bgp-router birdc show protocols

# Check routes redistributed to ISP2
docker compose exec -T bgp-router birdc show route | tee /tmp/routes_after.txt

# Restore ISP1
docker compose start isp1
sleep 30

# Verify BGP reconvergence
docker compose exec -T bgp-router birdc show protocols
```

### Test 8: Configuration Syntax

```bash
echo "Checking BIRD configuration syntax..."

# BGP Router
docker compose exec -T bgp-router bird -p -c /etc/bird/bird.conf
echo "BGP Router config: OK"

# ISP1
docker compose exec -T isp1 bird -p -c /etc/bird/bird.conf
echo "ISP1 config: OK"

# ISP2
docker compose exec -T isp2 bird -p -c /etc/bird/bird.conf
echo "ISP2 config: OK"
```

### Test 9: Logs Check

```bash
echo "Checking for errors in logs..."

# Check for errors
docker compose logs | grep -i error | head -20

# Check for BGP state changes
docker compose logs bgp-router | grep -i "established\|connect"

# Should see "BGP session established" messages
```

### Test 10: Resource Usage

```bash
echo "Checking resource usage..."

# Check CPU and memory usage
docker stats --no-stream

# All containers should be under reasonable resource usage
# (<100MB RAM per container, <5% CPU)
```

## Automated Test Script

Save this as `test.sh`:

```bash
#!/bin/bash

set -e

echo "========================================"
echo "BGP Simulator - Automated Test Suite"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

test_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
}

test_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    exit 1
}

test_warn() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1"
}

echo "Test 1: Container Health Check"
if docker compose ps | grep -q "Up"; then
    test_pass "Containers are running"
else
    test_fail "Containers are not running"
fi

echo ""
echo "Test 2: BGP Peering Check"
BGP_STATUS=$(docker compose exec -T bgp-router birdc show protocols 2>&1)
if echo "$BGP_STATUS" | grep -q "Established"; then
    test_pass "BGP peering established"
else
    test_warn "BGP peering not fully established yet"
fi

echo ""
echo "Test 3: Network Connectivity"
if docker compose exec -T client ping -c 1 -W 2 10.1.1.1 >/dev/null 2>&1; then
    test_pass "Client can reach ISP1"
else
    test_fail "Client cannot reach ISP1"
fi

if docker compose exec -T client ping -c 1 -W 2 10.2.2.1 >/dev/null 2>&1; then
    test_pass "Client can reach ISP2"
else
    test_fail "Client cannot reach ISP2"
fi

echo ""
echo "Test 4: Route Exchange"
ROUTES=$(docker compose exec -T bgp-router birdc show route 2>&1)
if echo "$ROUTES" | grep -q "8.8.8.0/24"; then
    test_pass "Routes from ISP1 received"
else
    test_warn "Routes from ISP1 not visible"
fi

if echo "$ROUTES" | grep -q "9.9.9.0/24"; then
    test_pass "Routes from ISP2 received"
else
    test_warn "Routes from ISP2 not visible"
fi

echo ""
echo "Test 5: IP Forwarding"
FWD_BGP=$(docker compose exec -T bgp-router sysctl net.ipv4.ip_forward 2>&1 | grep -o "[01]$")
if [ "$FWD_BGP" = "1" ]; then
    test_pass "IP forwarding enabled on BGP router"
else
    test_fail "IP forwarding disabled on BGP router"
fi

FWD_PF=$(docker compose exec -T pfrouter sysctl net.ipv4.ip_forward 2>&1 | grep -o "[01]$")
if [ "$FWD_PF" = "1" ]; then
    test_pass "IP forwarding enabled on pfRouter"
else
    test_fail "IP forwarding disabled on pfRouter"
fi

echo ""
echo "========================================"
echo "All tests completed!"
echo "========================================"
```

Make it executable and run:

```bash
chmod +x test.sh
./test.sh
```

## Manual Verification Steps

### Visual Inspection

1. **Check BGP neighbor states**
   ```bash
   docker compose exec bgp-router birdc show protocols all
   ```
   Verify:
   - Neighbor state: Established
   - Hold timer: Active
   - Routes: Imported and exported

2. **Inspect routing tables**
   ```bash
   # BGP Router
   docker compose exec bgp-router birdc show route all
   
   # Linux kernel routing
   docker compose exec bgp-router ip route show
   
   # pfRouter
   docker compose exec pfrouter ip route show
   
   # Client
   docker compose exec client ip route show
   ```

3. **Check BGP attributes**
   ```bash
   docker compose exec bgp-router birdc 'show route all where net = 8.8.8.0/24'
   ```
   Look for:
   - AS path
   - Next hop
   - Local preference
   - Origin

### Interactive Testing

1. **BGP session manipulation**
   ```bash
   # Disable ISP1
   docker compose exec bgp-router birdc disable isp1
   
   # Wait and observe
   sleep 5
   docker compose exec bgp-router birdc show route
   
   # Re-enable
   docker compose exec bgp-router birdc enable isp1
   ```

2. **Traffic path tracing**
   ```bash
   # From client to different destinations
   docker compose exec client traceroute -n 8.8.8.8
   docker compose exec client traceroute -n 9.9.9.9
   docker compose exec client traceroute -n 10.1.1.1
   docker compose exec client traceroute -n 10.2.2.1
   ```

3. **Packet capture**
   ```bash
   # Capture BGP traffic
   docker compose exec bgp-router tcpdump -i eth0 -n port 179 -c 20
   
   # Capture ICMP traffic
   docker compose exec pfrouter tcpdump -i any icmp -n -c 10
   ```

## Performance Benchmarks

### Expected Performance Metrics

| Metric | Expected Value |
|--------|----------------|
| BGP Peering Time | < 30 seconds |
| Ping Latency | < 1ms (local) |
| Failover Time | < 10 seconds |
| Memory per Container | < 100MB |
| CPU Usage | < 5% idle |
| Route Count | ~6 routes from ISPs |

### Load Testing

```bash
# Ping test
docker compose exec client ping -c 100 -i 0.1 10.1.1.1

# Should see:
# - 0% packet loss
# - RTT < 1ms average
```

## Troubleshooting Common Issues

### Issue: BGP not establishing

**Check:**
```bash
# Verify IP connectivity
docker compose exec bgp-router ping 10.1.1.1
docker compose exec bgp-router ping 10.2.2.1

# Check BIRD is running
docker compose exec bgp-router ps aux | grep bird

# Check BIRD logs
docker compose logs bgp-router | tail -50
```

**Fix:**
```bash
# Restart BGP router
docker compose restart bgp-router
```

### Issue: No routes received

**Check:**
```bash
# Verify BGP session is established
docker compose exec bgp-router birdc show protocols all

# Check import filters
docker compose exec bgp-router birdc show route all
```

**Fix:**
```bash
# Check BIRD configuration
docker compose exec bgp-router cat /etc/bird/bird.conf
```

### Issue: Client cannot reach ISPs

**Check:**
```bash
# Verify routing on client
docker compose exec client ip route show

# Verify IP forwarding on pfRouter
docker compose exec pfrouter sysctl net.ipv4.ip_forward

# Check NAT rules
docker compose exec pfrouter iptables -t nat -L -n -v
```

**Fix:**
```bash
# Restart pfRouter
docker compose restart pfrouter
```

## Cleanup

```bash
# Stop all containers
docker compose down

# Remove all data
docker compose down -v

# Remove images
docker compose down -v --rmi all

# Full cleanup including networks
docker compose down -v --rmi all --remove-orphans
```

## Success Criteria

✅ All 5 containers running
✅ BGP peering established (both ISPs)
✅ Routes exchanged (6+ routes)
✅ End-to-end connectivity working
✅ Failover working correctly
✅ No errors in logs
✅ Resource usage reasonable

If all criteria met: **Setup is successful!** 🎉
