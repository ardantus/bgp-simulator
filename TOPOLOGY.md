# Network Topology Diagram

## Visual Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet (Simulated)                     │
└─────────────────┬──────────────────────────┬────────────────────┘
                  │                          │
                  │                          │
         ┌────────▼────────┐        ┌────────▼────────┐
         │   ISP1 Router   │        │   ISP2 Router   │
         │   AS65001       │        │   AS65002       │
         │   10.1.1.1/24   │        │   10.2.2.1/24   │
         │                 │        │                 │
         │   BIRD BGP      │        │   BIRD BGP      │
         └────────┬────────┘        └────────┬────────┘
                  │                          │
                  │                          │
                  └────────┬─────────────────┘
                           │
                  ┌────────▼────────┐
                  │   BGP Router    │
                  │   AS65000       │
                  │   (Your Network)│
                  │                 │
                  │  10.1.1.2/24    │ ← ISP1 Connection
                  │  10.2.2.2/24    │ ← ISP2 Connection
                  │  192.168.100.1  │ ← Internal
                  │                 │
                  │   BIRD BGP      │
                  └────────┬────────┘
                           │
                           │ Internal Network
                           │ 192.168.100.0/24
                           │
                  ┌────────▼────────┐
                  │    pfRouter     │
                  │  Linux Router   │
                  │                 │
                  │  192.168.100.2  │ ← Uplink
                  │  192.168.200.1  │ ← Downlink
                  │                 │
                  │  IP Forwarding  │
                  │  NAT/Firewall   │
                  └────────┬────────┘
                           │
                           │ Client Network
                           │ 192.168.200.0/24
                           │
                  ┌────────▼────────┐
                  │  Ubuntu Client  │
                  │                 │
                  │  192.168.200.10 │
                  │                 │
                  │  traceroute     │
                  │  ping, curl     │
                  └─────────────────┘
```

## Detailed Network Layout

### Layer 1: ISP Layer
```
┌──────────────────────────────────────────────────────────┐
│ ISP1 (AS65001)              ISP2 (AS65002)              │
│ Network: 10.1.1.0/24        Network: 10.2.2.0/24        │
│                                                          │
│ Routes Announced:           Routes Announced:           │
│ - 8.8.8.0/24               - 9.9.9.0/24                 │
│ - 1.1.1.0/24               - 4.4.4.0/24                 │
│ - 203.0.113.0/24           - 198.51.100.0/24            │
└──────────────────────────────────────────────────────────┘
```

### Layer 2: BGP Router Layer
```
┌──────────────────────────────────────────────────────────┐
│ BGP Router (AS65000)                                     │
│                                                          │
│ Interfaces:                                              │
│ - eth0: 10.1.1.2/24   (to ISP1)                         │
│ - eth1: 10.2.2.2/24   (to ISP2)                         │
│ - eth2: 192.168.100.1/24 (internal)                     │
│                                                          │
│ BGP Peering:                                             │
│ - Peer 1: 10.1.1.1 (ISP1 - AS65001)                     │
│ - Peer 2: 10.2.2.1 (ISP2 - AS65002)                     │
│                                                          │
│ Advertised Networks:                                     │
│ - 192.168.0.0/16 (Your network)                         │
└──────────────────────────────────────────────────────────┘
```

### Layer 3: pfRouter Layer
```
┌──────────────────────────────────────────────────────────┐
│ pfRouter (Linux Router)                                  │
│                                                          │
│ Interfaces:                                              │
│ - eth0: 192.168.100.2/24 (uplink to BGP)               │
│ - eth1: 192.168.200.1/24 (downlink to clients)         │
│                                                          │
│ Functions:                                               │
│ - IP Forwarding: Enabled                                │
│ - NAT: MASQUERADE on eth0                               │
│ - Default Route: via 192.168.100.1                      │
└──────────────────────────────────────────────────────────┘
```

### Layer 4: Client Layer
```
┌──────────────────────────────────────────────────────────┐
│ Ubuntu Client                                            │
│                                                          │
│ Interface:                                               │
│ - eth0: 192.168.200.10/24                               │
│                                                          │
│ Default Gateway: 192.168.200.1 (pfRouter)               │
│                                                          │
│ Installed Tools:                                         │
│ - traceroute, ping, curl, wget                          │
│ - ip, netstat, ss                                        │
│ - tcpdump, dnsutils                                      │
└──────────────────────────────────────────────────────────┘
```

## Network Flow Examples

### Example 1: Client to ISP1
```
Client (192.168.200.10)
    |
    | Layer 4: Client Network
    ↓
pfRouter (192.168.200.1)
    |
    | Layer 3: Internal Network
    ↓
pfRouter (192.168.100.2)
    |
    | Layer 3: Internal Network
    ↓
BGP Router (192.168.100.1)
    |
    | Layer 2: ISP1 Network
    ↓
BGP Router (10.1.1.2)
    |
    | BGP Peering
    ↓
ISP1 (10.1.1.1)
```

### Example 2: BGP Route Advertisement
```
ISP1 (AS65001)
    |
    | BGP UPDATE: Route 8.8.8.0/24, AS_PATH: 65001
    ↓
BGP Router (AS65000)
    |
    | Imports route with LP=100
    | Best path selection
    ↓
Kernel Routing Table
    |
    | Routes installed
    ↓
Available to pfRouter and Client
```

### Example 3: Failover Scenario
```
Normal Operation:
ISP1 (Primary) ←─── BGP Router ───→ ISP2 (Backup)
     └─────────────────┬───────────────────┘
                       │
              Traffic via ISP1 (LP=100)

After ISP1 Failure:
ISP1 (DOWN)     BGP Router ───→ ISP2 (Now Primary)
                       │
              Traffic via ISP2 (LP=90)
              Convergence time: ~10 seconds
```

## Docker Network Mapping

```
Docker Networks:
┌──────────────────────────────────────────────────────────┐
│ isp1_network (10.1.1.0/24)                               │
│   - isp1: 10.1.1.1                                       │
│   - bgp-router: 10.1.1.2                                 │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ isp2_network (10.2.2.0/24)                               │
│   - isp2: 10.2.2.1                                       │
│   - bgp-router: 10.2.2.2                                 │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ internal_network (192.168.100.0/24)                      │
│   - bgp-router: 192.168.100.1                            │
│   - pfrouter: 192.168.100.2                              │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ client_network (192.168.200.0/24)                        │
│   - pfrouter: 192.168.200.1                              │
│   - client: 192.168.200.10                               │
└──────────────────────────────────────────────────────────┘
```

## Port Usage

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| BIRD BGP | 179 | TCP | BGP Peering |
| SSH (if enabled) | 22 | TCP | Remote Access |

## Traffic Flow Matrix

| Source | Destination | Path | Hops |
|--------|------------|------|------|
| Client → ISP1 | 10.1.1.1 | client → pfrouter → bgp-router → isp1 | 3 |
| Client → ISP2 | 10.2.2.1 | client → pfrouter → bgp-router → isp2 | 3 |
| BGP Router → ISP1 | 10.1.1.1 | bgp-router → isp1 | 1 |
| BGP Router → ISP2 | 10.2.2.1 | bgp-router → isp2 | 1 |

## BGP Session Details

### AS Path Information
```
From Client perspective:
  → Routes to 8.8.8.0/24: AS_PATH = 65000 → 65001
  → Routes to 9.9.9.0/24: AS_PATH = 65000 → 65002

From ISP1 perspective:
  → Routes to 192.168.0.0/16: AS_PATH = 65000

From ISP2 perspective:
  → Routes to 192.168.0.0/16: AS_PATH = 65000
```

### BGP Attributes Summary
```
BGP Router Default Attributes:
┌────────────────────────────────────────────┐
│ Attribute          ISP1        ISP2        │
├────────────────────────────────────────────┤
│ Local AS           65000       65000       │
│ Peer AS            65001       65002       │
│ Local Preference   100 (def)   90          │
│ Hold Time          90s         90s         │
│ Keepalive          30s         30s         │
│ Next Hop Self      Yes         Yes         │
└────────────────────────────────────────────┘
```

## Routing Decision Process

```
┌──────────────────────────────────────────────────────────┐
│ BGP Best Path Selection (in order)                       │
├──────────────────────────────────────────────────────────┤
│ 1. Highest Weight (Cisco specific - N/A)                │
│ 2. Highest Local Preference ⭐                           │
│ 3. Locally originated routes                             │
│ 4. Shortest AS Path                                      │
│ 5. Lowest Origin (IGP < EGP < Incomplete)               │
│ 6. Lowest MED                                            │
│ 7. eBGP over iBGP                                        │
│ 8. Lowest IGP metric to next hop                        │
│ 9. Oldest route (for stability)                         │
│ 10. Lowest Router ID                                     │
└──────────────────────────────────────────────────────────┘

In our setup:
- ISP1 preferred by default (LP=100)
- ISP2 backup (LP=90)
```

## Summary

- **5 Containers**: isp1, isp2, bgp-router, pfrouter, client
- **4 Networks**: ISP1, ISP2, Internal, Client
- **3 ASNs**: 65000, 65001, 65002
- **2 BGP Sessions**: BGP Router ↔ ISP1, BGP Router ↔ ISP2
- **Full Layer 3 Routing**: From client to ISPs

This topology provides a complete learning environment for BGP!
