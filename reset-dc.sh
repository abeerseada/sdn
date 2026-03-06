#!/bin/bash

echo "=== Removing OVS bridges ==="
for sw in c1 c2 c3 c4 \
          a01 a02 a11 a12 a21 a22 a31 a32 \
          e01 e02 e11 e12 e21 e22 e31 e32; do
    ovs-vsctl --if-exists del-br $sw
done

echo "=== Removing leftover veth interfaces ==="
for iface in $(ip -o link show | awk '{print $2}' | cut -d'@' -f1 | cut -d':' -f1 | grep -E '^[ace][0-9]|^h[0-9]'); do
    ip link delete "$iface" 2>/dev/null || true
done

echo "=== Done ==="
