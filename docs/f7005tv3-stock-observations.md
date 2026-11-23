# F7005TV3 stock observations (2026-11-23)

LAN1 remained connected to the PPPoE router throughout. With a second live cable moved between jacks, stock eth0–eth3 carrier values were:

| Test cable | eth0 | eth1 | eth2 | eth3 |
|---|---:|---:|---:|---:|
| None | 1 | 0 | 0 | 0 |
| LAN2 | 1 | 1 | 0 | 0 |
| LAN3 | 1 | 0 | 1 | 0 |
| LAN4 | 1 | 0 | 0 | 1 |

LAN2–4 correspond to stock eth1–3. LAN1/eth0 is inferred by exclusion. These measurements do not identify mainline switch port numbers, PHY addresses or negotiated speed.

The stock FDT exposes no /reserved-memory node. Its reservation map at offset 0x28 contains only the 16-byte zero terminator. The stock iomem map reserves 0x989f4000–0x9fffffff, encompassing the trial DTS's proposed BMU, IDM and SE regions without establishing their individual boundaries or ownership. The bmu_ddr_mem node exposes only name. Keep the trial carve-outs provisional.
