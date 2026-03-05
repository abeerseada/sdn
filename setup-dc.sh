#!/bin/bash

# Global Settings
SPINE1=spine1
SPINE2=spine2
SPINE3=spine3
LEAF1=leaf1
LEAF2=leaf2
LEAF3=leaf3
LEAF4=leaf4

IP_CTRL=172.10.10.10
IP_PORT=6653

OF_VER=OpenFlow13
FAIL_MODE=secure

SFLOW=172.10.10.100

echo "=== Create switches ==="
ovs-vsctl --may-exist add-br $SPINE1
ovs-vsctl --may-exist add-br $SPINE2
ovs-vsctl --may-exist add-br $SPINE3
ovs-vsctl --may-exist add-br $LEAF1
ovs-vsctl --may-exist add-br $LEAF2
ovs-vsctl --may-exist add-br $LEAF3
ovs-vsctl --may-exist add-br $LEAF4

echo "=== Set MAC addresses (determines OpenFlow DPID) ==="
# spine1=0x0B=11, spine2=0x0C=12, spine3=0x0D=13
ovs-vsctl set bridge $SPINE1 other-config:hwaddr=00:00:00:00:00:0B
ovs-vsctl set bridge $SPINE2 other-config:hwaddr=00:00:00:00:00:0C
ovs-vsctl set bridge $SPINE3 other-config:hwaddr=00:00:00:00:00:0D
# leaf1=0x15=21, leaf2=0x16=22, leaf3=0x17=23, leaf4=0x18=24
ovs-vsctl set bridge $LEAF1 other-config:hwaddr=00:00:00:00:00:15
ovs-vsctl set bridge $LEAF2 other-config:hwaddr=00:00:00:00:00:16
ovs-vsctl set bridge $LEAF3 other-config:hwaddr=00:00:00:00:00:17
ovs-vsctl set bridge $LEAF4 other-config:hwaddr=00:00:00:00:00:18

echo "=== Connect switches via patch ports ==="
# Port-add ORDER determines OpenFlow port numbers.
#
# Spines: add leaf1 first → OF port 1, leaf2 → port 2, leaf3 → port 3, leaf4 → port 4
# Leaves: add spine1 first → OF port 1, spine2 → port 2, spine3 → port 3

# --- Spine1 ports (OF 1→leaf1, 2→leaf2, 3→leaf3, 4→leaf4) ---
ovs-vsctl --may-exist add-port $SPINE1 s1l1 -- set interface s1l1 type=patch options:peer=l1s1
ovs-vsctl --may-exist add-port $SPINE1 s1l2 -- set interface s1l2 type=patch options:peer=l2s1
ovs-vsctl --may-exist add-port $SPINE1 s1l3 -- set interface s1l3 type=patch options:peer=l3s1
ovs-vsctl --may-exist add-port $SPINE1 s1l4 -- set interface s1l4 type=patch options:peer=l4s1

# --- Spine2 ports (OF 1→leaf1, 2→leaf2, 3→leaf3, 4→leaf4) ---
ovs-vsctl --may-exist add-port $SPINE2 s2l1 -- set interface s2l1 type=patch options:peer=l1s2
ovs-vsctl --may-exist add-port $SPINE2 s2l2 -- set interface s2l2 type=patch options:peer=l2s2
ovs-vsctl --may-exist add-port $SPINE2 s2l3 -- set interface s2l3 type=patch options:peer=l3s2
ovs-vsctl --may-exist add-port $SPINE2 s2l4 -- set interface s2l4 type=patch options:peer=l4s2

# --- Spine3 ports (OF 1→leaf1, 2→leaf2, 3→leaf3, 4→leaf4) ---
ovs-vsctl --may-exist add-port $SPINE3 s3l1 -- set interface s3l1 type=patch options:peer=l1s3
ovs-vsctl --may-exist add-port $SPINE3 s3l2 -- set interface s3l2 type=patch options:peer=l2s3
ovs-vsctl --may-exist add-port $SPINE3 s3l3 -- set interface s3l3 type=patch options:peer=l3s3
ovs-vsctl --may-exist add-port $SPINE3 s3l4 -- set interface s3l4 type=patch options:peer=l4s3

# --- Leaf1 uplink ports (OF 1→spine1, 2→spine2, 3→spine3) ---
ovs-vsctl --may-exist add-port $LEAF1 l1s1 -- set interface l1s1 type=patch options:peer=s1l1
ovs-vsctl --may-exist add-port $LEAF1 l1s2 -- set interface l1s2 type=patch options:peer=s2l1
ovs-vsctl --may-exist add-port $LEAF1 l1s3 -- set interface l1s3 type=patch options:peer=s3l1

# --- Leaf2 uplink ports (OF 1→spine1, 2→spine2, 3→spine3) ---
ovs-vsctl --may-exist add-port $LEAF2 l2s1 -- set interface l2s1 type=patch options:peer=s1l2
ovs-vsctl --may-exist add-port $LEAF2 l2s2 -- set interface l2s2 type=patch options:peer=s2l2
ovs-vsctl --may-exist add-port $LEAF2 l2s3 -- set interface l2s3 type=patch options:peer=s3l2

# --- Leaf3 uplink ports (OF 1→spine1, 2→spine2, 3→spine3) ---
ovs-vsctl --may-exist add-port $LEAF3 l3s1 -- set interface l3s1 type=patch options:peer=s1l3
ovs-vsctl --may-exist add-port $LEAF3 l3s2 -- set interface l3s2 type=patch options:peer=s2l3
ovs-vsctl --may-exist add-port $LEAF3 l3s3 -- set interface l3s3 type=patch options:peer=s3l3

# --- Leaf4 uplink ports (OF 1→spine1, 2→spine2, 3→spine3) ---
ovs-vsctl --may-exist add-port $LEAF4 l4s1 -- set interface l4s1 type=patch options:peer=s1l4
ovs-vsctl --may-exist add-port $LEAF4 l4s2 -- set interface l4s2 type=patch options:peer=s2l4
ovs-vsctl --may-exist add-port $LEAF4 l4s3 -- set interface l4s3 type=patch options:peer=s3l4

echo "=== Set switch options ==="
for BR in $SPINE1 $SPINE2 $SPINE3 $LEAF1 $LEAF2 $LEAF3 $LEAF4
do
  ovs-vsctl set bridge $BR fail_mode=$FAIL_MODE
  ovs-vsctl set bridge $BR protocols=$OF_VER
  ovs-vsctl set-controller $BR tcp:$IP_CTRL:$IP_PORT
done
