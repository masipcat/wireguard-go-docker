.PHONY: build push

DOCKER_REGISTRY ?= masipcat/wireguard-go

build:
	docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
	docker build -t ${DOCKER_REGISTRY}:${TAG}-amd64 --build-arg ARCH=amd64/ .
	docker build -t ${DOCKER_REGISTRY}:${TAG}-arm32v6 --build-arg ARCH=arm32v6/ .
	docker build -t ${DOCKER_REGISTRY}:${TAG}-arm32v7 --build-arg ARCH=arm32v7/ .
	docker build -t ${DOCKER_REGISTRY}:${TAG}-arm64v8 --build-arg ARCH=arm64v8/ .

push:
	docker push ${DOCKER_REGISTRY}:${TAG}-amd64
	docker push ${DOCKER_REGISTRY}:${TAG}-arm32v6
	docker push ${DOCKER_REGISTRY}:${TAG}-arm32v7
	docker push ${DOCKER_REGISTRY}:${TAG}-arm64v8
	docker manifest create ${DOCKER_REGISTRY}:${TAG} \
		--amend ${DOCKER_REGISTRY}:${TAG}-amd64 \
		--amend ${DOCKER_REGISTRY}:${TAG}-arm32v6 \
		--amend ${DOCKER_REGISTRY}:${TAG}-arm32v7 \
		--amend ${DOCKER_REGISTRY}:${TAG}-arm64v8
	docker manifest push ${DOCKER_REGISTRY}:${TAG}
