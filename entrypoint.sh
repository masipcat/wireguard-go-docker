wg set wg0 listen-port 51820
wg set wg0 private-key /etc/wireguard/privkey
wg set wg0 peer oqUAXorHkpP5fYyMxy6Jv+lzttNzXthdC8Bdsb7yem4= allowed-ips 10.0.0.2/32
sysctl -w net.ipv4.ip_forward=1
ip addr add 10.0.0.1/24 dev wg0
iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o eth0 -j MASQUERADE
ip link set up dev wg0
