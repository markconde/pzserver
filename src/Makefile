IMAGE_NAME = markconde/pzserver
CONTAINER_NAME = pz-test
DATA_DIR = $(PWD)/zomboid-data

# Default target
.PHONY: build
build:
	docker build -t $(IMAGE_NAME):latest .

.PHONY: run
run:
	docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
	docker run --rm -it \
		--name $(CONTAINER_NAME) \
		-p 16261:16261/udp \
		-p 16262-16272:16262-16272/udp \
		-p 27015:27015/tcp \
		-v "$(DATA_DIR):/home/steam/Zomboid" \
		-e SERVER_NAME="ZomboidServer" \
		-e ADMIN_PASSWORD="changeme" \
		-e RCON_PORT="27015" \
		-e RCON_PASSWORD="changeme_rcon" \
		$(IMAGE_NAME):latest

.PHONY: shell
shell:
	docker run --rm -it \
		--name $(CONTAINER_NAME)-shell \
		--entrypoint /bin/bash \
		$(IMAGE_NAME):latest

.PHONY: logs
logs:
	docker logs -f $(CONTAINER_NAME)

.PHONY: clean
clean:
	docker rm -f $(CONTAINER_NAME) 2>/dev/null || true