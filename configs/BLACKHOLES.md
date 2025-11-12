This file documents the static `blackhole` routes present in the ISP configuration files.

Purpose
-------
The `blackhole` static routes in `configs/isp1/bird.conf` and `configs/isp2/bird.conf` are provided as simulation helpers. When enabled, they instruct the ISP container's routing table to drop traffic for the specified prefixes (useful to simulate upstream filtering, DDoS blackholing, or network partitions).

How to enable a blackhole
-------------------------
1. Edit the respective ISP config (`configs/isp1/bird.conf` or `configs/isp2/bird.conf`).
2. Uncomment the `route <prefix> blackhole;` line(s) you want to enable.
3. Restart the ISP container so BIRD reloads the config and installs the kernel route(s):

   ```bash
   docker compose restart isp1   # or isp2
   ```

Notes and caveats
-----------------
- Enabling a blackhole will cause the ISP to drop traffic destined to the blackholed prefix. This may make client traffic fail to reach those destinations until the blackhole is removed.
- If BIRD is configured to export static routes via BGP (as in the supplied configs), enabling blackholes can also cause those prefixes to be announced to neighbors as unreachable or installed as blackholes locally.
- To temporarily test without editing configs, you can remove or add the kernel blackhole route directly (non-persistent):

  ```bash
  docker compose exec isp1 ip route add blackhole 1.1.1.0/24
  docker compose exec isp1 ip route del blackhole 1.1.1.0/24
  ```

- After changing the config, monitor routes with:

  ```bash
  docker compose exec isp1 birdc show route  # or isp2
  docker compose exec isp1 ip -4 route        # or isp2
  ```

