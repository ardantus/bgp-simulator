# BGP Simulator dengan Docker Compose

Project ini adalah simulator BIRD BGP router menggunakan Docker Compose untuk pembelajaran routing BGP. Setup ini mensimulasikan koneksi ke 2 ISP berbeda dengan ASN yang berbeda.

## Topologi Jaringan

```
                    Internet
                       |
        +-------------+--------------+
        |                            |
    ISP1 (AS65001)              ISP2 (AS65002)
        |                            |
        +-------------+--------------+
                       |
                  BGP Router
                 (AS65000 - BIRD)
                       |
                  pfRouter Linux
                       |
                  Ubuntu Client
              (dengan traceroute)
```

## Komponen

### 1. BGP Router (BIRD)
- **ASN**: 65000 (Private ASN)
- **Software**: BIRD BGP daemon
- **Fungsi**: Mengelola routing BGP dan koneksi ke 2 ISP
- **Koneksi**:
  - ISP1: AS65001 (upstream provider 1)
  - ISP2: AS65002 (upstream provider 2)

### 2. ISP Simulators
- **ISP1**: AS65001
- **ISP2**: AS65002
- **Fungsi**: Mensimulasikan BGP peers eksternal

### 3. pfRouter Linux
- **Fungsi**: Layer routing Linux di bawah BGP router
- **Kemampuan**: Packet forwarding, NAT, firewall

### 4. Ubuntu Client
- **Fungsi**: Container untuk testing dan troubleshooting
- **Tools**: traceroute, ping, curl, netstat, ip tools

## Documentation

- **[QUICKSTART.md](QUICKSTART.md)**: Panduan cepat untuk memulai
- **[SCENARIOS.md](SCENARIOS.md)**: 10+ skenario pembelajaran BGP dengan contoh lengkap
- **[TESTING.md](TESTING.md)**: Panduan testing dan verifikasi lengkap
- **[TOPOLOGY.md](TOPOLOGY.md)**: Diagram dan penjelasan topologi jaringan detail

## Prerequisites

- Docker Engine (versi 20.10 atau lebih baru)
- Docker Compose (versi 1.29 atau lebih baru)
- Minimal 2GB RAM free
- Koneksi internet untuk download images

## Instalasi dan Menjalankan

### 1. Clone Repository

```bash
git clone https://github.com/ardantus/bgp-simulator.git
cd bgp-simulator
```

### 2. Build dan Start Containers

```bash
# Build dan jalankan semua containers
docker-compose up -d

# Cek status containers
docker-compose ps
```

### 3. Verifikasi Setup

```bash
# Cek logs BGP router
docker-compose logs -f bgp-router

# Cek logs ISP1
docker-compose logs -f isp1

# Cek logs ISP2
docker-compose logs -f isp2
```

## Cara Menggunakan

### Koneksi ke Container

#### 1. BGP Router
```bash
# Masuk ke BGP router
docker-compose exec bgp-router /bin/bash

# Cek status BIRD
birdc show status

# Cek BGP protocols
birdc show protocols

# Cek routing table
birdc show route

# Cek BGP neighbors
birdc show protocols all
```

#### 2. ISP1 Router
```bash
# Masuk ke ISP1
docker-compose exec isp1 /bin/bash

# Cek status BIRD
birdc show status

# Cek routing table
birdc show route
```

#### 3. ISP2 Router
```bash
# Masuk ke ISP2
docker-compose exec isp2 /bin/bash

# Cek status BIRD
birdc show status

# Cek routing table
birdc show route
```

#### 4. pfRouter
```bash
# Masuk ke pfRouter
docker-compose exec pfrouter /bin/bash

# Cek routing table
ip route show

# Cek network interfaces
ip addr show

# Cek forwarding status
sysctl net.ipv4.ip_forward
```

#### 5. Ubuntu Client
```bash
# Masuk ke client
docker-compose exec client /bin/bash

# Test connectivity dengan traceroute
traceroute 8.8.8.8

# Test ping
ping -c 4 8.8.8.8

# Cek routing
ip route show

# Cek network interfaces
ip addr show
```

## Testing dan Troubleshooting

### 1. Cek BGP Peering

```bash
# Dari BGP router
docker-compose exec bgp-router birdc show protocols all

# Output yang diharapkan:
# - Koneksi ke ISP1 (AS65001) status: Established
# - Koneksi ke ISP2 (AS65002) status: Established
```

### 2. Test Routing Path

```bash
# Dari Ubuntu client
docker-compose exec client traceroute -n 8.8.8.8

# Atau traceroute ke IP ISP tertentu
docker-compose exec client traceroute -n 10.1.1.1  # ISP1
docker-compose exec client traceroute -n 10.2.2.1  # ISP2
```

### 3. Simulasi BGP Path Preference

```bash
# Matikan BGP session ke ISP1
docker-compose exec bgp-router birdc disable isp1

# Cek routing sekarang menggunakan ISP2
docker-compose exec bgp-router birdc show route

# Nyalakan kembali
docker-compose exec bgp-router birdc enable isp1
```

### 4. Monitor BGP Updates

```bash
# Live monitoring BGP updates
docker-compose exec bgp-router birdc
> show route all
> show protocols all
> exit
```

### 5. Packet Capture

```bash
# Capture BGP packets di BGP router
docker-compose exec bgp-router tcpdump -i eth0 -n port 179

# Capture semua packets di client
docker-compose exec client tcpdump -i eth0 -n
```

## Konfigurasi Network

### IP Addressing

| Container | Interface | IP Address | Network |
|-----------|-----------|------------|---------|
| ISP1 | eth0 | 10.1.1.1/24 | ISP1 Network |
| ISP2 | eth0 | 10.2.2.1/24 | ISP2 Network |
| BGP Router | eth0 (ISP1) | 10.1.1.2/24 | ISP1 Network |
| BGP Router | eth1 (ISP2) | 10.2.2.2/24 | ISP2 Network |
| BGP Router | eth2 (Internal) | 192.168.100.1/24 | Internal Network |
| pfRouter | eth0 | 192.168.100.2/24 | Internal Network |
| pfRouter | eth1 | 192.168.200.1/24 | Client Network |
| Client | eth0 | 192.168.200.10/24 | Client Network |

### ASN Configuration

- **AS65000**: BGP Router (Your network)
- **AS65001**: ISP1 (Upstream provider 1)
- **AS65002**: ISP2 (Upstream provider 2)

## Struktur File

```
bgp-simulator/
├── docker-compose.yml          # Docker Compose configuration
├── README.md                   # Dokumentasi ini
├── configs/
│   ├── bgp-router/
│   │   └── bird.conf          # BIRD config untuk BGP router
│   ├── isp1/
│   │   └── bird.conf          # BIRD config untuk ISP1
│   ├── isp2/
│   │   └── bird.conf          # BIRD config untuk ISP2
│   └── pfrouter/
│       └── routing.sh         # Script routing untuk pfRouter
└── Dockerfile.bird            # Custom Dockerfile untuk BIRD
```

## Pembelajaran BGP

### Konsep yang Bisa Dipelajari

1. **BGP Peering**: Cara setup BGP neighbors
2. **Route Advertisement**: Cara advertise network ke BGP peers
3. **Path Selection**: Cara BGP memilih best path
4. **AS Path**: Memahami AS path attribute
5. **Local Preference**: Mengatur preferensi routing
6. **MED (Multi-Exit Discriminator)**: Traffic engineering
7. **Failover**: Simulasi link failure dan BGP convergence
8. **Route Filtering**: Import/export filtering

### Eksperimen yang Bisa Dilakukan

1. **Failover Testing**
   ```bash
   # Matikan ISP1
   docker-compose stop isp1
   # Observe routing changes
   docker-compose exec bgp-router birdc show route
   ```

2. **Path Manipulation**
   - Edit BIRD config untuk mengubah local preference
   - Restart BIRD dan observe perubahan routing

3. **Traffic Engineering**
   - Gunakan AS path prepending
   - Gunakan communities untuk traffic control

4. **Route Filtering**
   - Implementasi prefix-list
   - Implementasi AS-path filtering

## Commands Berguna

### Docker Compose Commands

```bash
# Start semua containers
docker-compose up -d

# Stop semua containers
docker-compose down

# Restart container tertentu
docker-compose restart bgp-router

# Rebuild containers
docker-compose up -d --build

# Lihat logs
docker-compose logs -f [container-name]

# Stop sementara container
docker-compose stop [container-name]

# Start container yang di-stop
docker-compose start [container-name]
```

### BIRD Commands

```bash
# Status BIRD daemon
birdc show status

# Protokol BGP
birdc show protocols
birdc show protocols all

# Routing table
birdc show route
birdc show route all
birdc show route where bgp_path ~ [= * 65001 * =]  # Routes via ISP1

# Enable/disable protocol
birdc enable isp1
birdc disable isp1

# Reload config
birdc configure
birdc configure check  # Check syntax saja
```

### Linux Networking Commands

```bash
# Routing table
ip route show
route -n

# Network interfaces
ip addr show
ip link show

# Test connectivity
ping 8.8.8.8
traceroute 8.8.8.8

# Network statistics
netstat -rn
ss -s

# Packet capture
tcpdump -i eth0 -n
tcpdump -i eth0 -n port 179  # BGP packets only
```

## Troubleshooting

### BGP Peering Tidak Establish

1. Cek IP connectivity:
   ```bash
   docker-compose exec bgp-router ping 10.1.1.1  # ISP1
   docker-compose exec bgp-router ping 10.2.2.1  # ISP2
   ```

2. Cek BIRD logs:
   ```bash
   docker-compose logs bgp-router
   ```

3. Cek BIRD config syntax:
   ```bash
   docker-compose exec bgp-router bird -p
   ```

### Routing Tidak Bekerja

1. Cek IP forwarding enabled:
   ```bash
   docker-compose exec pfrouter sysctl net.ipv4.ip_forward
   ```

2. Cek routing table:
   ```bash
   docker-compose exec pfrouter ip route show
   docker-compose exec client ip route show
   ```

3. Cek firewall rules:
   ```bash
   docker-compose exec pfrouter iptables -L -n -v
   ```

### Container Tidak Start

1. Cek logs:
   ```bash
   docker-compose logs [container-name]
   ```

2. Cek resource usage:
   ```bash
   docker stats
   ```

3. Rebuild containers:
   ```bash
   docker-compose down
   docker-compose up -d --build
   ```

## Security Notes

⚠️ **PERHATIAN**: Setup ini untuk pembelajaran saja, JANGAN digunakan di production!

- Semua ASN menggunakan private ASN range (64512-65534)
- Tidak ada authentication pada BGP peering
- Tidak ada firewall rules yang strict
- Semua passwords default

## Kontribusi

Contributions are welcome! Please feel free to submit a Pull Request.

## Lisensi

Lihat file [LICENSE](LICENSE) untuk detail.

## Resources

### BIRD Documentation
- [BIRD Official Documentation](https://bird.network.cz/)
- [BIRD User's Guide](https://bird.network.cz/?get_doc&v=20&f=bird.html)

### BGP Learning Resources
- [BGP Fundamentals](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/26634-bgp-toc.html)
- [BGP Best Practices](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/13753-25.html)

### Docker Networking
- [Docker Networking Overview](https://docs.docker.com/network/)
- [Docker Compose Networking](https://docs.docker.com/compose/networking/)

## Support

Jika ada pertanyaan atau issue, silakan buat issue di GitHub repository ini.

## Changelog

### v1.0.0 (Initial Release)
- Setup dasar BGP simulator dengan 2 ISP
- BIRD BGP router configuration
- pfRouter Linux untuk packet forwarding
- Ubuntu client dengan networking tools
- Dokumentasi lengkap dalam bahasa Indonesia
