.PHONY: build push manifest

build:
	docker build -t masipcat/wireguard-go:${TAG}-amd64 --build-arg ARCH=amd64/ .
	docker build -t masipcat/wireguard-go:${TAG}-arm32v7 --build-arg ARCH=arm32v7/ .
	docker build -t masipcat/wireguard-go:${TAG}-arm64v8 --build-arg ARCH=arm64v8/ .

push:
	docker push masipcat/wireguard-go:${TAG}-amd64
	docker push masipcat/wireguard-go:${TAG}-arm32v7
	docker push masipcat/wireguard-go:${TAG}-arm64v8

manifest:
	docker manifest create masipcat/wireguard-go:${TAG} \
		masipcat/wireguard-go:${TAG}-amd64 \
		masipcat/wireguard-go:${TAG}-arm32v7 \
		masipcat/wireguard-go:${TAG}-arm64v8
	docker manifest push masipcat/wireguard-go:${TAG}
