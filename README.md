# wireguard-go docker

[![](https://images.microbadger.com/badges/version/masipcat/wireguard-go.svg)](https://hub.docker.com/r/masipcat/wireguard-go/tags) [![](https://images.microbadger.com/badges/image/masipcat/wireguard-go.svg)](https://hub.docker.com/r/masipcat/wireguard-go/tags)

## Setup

First of all you need a key pair for the server. Use the following command to generate the public and private keys:

```bash
# Generate privatekey
docker run --rm -i masipcat/wireguard-go wg genkey > privatekey

# Generate publickey from privatekey
docker run --rm -i masipcat/wireguard-go wg pubkey < privatekey > publickey
```

## Run server

### Docker

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
    # Uncomment the following line when 'AllowedIPs' is '0.0.0.0/0'
    # privileged: true
    restart: always
```

```
docker-compose up -d
```

### Kubernetes

Steps to deploy Wireguard-go to a k8s cluster:

1. Set the `privatekey` for the wireguard server in the `Secret` object
2. Add at least one peer in `wg0.conf`
3. Run `kubectl apply -f wireguard.yaml` to deploy wireguard

`wireguard.yaml`
```yaml
kind: Secret
apiVersion: v1
metadata:
  name: wg-secret
type: Opaque
data:
  # Generate and encode the server private key: `wg genkey | base64`
  privatekey: REPLACE_WITH_BASE64_PRIVKEY
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: wg-configmap
data:
  wg0.conf: |
    [Interface]
    Address = 10.33.0.1/24
    ListenPort = 51820
    PostUp = wg set wg0 private-key /etc/wireguard/privatekey && iptables -t nat -A POSTROUTING -s 10.33.0.0/24 -o eth0 -j MASQUERADE
    PostDown = iptables -t nat -D POSTROUTING -s 10.33.0.0/24 -o eth0 -j MASQUERADE

    # [Peer]
    # PublicKey =
    # AllowedIPs = 10.33.0.2/32
---
kind: Service
apiVersion: v1
metadata:
  name: wireguard
  labels:
    app: wireguard
spec:
  type: LoadBalancer
  ports:
  - name: wg
    protocol: UDP
    port: 51820
    targetPort: 51820
  selector:
    app: wireguard
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wireguard
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wireguard
  template:
    metadata:
      labels:
        app: wireguard
    spec:
      initContainers:
        - name: sysctls
          image: busybox
          command:
          - sh
          - -c
          - sysctl -w net.ipv4.ip_forward=1 && sysctl -w net.ipv4.conf.all.forwarding=1
          securityContext:
            capabilities:
              add:
                - NET_ADMIN
            privileged: true
      containers:
        - name: wireguard
          image: masipcat/wireguard-go:latest
          command:
          - sh
          - -c
          - echo "Public key '$(wg pubkey < /etc/wireguard/privatekey)'" && /entrypoint.sh
          ports:
          - containerPort: 51820
            protocol: UDP
            name: wireguard
          env:
          - name: LOG_LEVEL
            value: info
          securityContext:
            capabilities:
              add:
                - NET_ADMIN
            privileged: true
          resources:
            requests:
              memory: 64Mi
              cpu: "100m"
            limits:
              memory: 256Mi
          volumeMounts:
          - name: cfgmap
            mountPath: /etc/wireguard/wg0.conf
            subPath: wg0.conf
          - name: secret
            mountPath: /etc/wireguard/privatekey
            subPath: privatekey
      volumes:
      - name: cfgmap
        configMap:
          name: wg-configmap
      - name: secret
        secret:
          secretName: wg-secret
```

## Client config examples

### Basic

`/etc/wireguard/wg0.conf`
```conf
[Interface]
# Assign you an IP (that's not in use) and add it to server configmap
Address = 10.33.0.2/32
# generate private key using `wg genkey`
PrivateKey = <your private key>

[Peer]
# Wireguard server public key
PublicKey = AbC...XyZ=
# LoadBalancer IP (replace with your LoadBalancer ip)
Endpoint = 1.2.3.4:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

### Basic + kube-dns

(This example only works with OS that use `openresolv`)

`/etc/wireguard/wg0.conf`
```conf
[Interface]
...
# Configure kube-dns ip address as dns resolver in you local machine (resolves names like 'your-service.default.svc.cluster.local')
PostUp = printf "nameserver 10.90.0.5\nsearch default.svc.cluster.local svc.cluster.local cluster.local" | resolvconf -a %i

[Peer]
...
# Change AllowedIPs to 10.0.0.0/8 if you only want to connect to k8s pods/services
AllowedIPs = 10.0.0.0/8
```
