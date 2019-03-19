# wireguard-go docker

## Setup

First of all you need a key pair for the server. Use the following command to generate the public and private keys:

```bash
# Generate privatekey
docker run --rm -i masipcat/wireguard-go wg genkey > privatekey

# Generate publickey from privatekey
docker run --rm -i masipcat/wireguard-go wg genkey < privatekey > publickey
```

## Run server

`docker-compose.yaml`
```yaml
version: '3.3'
services:
  wireguard:
    image: masipcat/wireguard-go:latest
    cap_add:
     - NET_ADMIN
    sysctls:
     - net.ipv4.ip_forward=1
    volumes:
     - /dev/net/tun:/dev/net/tun
     # Folder with 'publickey', 'privatekey' and 'wg0.conf'
     - ./wireguard:/etc/wireguard
    environment:
     - WG_COLOR_MODE=always
     - LOG_LEVEL=info
    ports:
     - 51820:51820/udp
    restart: always
```

```
docker-compose up -d
```

