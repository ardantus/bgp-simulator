# Skenario Pembelajaran BGP

## Skenario 1: Basic BGP Peering

### Tujuan
Memahami cara BGP peering bekerja dan melihat route exchange

### Steps

1. **Start environment**
   ```bash
   docker compose up -d
   ```

2. **Monitor BGP establishment**
   ```bash
   # Watch BGP peering process
   docker compose logs -f bgp-router
   ```

3. **Verify peering**
   ```bash
   docker compose exec bgp-router birdc show protocols
   ```

4. **View exchanged routes**
   ```bash
   docker compose exec bgp-router birdc show route
   ```

### Expected Results
- Both ISP1 dan ISP2 status "Established"
- Routes dari ISP1: 8.8.8.0/24, 1.1.1.0/24, 203.0.113.0/24
- Routes dari ISP2: 9.9.9.0/24, 4.4.4.0/24, 198.51.100.0/24

---

## Skenario 2: Path Selection

### Tujuan
Memahami bagaimana BGP memilih best path

### Steps

1. **Check initial routing table**
   ```bash
   docker compose exec bgp-router birdc show route all
   ```

2. **Analyze path attributes**
   - Local Preference
   - AS Path length
   - Next hop

3. **Verify preferred path**
   ```bash
   docker compose exec bgp-router birdc 'show route where bgp_path ~ [= * 65001 * =]'
   docker compose exec bgp-router birdc 'show route where bgp_path ~ [= * 65002 * =]'
   ```

### Questions to Answer
- Route mana yang dipilih untuk reach internet?
- Mengapa route tersebut dipilih?
- Apa role Local Preference dalam path selection?

---

## Skenario 3: Link Failure & Convergence

### Tujuan
Simulasi link failure dan observe BGP convergence

### Steps

1. **Establish baseline**
   ```bash
   # From client, check connectivity
   docker compose exec client ping -c 4 10.1.1.1
   docker compose exec client traceroute 10.1.1.1
   ```

2. **Simulate ISP1 failure**
   ```bash
   docker compose stop isp1
   ```

3. **Observe convergence**
   ```bash
   # Watch routing table changes
   docker compose exec bgp-router birdc show route
   
   # Check logs
   docker compose logs bgp-router | tail -20
   ```

4. **Test connectivity**
   ```bash
   # Traffic should now go via ISP2
   docker compose exec client traceroute 9.9.9.9
   ```

5. **Restore ISP1**
   ```bash
   docker compose start isp1
   
   # Wait for convergence
   sleep 30
   
   # Check routes restored
   docker compose exec bgp-router birdc show protocols
   ```

### Timing to Observe
- Berapa lama BGP detect failure?
- Berapa lama convergence time?
- Apakah ada packet loss during failover?

---

## Skenario 4: Route Filtering

### Tujuan
Implement route filtering untuk control route advertisement

### Steps

1. **Backup original config**
   ```bash
   cp configs/bgp-router/bird.conf configs/bgp-router/bird.conf.backup
   ```

2. **Edit BGP router config**
   ```bash
   vim configs/bgp-router/bird.conf
   ```

3. **Add filtering ke ISP1**
   ```bird
   protocol bgp isp1 {
       # ... existing config ...
       
       ipv4 {
           import filter {
               # Only accept specific routes
               if net ~ [8.8.8.0/24] then accept;
               reject;
           };
           export where source = RTS_STATIC;
       };
   }
   ```

4. **Reload config**
   ```bash
   docker compose restart bgp-router
   ```

5. **Verify filtering**
   ```bash
   docker compose exec bgp-router birdc show route
   ```

### Expected Results
- Hanya route 8.8.8.0/24 yang di-accept dari ISP1
- Routes 1.1.1.0/24 dan 203.0.113.0/24 di-reject

---

## Skenario 5: Local Preference Manipulation

### Tujuan
Menggunakan Local Preference untuk traffic engineering

### Steps

1. **Check current preferences**
   ```bash
   docker compose exec bgp-router birdc 'show route all where net = 8.8.8.0/24'
   ```

2. **Modify ISP2 local preference**
   Edit `configs/bgp-router/bird.conf`:
   ```bird
   protocol bgp isp2 {
       # ... existing config ...
       
       import filter {
           bgp_local_pref = 120;  # Higher than ISP1 (default 100)
           accept;
       };
   }
   ```

3. **Reload and verify**
   ```bash
   docker compose restart bgp-router
   sleep 20
   docker compose exec bgp-router birdc show route all
   ```

### Expected Results
- Routes dari ISP2 sekarang preferred (local pref 120 > 90)
- Traffic outbound menggunakan ISP2 sebagai primary

---

## Skenario 6: AS Path Prepending

### Tujuan
Menggunakan AS path prepending untuk influence inbound traffic

### Steps

1. **Configure prepending di BGP router**
   Edit `configs/bgp-router/bird.conf`:
   ```bird
   protocol bgp isp1 {
       # ... existing config ...
       
       ipv4 {
           import all;
           export where source = RTS_STATIC {
               bgp_path.prepend(65000);
               bgp_path.prepend(65000);
           };
       };
   }
   ```

2. **Reload config**
   ```bash
   docker compose restart bgp-router
   ```

3. **Verify AS path from ISP perspective**
   ```bash
   docker compose exec isp1 birdc 'show route all where net = 192.168.0.0/16'
   ```

### Expected Results
- AS path to our network via ISP1: 65000 65000 65000
- AS path to our network via ISP2: 65000
- ISP prefer ISP2 path (shorter AS path)

---

## Skenario 7: Monitoring & Troubleshooting

### Tujuan
Learn monitoring tools dan troubleshooting techniques

### Steps

1. **Real-time BGP monitoring**
   ```bash
   # Watch BGP updates
   docker compose exec bgp-router birdc
   # In birdc console:
   show protocols all
   show route all
   ```

2. **Packet capture BGP sessions**
   ```bash
   # Capture BGP traffic
   docker compose exec bgp-router tcpdump -i eth0 -n port 179 -w /tmp/bgp.pcap
   
   # In another terminal, generate some BGP activity
   docker compose restart isp1
   
   # Stop capture and analyze
   docker compose exec bgp-router tcpdump -r /tmp/bgp.pcap -n
   ```

3. **Check BGP FSM states**
   ```bash
   docker compose exec bgp-router birdc show protocols all isp1
   ```

4. **Debug routing issues**
   ```bash
   # From client, trace to ISP
   docker compose exec client traceroute -n 10.1.1.1
   
   # Check each hop's routing
   docker compose exec client ip route get 10.1.1.1
   docker compose exec pfrouter ip route get 10.1.1.1
   docker compose exec bgp-router ip route get 10.1.1.1
   ```

### Tools Used
- birdc (BIRD control interface)
- tcpdump (packet capture)
- traceroute (path tracing)
- ip route (routing table)

---

## Skenario 8: Multi-Path Load Balancing

### Tujuan
Configure ECMP untuk load balancing traffic across multiple ISPs

### Steps

1. **Modify BGP router config untuk ECMP**
   Edit `configs/bgp-router/bird.conf`:
   ```bird
   protocol bgp isp1 {
       # ... existing config ...
       
       ipv4 {
           import all;
           export where source = RTS_STATIC;
           next hop self;
           add paths on;  # Enable multipath
       };
   }
   
   protocol bgp isp2 {
       # ... existing config ...
       
       import filter {
           bgp_local_pref = 100;  # Same as ISP1
           accept;
       };
       
       ipv4 {
           import all;
           export where source = RTS_STATIC;
           next hop self;
           add paths on;  # Enable multipath
       };
   }
   ```

2. **Enable multipath in kernel protocol**
   ```bird
   protocol kernel {
       ipv4 {
           export all;
           import all;
           merge paths yes;  # Enable ECMP
       };
   }
   ```

3. **Reload and verify**
   ```bash
   docker compose restart bgp-router
   docker compose exec bgp-router ip route show
   ```

### Expected Results
- Multiple next hops for same destination
- Traffic distributed across both ISPs

---

## Skenario 9: BGP Communities

### Tujuan
Menggunakan BGP communities untuk traffic classification

### Steps

1. **Configure communities di BGP router**
   Edit `configs/bgp-router/bird.conf`:
   ```bird
   protocol bgp isp1 {
       # ... existing config ...
       
       ipv4 {
           import filter {
               bgp_community.add((65000,100));  # Tag with community
               accept;
           };
           export where source = RTS_STATIC;
       };
   }
   ```

2. **Use communities for filtering**
   ```bird
   protocol bgp isp2 {
       # ... existing config ...
       
       ipv4 {
           import filter {
               if (65000,100) ~ bgp_community then {
                   bgp_local_pref = 90;
               }
               accept;
           };
       };
   }
   ```

3. **Verify community tagging**
   ```bash
   docker compose restart bgp-router
   docker compose exec bgp-router birdc 'show route all'
   ```

---

## Skenario 10: BGP Graceful Shutdown

### Tujuan
Perform maintenance dengan minimal impact

### Steps

1. **Announce graceful shutdown**
   ```bash
   docker compose exec bgp-router birdc disable isp1
   ```

2. **Monitor traffic shift**
   ```bash
   # From client, watch routing changes
   watch -n 1 'docker compose exec client ip route get 8.8.8.8'
   ```

3. **Perform maintenance**
   ```bash
   # Simulate maintenance
   docker compose stop isp1
   sleep 60
   docker compose start isp1
   ```

4. **Restore service**
   ```bash
   docker compose exec bgp-router birdc enable isp1
   ```

### Best Practices Demonstrated
- Drain traffic before maintenance
- Monitor during change window
- Verify restoration

---

## Advanced Exercises

### Exercise 1: Implement Route Reflector
Add a route reflector untuk scale BGP infrastructure

### Exercise 2: BGP Peering over VPN
Setup BGP over secure tunnel

### Exercise 3: BGP with IPv6
Extend setup untuk IPv6 routing

### Exercise 4: Anycast Implementation
Implement anycast untuk service redundancy

### Exercise 5: BGP Security
Add MD5 authentication dan prefix filtering

---

## Kesimpulan

Setelah menyelesaikan scenarios ini, anda akan memahami:
- BGP fundamentals dan operations
- Path selection process
- Traffic engineering techniques
- Troubleshooting methods
- Best practices untuk production

Untuk deep dive, modifikasi scenarios dan experiment dengan parameters berbeda!
