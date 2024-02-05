ARG ARCH=
ARG GOLANG_VERSION=1.20
ARG ALPINE_VERSION=3.18

FROM ${ARCH}golang:${GOLANG_VERSION}-alpine${ALPINE_VERSION} as builder

ARG wg_go_tag=0.0.20230223
ARG wg_tools_tag=v1.0.20210914

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

COPY --from=hairyhenderson/gomplate:stable /gomplate /bin/gomplate


FROM ${ARCH}alpine:${ALPINE_VERSION}

RUN apk add --no-cache --update bash libmnl iptables openresolv iproute2 curl \
        wireguard-tools-doc tcpdump nmap-ncat nginx

COPY --from=builder /usr/bin/wireguard-go /usr/bin/wg* /bin/gomplate /usr/bin/



RUN mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bk \
    && mv /etc/nginx/http.d/default.conf /etc/nginx/http.d/default.conf.bk

COPY ng /etc/ng
COPY ng/nginx-auto.sh /usr/bin/nginx-auto

COPY entrypoint.sh /entrypoint.sh

RUN mkdir -p /data/ng
VOLUME /data

CMD ["/entrypoint.sh"]
