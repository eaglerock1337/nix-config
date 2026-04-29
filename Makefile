NIX_FLAGS := --extra-experimental-features 'nix-command flakes'

.PHONY: build-image flash-image silicon-dry silicon-switch update help

help:
	@echo "Targets:"
	@echo "  build-image HOST=hlc-501          Build SD card image for a pi node"
	@echo "  flash-image HOST=hlc-501 DEV=...  Flash built image to SD card device"
	@echo "  silicon-dry                        Dry-run NixOS config for silicon"
	@echo "  silicon-switch                     Apply NixOS config for silicon"
	@echo "  update                             Update all flake inputs"

build-image:
ifndef HOST
	$(error HOST is not set. Usage: make build-image HOST=hlc-501)
endif
	time nix build $(NIX_FLAGS) \
		.#nixosConfigurations.$(HOST).config.system.build.sdImage \
		-L

flash-image: build-image
ifndef HOST
	$(error HOST is not set. Usage: make flash-image HOST=hlc-501 DEV=/dev/sdX)
endif
ifndef DEV
	$(error DEV is not set. Usage: make flash-image HOST=hlc-501 DEV=/dev/sdX)
endif
	@echo "WARNING: About to flash $(DEV). Ctrl+C to abort."
	@sleep 5
	zstdcat result/sd-image/*.img.zst | sudo dd if=/dev/stdin of=$(DEV) bs=4M conv=fsync status=progress

silicon-dry:
	sudo nixos-rebuild dry-run --flake .#silicon

silicon-switch:
	sudo nixos-rebuild switch --flake .#silicon

update:
	nix flake update $(NIX_FLAGS)
