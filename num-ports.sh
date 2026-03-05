#!/bin/bash

# Set desired OpenFlow port numbers for host-facing interfaces.
# Each leaf has 3 spine uplinks (OF ports 1-3), so host ports start at 4.
#
# Interface names match the YAML links:
#   leaf1: p1, p2, p3  (hosts h11, h12, h13)  → OF ports 4, 5, 6
#   leaf2: p4, p5, p6  (hosts h21, h22, h23)  → OF ports 4, 5, 6
#   leaf3: p7, p8, p9  (hosts h31, h32, h33)  → OF ports 4, 5, 6
#   leaf4: p10, p11, p12 (hosts h41, h42, h43) → OF ports 4, 5, 6

echo "Set desired port numbers"

# Leaf1 host ports
ovs-vsctl set Interface p1  ofport_request=4
ovs-vsctl set Interface p2  ofport_request=5
ovs-vsctl set Interface p3  ofport_request=6

# Leaf2 host ports
ovs-vsctl set Interface p4  ofport_request=4
ovs-vsctl set Interface p5  ofport_request=5
ovs-vsctl set Interface p6  ofport_request=6

# Leaf3 host ports
ovs-vsctl set Interface p7  ofport_request=4
ovs-vsctl set Interface p8  ofport_request=5
ovs-vsctl set Interface p9  ofport_request=6

# Leaf4 host ports
ovs-vsctl set Interface p10 ofport_request=4
ovs-vsctl set Interface p11 ofport_request=5
ovs-vsctl set Interface p12 ofport_request=6
