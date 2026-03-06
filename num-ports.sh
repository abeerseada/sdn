#!/bin/bash

# Fat-Tree k=4 — OpenFlow port number assignments
#
# Port layout per switch type:
#   Core  : port 1-4 → one agg per pod
#   Agg   : port 1-2 → core uplinks  |  port 3-4 → edge downlinks
#   Edge  : port 1-2 → agg uplinks   |  port 3-4 → host downlinks

echo "=== Setting OpenFlow port numbers ==="

# ── Core c1 (ports 1-4 → pod0,1,2,3 first agg)
ovs-vsctl set Interface c1a01 ofport_request=1
ovs-vsctl set Interface c1a11 ofport_request=2
ovs-vsctl set Interface c1a21 ofport_request=3
ovs-vsctl set Interface c1a31 ofport_request=4

# ── Core c2 (ports 1-4 → pod0,1,2,3 first agg)
ovs-vsctl set Interface c2a01 ofport_request=1
ovs-vsctl set Interface c2a11 ofport_request=2
ovs-vsctl set Interface c2a21 ofport_request=3
ovs-vsctl set Interface c2a31 ofport_request=4

# ── Core c3 (ports 1-4 → pod0,1,2,3 second agg)
ovs-vsctl set Interface c3a02 ofport_request=1
ovs-vsctl set Interface c3a12 ofport_request=2
ovs-vsctl set Interface c3a22 ofport_request=3
ovs-vsctl set Interface c3a32 ofport_request=4

# ── Core c4 (ports 1-4 → pod0,1,2,3 second agg)
ovs-vsctl set Interface c4a02 ofport_request=1
ovs-vsctl set Interface c4a12 ofport_request=2
ovs-vsctl set Interface c4a22 ofport_request=3
ovs-vsctl set Interface c4a32 ofport_request=4

# ── Agg a01 pod0 (1=c1, 2=c2, 3=e01, 4=e02)
ovs-vsctl set Interface a01c1  ofport_request=1
ovs-vsctl set Interface a01c2  ofport_request=2
ovs-vsctl set Interface a01e01 ofport_request=3
ovs-vsctl set Interface a01e02 ofport_request=4

# ── Agg a02 pod0 (1=c3, 2=c4, 3=e01, 4=e02)
ovs-vsctl set Interface a02c3  ofport_request=1
ovs-vsctl set Interface a02c4  ofport_request=2
ovs-vsctl set Interface a02e01 ofport_request=3
ovs-vsctl set Interface a02e02 ofport_request=4

# ── Agg a11 pod1
ovs-vsctl set Interface a11c1  ofport_request=1
ovs-vsctl set Interface a11c2  ofport_request=2
ovs-vsctl set Interface a11e11 ofport_request=3
ovs-vsctl set Interface a11e12 ofport_request=4

# ── Agg a12 pod1
ovs-vsctl set Interface a12c3  ofport_request=1
ovs-vsctl set Interface a12c4  ofport_request=2
ovs-vsctl set Interface a12e11 ofport_request=3
ovs-vsctl set Interface a12e12 ofport_request=4

# ── Agg a21 pod2
ovs-vsctl set Interface a21c1  ofport_request=1
ovs-vsctl set Interface a21c2  ofport_request=2
ovs-vsctl set Interface a21e21 ofport_request=3
ovs-vsctl set Interface a21e22 ofport_request=4

# ── Agg a22 pod2
ovs-vsctl set Interface a22c3  ofport_request=1
ovs-vsctl set Interface a22c4  ofport_request=2
ovs-vsctl set Interface a22e21 ofport_request=3
ovs-vsctl set Interface a22e22 ofport_request=4

# ── Agg a31 pod3
ovs-vsctl set Interface a31c1  ofport_request=1
ovs-vsctl set Interface a31c2  ofport_request=2
ovs-vsctl set Interface a31e31 ofport_request=3
ovs-vsctl set Interface a31e32 ofport_request=4

# ── Agg a32 pod3
ovs-vsctl set Interface a32c3  ofport_request=1
ovs-vsctl set Interface a32c4  ofport_request=2
ovs-vsctl set Interface a32e31 ofport_request=3
ovs-vsctl set Interface a32e32 ofport_request=4

# ── Edge e01 pod0 (1=a01, 2=a02, 3=h011, 4=h012)
ovs-vsctl set Interface e01a01  ofport_request=1
ovs-vsctl set Interface e01a02  ofport_request=2
ovs-vsctl set Interface e01h011 ofport_request=3
ovs-vsctl set Interface e01h012 ofport_request=4

# ── Edge e02 pod0
ovs-vsctl set Interface e02a01  ofport_request=1
ovs-vsctl set Interface e02a02  ofport_request=2
ovs-vsctl set Interface e02h021 ofport_request=3
ovs-vsctl set Interface e02h022 ofport_request=4

# ── Edge e11 pod1
ovs-vsctl set Interface e11a11  ofport_request=1
ovs-vsctl set Interface e11a12  ofport_request=2
ovs-vsctl set Interface e11h111 ofport_request=3
ovs-vsctl set Interface e11h112 ofport_request=4

# ── Edge e12 pod1
ovs-vsctl set Interface e12a11  ofport_request=1
ovs-vsctl set Interface e12a12  ofport_request=2
ovs-vsctl set Interface e12h121 ofport_request=3
ovs-vsctl set Interface e12h122 ofport_request=4

# ── Edge e21 pod2
ovs-vsctl set Interface e21a21  ofport_request=1
ovs-vsctl set Interface e21a22  ofport_request=2
ovs-vsctl set Interface e21h211 ofport_request=3
ovs-vsctl set Interface e21h212 ofport_request=4

# ── Edge e22 pod2
ovs-vsctl set Interface e22a21  ofport_request=1
ovs-vsctl set Interface e22a22  ofport_request=2
ovs-vsctl set Interface e22h221 ofport_request=3
ovs-vsctl set Interface e22h222 ofport_request=4

# ── Edge e31 pod3
ovs-vsctl set Interface e31a31  ofport_request=1
ovs-vsctl set Interface e31a32  ofport_request=2
ovs-vsctl set Interface e31h311 ofport_request=3
ovs-vsctl set Interface e31h312 ofport_request=4

# ── Edge e32 pod3
ovs-vsctl set Interface e32a31  ofport_request=1
ovs-vsctl set Interface e32a32  ofport_request=2
ovs-vsctl set Interface e32h321 ofport_request=3
ovs-vsctl set Interface e32h322 ofport_request=4

echo "=== Done ==="
