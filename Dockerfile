ARG ARCH=

FROM ${ARCH}golang:1.16.5-alpine3.13 as builder

ARG wg_go_tag=0.0.20210424
ARG wg_tools_tag=v1.0.20210424

RUN apk add --update git build-base libmnl-dev iptables

RUN git clone https://git.zx2c4.com/wireguard-go && \
    cd wireguard-go && \
    git checkout $wg_go_tag && \
    make && \
    make install

ENV WITH_WGQUICK=yes
RUN git clone https://git.zx2c4.com/wireguard-tools && \
    cd wireguard-tools && \
    git checkout $wg_tools_tag && \
    cd src && \
    make && \
    make install

FROM ${ARCH}alpine:3.13

RUN apk add --no-cache --update bash libmnl iptables openresolv iproute2

COPY --from=builder /usr/bin/wireguard-go /usr/bin/wg* /usr/bin/
COPY entrypoint.sh /entrypoint.sh

CMD ["/entrypoint.sh"]
