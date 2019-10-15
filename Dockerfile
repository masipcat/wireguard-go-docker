FROM golang:1.13-alpine3.10 as builder

ARG wg_go_tag=v0.0.20191012
ARG wg_tag=0.0.20190702

RUN apk add --update git build-base libmnl-dev iptables

RUN git clone https://git.zx2c4.com/wireguard-go && \
    cd wireguard-go && \
    git checkout $wg_go_tag && \
    make && \
    make install

ENV WITH_WGQUICK=yes
RUN git clone https://git.zx2c4.com/WireGuard && \
    cd WireGuard && \
    git checkout $wg_tag && \
    cd src && \
    make tools && \
    make -C tools install

FROM alpine:3.10

RUN apk add --update bash libmnl iptables

COPY --from=builder /usr/bin/wireguard-go /usr/bin/wg* /usr/bin/
COPY entrypoint.sh /entrypoint.sh

CMD ["/entrypoint.sh"]
