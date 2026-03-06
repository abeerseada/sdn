# SDN Fat-Tree Data Center Network

A Software-Defined Networking (SDN) implementation of a **Fat-Tree k=4** data center topology using Open vSwitch (OVS), ContainerLab, and the Ryu SDN controller. Deployed automatically via Jenkins CI/CD on every push.

> Reference: Al-Fares et al., *"A Scalable, Commodity Data Center Network Architecture"*, ACM SIGCOMM 2008.

---

## Topology

```
                    ┌────┐  ┌────┐  ┌────┐  ┌────┐
     CORE LAYER     │ c1 │  │ c2 │  │ c3 │  │ c4 │
                    └─┬──┘  └──┬─┘  └──┬─┘  └──┬─┘
          ┌──────────────────────────────────────────┐
          │           AGGREGATION LAYER              │
          │  Pod 0: a01 a02 | Pod 1: a11 a12        │
          │  Pod 2: a21 a22 | Pod 3: a31 a32        │
          └──────────────────────────────────────────┘
          ┌──────────────────────────────────────────┐
          │              EDGE LAYER                  │
          │  Pod 0: e01 e02 | Pod 1: e11 e12        │
          │  Pod 2: e21 e22 | Pod 3: e31 e32        │
          └──────────────────────────────────────────┘
          ┌──────────────────────────────────────────┐
          │                 HOSTS                    │
          │  Pod 0: h011 h012 h021 h022              │
          │  Pod 1: h111 h112 h121 h122              │
          │  Pod 2: h211 h212 h221 h222              │
          │  Pod 3: h311 h312 h321 h322              │
          └──────────────────────────────────────────┘

                    ┌──────────────────┐
                    │  Ryu Controller  │  OpenFlow 1.3
                    │  FlowManager UI  │  :8081/home/index.html
                    └──────────────────┘
```

| Layer | Count | Nodes |
|---|---|---|
| Core | 4 switches | c1, c2, c3, c4 |
| Aggregation | 8 switches | a01–a02, a11–a12, a21–a22, a31–a32 |
| Edge | 8 switches | e01–e02, e11–e12, e21–e22, e31–e32 |
| Hosts | 16 hosts | h011–h322 (4 per pod) |
| **Total** | **48 links** | Full bisection bandwidth |

---

## IP Addressing

IP scheme: `10.<pod>.<rack>.<host>/24`

| Pod | Edge Switch | Subnet | Hosts |
|---|---|---|---|
| 0 | e01 | 10.0.1.0/24 | h011 (10.0.1.1), h012 (10.0.1.2) |
| 0 | e02 | 10.0.2.0/24 | h021 (10.0.2.1), h022 (10.0.2.2) |
| 1 | e11 | 10.1.1.0/24 | h111 (10.1.1.1), h112 (10.1.1.2) |
| 1 | e12 | 10.1.2.0/24 | h121 (10.1.2.1), h122 (10.1.2.2) |
| 2 | e21 | 10.2.1.0/24 | h211 (10.2.1.1), h212 (10.2.1.2) |
| 2 | e22 | 10.2.2.0/24 | h221 (10.2.2.1), h222 (10.2.2.2) |
| 3 | e31 | 10.3.1.0/24 | h311 (10.3.1.1), h312 (10.3.1.2) |
| 3 | e32 | 10.3.2.0/24 | h321 (10.3.2.1), h322 (10.3.2.2) |

---

## OpenFlow DPID Mapping

| Layer | Switch | DPID |
|---|---|---|
| Core | c1 | `0x0C01` |
| Core | c2 | `0x0C02` |
| Core | c3 | `0x0C03` |
| Core | c4 | `0x0C04` |
| Agg | a01 | `0x0A01` |
| Agg | a02 | `0x0A02` |
| Agg | a11 | `0x0A03` |
| Agg | a12 | `0x0A04` |
| Agg | a21 | `0x0A05` |
| Agg | a22 | `0x0A06` |
| Agg | a31 | `0x0A07` |
| Agg | a32 | `0x0A08` |
| Edge | e01 | `0x0E01` |
| Edge | e02 | `0x0E02` |
| Edge | e11 | `0x0E03` |
| Edge | e12 | `0x0E04` |
| Edge | e21 | `0x0E05` |
| Edge | e22 | `0x0E06` |
| Edge | e31 | `0x0E07` |
| Edge | e32 | `0x0E08` |

---

## Port Layout

| Switch Type | Port 1 | Port 2 | Port 3 | Port 4 |
|---|---|---|---|---|
| Core (c1, c2) | Pod-0 agg | Pod-1 agg | Pod-2 agg | Pod-3 agg |
| Core (c3, c4) | Pod-0 agg | Pod-1 agg | Pod-2 agg | Pod-3 agg |
| Aggregation | Core-left | Core-right | Edge-0 | Edge-1 |
| Edge | Agg-0 | Agg-1 | Host-0 | Host-1 |

---

## Repository Structure

```
sdn/
├── sdn-dcn.clab.yml       # ContainerLab topology definition
├── setup-dc.sh            # Creates 20 OVS bridges, sets DPIDs and controller
├── reset-dc.sh            # Tears down all OVS bridges
├── num-ports.sh           # Configures OpenFlow port numbering on all switches
├── config/
│   ├── fat_tree.py        # Ryu ECMP routing application (Fat-Tree aware)
│   └── base_switch.py     # Base class with core flow management utilities
├── Jenkinsfile            # CI/CD pipeline (auto-triggered on git push)
└── README.md
```

---

## SDN Controller

The topology uses the **Ryu** SDN framework with a custom **Fat-Tree ECMP** application.

- **Image**: `martimy/ryu-flowmanager:latest`
- **Controller address**: `172.20.20.10:6653`
- **Protocol**: OpenFlow 1.3
- **Fail mode**: `secure` (traffic dropped if controller is unreachable)
- **UI**: `http://<host-ip>:8081/home/index.html`

### Routing Logic (fat_tree.py)

- **Same pod** (3 hops): `edge → agg → edge`
- **Cross pod** (5 hops): `edge → agg → core → agg → edge`
- **ECMP path selection**: `hash(src_mac + dst_mac)` to distribute flows across equal-cost paths
- **Flow installation**: bidirectional flows installed on every switch along the path
- **Idle timeout**: 30 seconds per flow

---

## CI/CD Pipeline

Every `git push` to this repository automatically triggers the Jenkins pipeline:

```
Clone / Update Repo
        │
        ▼
Reset Previous Deployment   (clab destroy + reset-dc.sh)
        │
        ▼
Create OVS Bridges          (setup-dc.sh — 20 bridges)
        │
        ▼
Deploy ContainerLab         (clab deploy -t sdn-dcn.clab.yml)
        │
        ▼
Configure OVS Switches      (num-ports.sh — OpenFlow port numbering)
        │
        ▼
Verify Deployment           (clab inspect + ovs-vsctl show)
```

---

## Manual Deployment

### Requirements

- Open vSwitch (`openvswitch-switch`)
- ContainerLab
- Docker

### Deploy

```bash
# 1. Create OVS bridges and connect to controller
sudo bash setup-dc.sh

# 2. Deploy topology (starts Ryu controller + all hosts)
sudo clab deploy -t sdn-dcn.clab.yml

# 3. Set OpenFlow port numbers
sudo bash num-ports.sh
```

### Teardown

```bash
sudo clab destroy -t sdn-dcn.clab.yml --cleanup
sudo bash reset-dc.sh
```

### Verify

```bash
# Check ContainerLab nodes
sudo clab inspect -t sdn-dcn.clab.yml

# Check OVS bridges and controller connections
sudo ovs-vsctl show

# Test connectivity between hosts
sudo docker exec clab-fat-tree-k4-h011 ping 10.3.2.2
```

---

## Infrastructure Repository

The AWS cloud infrastructure (Terraform, Ansible, Jenkins, Monitoring) lives in the companion repo:

**IT-GP**: [https://github.com/abeerseada/IT-GP](https://github.com/abeerseada/IT-GP)
