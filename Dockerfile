FROM golang:1.12.1-alpine3.9 as builder

ARG tag=0.0.20181222

RUN apk add --update git build-base libmnl-dev iptables

RUN git clone https://git.zx2c4.com/wireguard-go && \
    cd wireguard-go && \
    git checkout $tag && \
    make && \
    make install

ENV WITH_WGQUICK=yes
RUN git clone https://git.zx2c4.com/WireGuard && \
    cd WireGuard/src && \
    make tools && \
    make -C tools install

FROM alpine:3.9

RUN apk add --update bash libmnl iptables

COPY --from=builder /usr/bin/wireguard-go /usr/bin/wg* /usr/bin/
COPY entrypoint.sh /entrypoint.sh

ENV WG_I_PREFER_BUGGY_USERSPACE_TO_POLISHED_KMOD=1

ENTRYPOINT ["/entrypoint.sh"]
