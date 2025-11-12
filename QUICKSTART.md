# Quick Start Guide - BGP Simulator

## Panduan Cepat Memulai

### 1. Prasyarat
Pastikan sudah install:
- Docker Engine
- Docker Compose

### 2. Clone dan Jalankan

```bash
# Clone repository
git clone https://github.com/ardantus/bgp-simulator.git
cd bgp-simulator

# Start semua containers
docker compose up -d

# Tunggu beberapa detik untuk BGP peering establish
sleep 30

# Cek status containers
docker compose ps
```

### 3. Verifikasi BGP Peering

```bash
# Cek BGP status di router utama
docker compose exec bgp-router birdc show protocols

# Output yang diharapkan:
# name     proto    table    state  since         info
# device1  Device   ---      up     04:20:00.000  
# direct1  Direct   ---      up     04:20:00.000  
# kernel1  Kernel   master4  up     04:20:00.000  
# static1  Static   master4  up     04:20:00.000  
# isp1     BGP      ---      up     04:20:05.000  Established   
# isp2     BGP      ---      up     04:20:05.000  Established
```

### 4. Test dari Client

```bash
# Masuk ke client container
docker compose exec client bash

# Di dalam container client:
# Test ping ke ISP1
ping -c 4 10.1.1.1

# Test ping ke ISP2
ping -c 4 10.2.2.1

# Traceroute untuk melihat path
traceroute -n 10.1.1.1
traceroute -n 10.2.2.1

# Keluar dari container
exit
```

### 5. Commands Penting

```bash
# Lihat routing table di BGP router
docker compose exec bgp-router birdc show route

# Lihat detail BGP neighbors
docker compose exec bgp-router birdc show protocols all

# Lihat logs
docker compose logs -f bgp-router
docker compose logs -f isp1
docker compose logs -f isp2

# Restart container tertentu
docker compose restart bgp-router

# Stop semua
docker compose down
```

### 6. Eksperimen Failover

```bash
# Matikan ISP1
docker compose stop isp1

# Cek routing sekarang hanya via ISP2
docker compose exec bgp-router birdc show route

# Nyalakan kembali ISP1
docker compose start isp1

# Cek routing kembali normal
docker compose exec bgp-router birdc show route
```

## Troubleshooting Cepat

### BGP tidak Establish
```bash
# Cek logs untuk error
docker compose logs bgp-router | grep -i error
docker compose logs isp1 | grep -i error

# Cek connectivity
docker compose exec bgp-router ping 10.1.1.1
docker compose exec bgp-router ping 10.2.2.1
```

### Routing tidak bekerja
```bash
# Cek IP forwarding
docker compose exec pfrouter sysctl net.ipv4.ip_forward

# Cek routes
docker compose exec pfrouter ip route show
docker compose exec client ip route show
```

### Container tidak start
```bash
# Rebuild semua images
docker compose down
docker compose build --no-cache
docker compose up -d

# Cek logs
docker compose logs
```

## Network Layout Cepat

```
Client (192.168.200.10)
    ↓
pfRouter (192.168.200.1 / 192.168.100.2)
    ↓
BGP Router (192.168.100.1 / 10.1.1.2 / 10.2.2.2)
    ↓           ↓
ISP1 (10.1.1.1) ISP2 (10.2.2.1)
```

## Learning Path

1. **Pemula**: Jalankan setup → Cek BGP status → Test ping/traceroute
2. **Intermediate**: Simulasi failover → Edit config → Observe routing changes
3. **Advanced**: Custom filtering → AS-path prepending → Traffic engineering

Untuk dokumentasi lengkap, lihat [README.md](README.md)
