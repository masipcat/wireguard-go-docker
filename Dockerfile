FROM golang:1.11.0-alpine3.8

RUN apk update && apk add git curl build-base libmnl-dev iptables

RUN curl https://raw.githubusercontent.com/golang/dep/master/install.sh | sh

RUN git clone https://git.zx2c4.com/wireguard-go && cd wireguard-go && make && make install

RUN git clone https://git.zx2c4.com/WireGuard && cd WireGuard/src && make tools && make -C tools install

ENV LOG_LEVEL=debug
ENV WG_I_PREFER_BUGGY_USERSPACE_TO_POLISHED_KMOD=1

ENTRYPOINT ["wireguard-go", "-f", "wg0"]

