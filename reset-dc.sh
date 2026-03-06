#!/bin/bash

echo "=== Removing OVS bridges ==="
for sw in c1 c2 c3 c4 \
          a01 a02 a11 a12 a21 a22 a31 a32 \
          e01 e02 e11 e12 e21 e22 e31 e32; do
    ovs-vsctl --if-exists del-br $sw
done
echo "=== Done ==="
