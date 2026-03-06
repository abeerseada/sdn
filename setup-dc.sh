#!/bin/bash

# Fat-Tree k=4 OVS Setup
# Reference: Al-Fares et al., ACM SIGCOMM 2008
#
# DPID assignments (derived from bridge MAC):
#   Core : c1=0x0C01  c2=0x0C02  c3=0x0C03  c4=0x0C04
#   Agg  : a01=0x0A01 a02=0x0A02 a11=0x0A03 a12=0x0A04
#          a21=0x0A05 a22=0x0A06 a31=0x0A07 a32=0x0A08
#   Edge : e01=0x0E01 e02=0x0E02 e11=0x0E03 e12=0x0E04
#          e21=0x0E05 e22=0x0E06 e31=0x0E07 e32=0x0E08

CTRL_IP=172.20.20.10
CTRL_PORT=6653
OF_VER=OpenFlow13
FAIL_MODE=secure

CORE="c1 c2 c3 c4"
AGG="a01 a02 a11 a12 a21 a22 a31 a32"
EDGE="e01 e02 e11 e12 e21 e22 e31 e32"
ALL="$CORE $AGG $EDGE"

echo "=== Creating OVS bridges ==="
for sw in $ALL; do
    ovs-vsctl --may-exist add-br $sw
done

echo "=== Setting MAC addresses (DPIDs) ==="
# Core layer
ovs-vsctl set bridge c1 other-config:hwaddr=00:00:00:00:0c:01
ovs-vsctl set bridge c2 other-config:hwaddr=00:00:00:00:0c:02
ovs-vsctl set bridge c3 other-config:hwaddr=00:00:00:00:0c:03
ovs-vsctl set bridge c4 other-config:hwaddr=00:00:00:00:0c:04

# Aggregation layer
ovs-vsctl set bridge a01 other-config:hwaddr=00:00:00:00:0a:01
ovs-vsctl set bridge a02 other-config:hwaddr=00:00:00:00:0a:02
ovs-vsctl set bridge a11 other-config:hwaddr=00:00:00:00:0a:03
ovs-vsctl set bridge a12 other-config:hwaddr=00:00:00:00:0a:04
ovs-vsctl set bridge a21 other-config:hwaddr=00:00:00:00:0a:05
ovs-vsctl set bridge a22 other-config:hwaddr=00:00:00:00:0a:06
ovs-vsctl set bridge a31 other-config:hwaddr=00:00:00:00:0a:07
ovs-vsctl set bridge a32 other-config:hwaddr=00:00:00:00:0a:08

# Edge layer
ovs-vsctl set bridge e01 other-config:hwaddr=00:00:00:00:0e:01
ovs-vsctl set bridge e02 other-config:hwaddr=00:00:00:00:0e:02
ovs-vsctl set bridge e11 other-config:hwaddr=00:00:00:00:0e:03
ovs-vsctl set bridge e12 other-config:hwaddr=00:00:00:00:0e:04
ovs-vsctl set bridge e21 other-config:hwaddr=00:00:00:00:0e:05
ovs-vsctl set bridge e22 other-config:hwaddr=00:00:00:00:0e:06
ovs-vsctl set bridge e31 other-config:hwaddr=00:00:00:00:0e:07
ovs-vsctl set bridge e32 other-config:hwaddr=00:00:00:00:0e:08

echo "=== Setting OpenFlow options ==="
for sw in $ALL; do
    ovs-vsctl set bridge $sw fail_mode=$FAIL_MODE
    ovs-vsctl set bridge $sw protocols=$OF_VER
    ovs-vsctl set-controller $sw tcp:$CTRL_IP:$CTRL_PORT
done

echo "=== Done ==="
