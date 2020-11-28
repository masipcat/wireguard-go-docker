.PHONY: build push

build:
	docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
	docker build -t masipcat/wireguard-go:${TAG}-amd64 --build-arg ARCH=amd64/ .
	docker build -t masipcat/wireguard-go:${TAG}-arm32v7 --build-arg ARCH=arm32v7/ .
	docker build -t masipcat/wireguard-go:${TAG}-arm64v8 --build-arg ARCH=arm64v8/ .

push:
	docker push masipcat/wireguard-go:${TAG}-amd64
	docker push masipcat/wireguard-go:${TAG}-arm32v7
	docker push masipcat/wireguard-go:${TAG}-arm64v8
	docker manifest create masipcat/wireguard-go:${TAG} \
		--amend masipcat/wireguard-go:${TAG}-amd64 \
		--amend masipcat/wireguard-go:${TAG}-arm32v7 \
		--amend masipcat/wireguard-go:${TAG}-arm64v8
	docker manifest push masipcat/wireguard-go:${TAG}
