"""
Fat-Tree k=4 SDN Controller Application
Reference: Al-Fares et al., "A Scalable, Commodity Data Center Network
           Architecture", ACM SIGCOMM 2008.

Topology (k=4):
  - 4  core switches       DPID 0x0C01 – 0x0C04
  - 8  aggregation switches DPID 0x0A01 – 0x0A08  (2 per pod)
  - 8  edge switches        DPID 0x0E01 – 0x0E08  (2 per pod)
  - 16 hosts                10.pod.rack.host/24

Port layout:
  Core  : port 1-4 → one aggregation switch per pod
  Agg   : port 1-2 → core  |  port 3-4 → edge
  Edge  : port 1-2 → agg   |  port 3-4 → hosts
"""

from ryu.controller import ofp_event
from ryu.controller.handler import CONFIG_DISPATCHER, MAIN_DISPATCHER
from ryu.controller.handler import set_ev_cls
from ryu.ofproto import ofproto_v1_3
from ryu.lib.packet import packet, ethernet, ether_types
from ryu.app.ofctl.api import get_datapath
from base_switch import BaseSwitch

TABLE0      = 0
MIN_PRI     = 0
MID_PRI     = 500
IDLE_TIME   = 30


# ─────────────────────────────────────────────────────────────
# Topology definition
# ─────────────────────────────────────────────────────────────

class FatTreeNetwork:
    """
    Static description of the Fat-Tree k=4 topology.

    DPIDs are derived from the bridge MAC set in setup-dc.sh:
      MAC 00:00:00:00:XX:YY  →  DPID = 0xXXYY

    Port numbering (set by num-ports.sh):
      Core  c1,c2  : port 1=pod0-agg0, 2=pod1-agg0, 3=pod2-agg0, 4=pod3-agg0
      Core  c3,c4  : port 1=pod0-agg1, 2=pod1-agg1, 3=pod2-agg1, 4=pod3-agg1
      Agg   aXY    : port 1=c_left,    2=c_right,   3=edge0,      4=edge1
      Edge  eXY    : port 1=agg0,      2=agg1,      3=host0,      4=host1
    """

    # ── DPIDs ────────────────────────────────────────────────
    CORE  = [0x0C01, 0x0C02, 0x0C03, 0x0C04]

    # agg_by_pod[p] = [first_agg_dpid, second_agg_dpid]
    AGG_BY_POD = {
        0: [0x0A01, 0x0A02],
        1: [0x0A03, 0x0A04],
        2: [0x0A05, 0x0A06],
        3: [0x0A07, 0x0A08],
    }

    # edge_by_pod[p] = [first_edge_dpid, second_edge_dpid]
    EDGE_BY_POD = {
        0: [0x0E01, 0x0E02],
        1: [0x0E03, 0x0E04],
        2: [0x0E05, 0x0E06],
        3: [0x0E07, 0x0E08],
    }

    def __init__(self):
        # Flat sets for membership checks
        self.core_set  = set(self.CORE)
        self.agg_set   = {d for ds in self.AGG_BY_POD.values()  for d in ds}
        self.edge_set  = {d for ds in self.EDGE_BY_POD.values() for d in ds}
        self.all_edges = [d for ds in self.EDGE_BY_POD.values() for d in ds]

        # Reverse: dpid → pod number
        self.agg_pod  = {d: p for p, ds in self.AGG_BY_POD.items()  for d in ds}
        self.edge_pod = {d: p for p, ds in self.EDGE_BY_POD.items() for d in ds}

        # Port table: links[(src, dst)] = out_port_on_src
        self.links = self._build_links()

    def _build_links(self):
        L = {}

        # Core c1,c2 connect to first agg in every pod (ports 1-4)
        for core in [0x0C01, 0x0C02]:
            for pod in range(4):
                agg = self.AGG_BY_POD[pod][0]
                L[(core, agg)] = pod + 1          # port 1..4

        # Core c3,c4 connect to second agg in every pod (ports 1-4)
        for core in [0x0C03, 0x0C04]:
            for pod in range(4):
                agg = self.AGG_BY_POD[pod][1]
                L[(core, agg)] = pod + 1

        # Agg → core uplinks (port 1 = c1/c3, port 2 = c2/c4)
        for pod in range(4):
            agg0, agg1 = self.AGG_BY_POD[pod]
            L[(agg0, 0x0C01)] = 1;  L[(agg0, 0x0C02)] = 2
            L[(agg1, 0x0C03)] = 1;  L[(agg1, 0x0C04)] = 2

        # Agg → edge downlinks (port 3 = first edge, port 4 = second edge)
        for pod in range(4):
            for ai, agg in enumerate(self.AGG_BY_POD[pod]):
                for ei, edge in enumerate(self.EDGE_BY_POD[pod]):
                    L[(agg, edge)] = 3 + ei       # port 3 or 4

        # Edge → agg uplinks (port 1 = first agg, port 2 = second agg)
        for pod in range(4):
            for ei, edge in enumerate(self.EDGE_BY_POD[pod]):
                for ai, agg in enumerate(self.AGG_BY_POD[pod]):
                    L[(edge, agg)] = 1 + ai       # port 1 or 2

        return L

    def get_path(self, src_dpid, dst_dpid, flow_hash):
        """
        Compute an ECMP path from src_edge to dst_edge.
        Returns a list of (switch_dpid, out_port) tuples for every hop
        up to (but not including) the final host port.
        """
        src_pod = self.edge_pod[src_dpid]
        dst_pod = self.edge_pod[dst_dpid]
        path = []

        if src_pod == dst_pod:
            # Same pod: edge → agg → edge  (3 switches)
            agg_idx = flow_hash % 2
            agg     = self.AGG_BY_POD[src_pod][agg_idx]
            path.append((src_dpid, self.links[(src_dpid, agg)]))
            path.append((agg,      self.links[(agg, dst_dpid)]))
        else:
            # Cross-pod: edge → agg → core → agg → edge  (5 switches)
            agg_idx  = flow_hash % 2
            src_agg  = self.AGG_BY_POD[src_pod][agg_idx]

            # c1,c2 serve agg[p][0]; c3,c4 serve agg[p][1]
            if agg_idx == 0:
                core_candidates = [0x0C01, 0x0C02]
            else:
                core_candidates = [0x0C03, 0x0C04]
            core    = core_candidates[(flow_hash >> 1) % 2]
            dst_agg = self.AGG_BY_POD[dst_pod][agg_idx]

            path.append((src_dpid, self.links[(src_dpid, src_agg)]))
            path.append((src_agg,  self.links[(src_agg,  core)]))
            path.append((core,     self.links[(core,     dst_agg)]))
            path.append((dst_agg,  self.links[(dst_agg,  dst_dpid)]))

        return path


net = FatTreeNetwork()


# ─────────────────────────────────────────────────────────────
# Ryu Application
# ─────────────────────────────────────────────────────────────

class FatTreeSwitch(BaseSwitch):
    """
    Fat-Tree k=4 SDN controller with ECMP-style flow installation.

    For each new flow:
      - Flood to all edge switches when destination is unknown.
      - On destination discovery, install bidirectional flows along
        the chosen path through all intermediate switches.
    """

    OFP_VERSIONS = [ofproto_v1_3.OFP_VERSION]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.mac_table = {}   # MAC → {'dpid': X, 'port': Y}
        self.ignore    = [ether_types.ETH_TYPE_LLDP, ether_types.ETH_TYPE_IPV6]

    # ── Switch handshake ─────────────────────────────────────

    @set_ev_cls(ofp_event.EventOFPSwitchFeatures, CONFIG_DISPATCHER)
    def switch_features_handler(self, ev):
        dp      = ev.msg.datapath
        ofproto = dp.ofproto
        parser  = dp.ofproto_parser

        msgs = [self.del_flow(dp)]

        if dp.id in net.edge_set:
            # Edge switches send unknown packets to controller
            match = parser.OFPMatch()
            actions = [parser.OFPActionOutput(ofproto.OFPP_CONTROLLER,
                                              ofproto.OFPCML_NO_BUFFER)]
            inst  = [parser.OFPInstructionActions(ofproto.OFPIT_APPLY_ACTIONS, actions)]
            msgs += [self.add_flow(dp, TABLE0, MIN_PRI, match, inst)]
        else:
            # Core and aggregation: drop unknown by default (secure mode)
            match = parser.OFPMatch()
            msgs += [self.add_flow(dp, TABLE0, MIN_PRI, match, [])]

        self.send_messages(dp, msgs)

    # ── Packet-in handler ────────────────────────────────────

    @set_ev_cls(ofp_event.EventOFPPacketIn, MAIN_DISPATCHER)
    def packet_in_handler(self, ev):
        dp      = ev.msg.datapath
        ofproto = dp.ofproto
        in_port = ev.msg.match['in_port']

        pkt = packet.Packet(ev.msg.data)
        eth = pkt.get_protocol(ethernet.ethernet)

        if eth.ethertype in self.ignore:
            return

        dst, src = eth.dst, eth.src
        self.logger.debug("Packet-in dpid=%016x src=%s dst=%s port=%s",
                          dp.id, src, dst, in_port)

        # Learn source MAC
        self.mac_table[src] = {'dpid': dp.id, 'port': in_port}

        dst_info = self.mac_table.get(dst)

        if dst_info is None:
            # Unknown destination — flood to all edge switches
            for edge_dpid in net.all_edges:
                edp      = get_datapath(self, edge_dpid)
                flood_in = in_port if dp.id == edge_dpid else ofproto.OFPP_CONTROLLER
                self.send_messages(edp,
                    self._packet_out(edp, ev.msg.data, flood_in, ofproto.OFPP_ALL))
            return

        dst_dpid = dst_info['dpid']
        dst_port = dst_info['port']

        if dst_dpid == dp.id:
            # Same edge switch
            self._install_bidir(dp, src, dst, in_port, dst_port)
            self.send_messages(dp,
                self._packet_out(dp, ev.msg.data, in_port, dst_port))
        else:
            # Different edge switches — install flows along entire path
            flow_hash = hash(src + dst) & 0xFFFF
            path      = net.get_path(dp.id, dst_dpid, flow_hash)

            # Walk the path: each entry is (sw, out_port_toward_dst)
            # We need the corresponding in_port for each switch.
            prev_dpid  = dp.id
            prev_port  = in_port   # ingress port on source edge

            for (sw_dpid, out_port) in path:
                sw_dp = get_datapath(self, sw_dpid)
                # The in_port on this switch is the port facing prev_dpid
                sw_in = net.links.get((sw_dpid, prev_dpid), ofproto.OFPP_CONTROLLER)
                self._install_bidir(sw_dp, src, dst, sw_in, out_port)
                prev_dpid = sw_dpid
                prev_port = out_port

            # Install flows on destination edge switch
            dst_dp   = get_datapath(self, dst_dpid)
            dst_in   = net.links.get((dst_dpid, prev_dpid), ofproto.OFPP_CONTROLLER)
            self._install_bidir(dst_dp, src, dst, dst_in, dst_port)

            # Deliver the original packet to the destination
            self.send_messages(dst_dp,
                self._packet_out(dst_dp, ev.msg.data,
                                 ofproto.OFPP_CONTROLLER, dst_port))

    # ── Helpers ──────────────────────────────────────────────

    def _install_bidir(self, dp, src, dst, in_port, out_port):
        """Install bidirectional flow entries on a switch."""
        parser  = dp.ofproto_parser
        ofproto = dp.ofproto

        for (s, d, ip, op) in [(src, dst, in_port, out_port),
                                (dst, src, out_port, in_port)]:
            match = parser.OFPMatch(in_port=ip, eth_src=s, eth_dst=d)
            actions = [parser.OFPActionOutput(op)]
            inst    = [parser.OFPInstructionActions(ofproto.OFPIT_APPLY_ACTIONS, actions)]
            self.send_messages(dp,
                [self.add_flow(dp, TABLE0, MID_PRI, match, inst, i_time=IDLE_TIME)])

    def _packet_out(self, dp, data, in_port, out_port):
        """Build a PACKET_OUT message."""
        ofproto = dp.ofproto
        parser  = dp.ofproto_parser
        return [parser.OFPPacketOut(
            datapath=dp,
            buffer_id=ofproto.OFP_NO_BUFFER,
            in_port=in_port,
            actions=[parser.OFPActionOutput(out_port)],
            data=data
        )]
