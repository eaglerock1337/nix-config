NIX_FLAGS := --extra-experimental-features 'nix-command flakes'

HLC_HOSTS := hlc-401 hlc-402 hlc-403 hlc-404 hlc-501 hlc-502 hlc-503 hlc-504 hlc-505 hlc-506 hlc-507 hlc-508

.PHONY: build-image flash-image silicon-dry silicon-switch update help \
        dry-run dry-run-all update-node build-image-rpi4 build-image-rpi5 \
        provision update-cluster encrypt-secret

help:
	@echo "Targets:"
	@echo "  build-image HOST=hlc-501          Build SD card image for a pi node"
	@echo "  flash-image HOST=hlc-501 DEV=...  Flash built image to SD card device"
	@echo "  silicon-dry                        Dry-run NixOS config for silicon"
	@echo "  silicon-switch                     Apply NixOS config for silicon"
	@echo "  update                             Update all flake inputs"
	@echo ""
	@echo "Cluster targets:"
	@echo "  dry-run HOST=hlc-401              Dry-run a single cluster host"
	@echo "  dry-run-all                        Dry-run all 12 cluster hosts"
	@echo "  update-node HOST=hlc-401 IP=...   Deploy to a live node over SSH"
	@echo "  build-image-rpi4                   Build SD image (Pi4, uses hlc-401)"
	@echo "  build-image-rpi5                   Build SD image (Pi5, uses hlc-501)"

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

# --- Cluster targets (HLC) ---

# Dry-run a single cluster host (validates evaluation without building)
# Usage: make dry-run HOST=hlc-401
dry-run:
ifndef HOST
	$(error HOST is not set. Usage: make dry-run HOST=hlc-401)
endif
	nixos-rebuild dry-run --flake .#$(HOST)

# Dry-run all 12 cluster hosts — exits non-zero on first failure
dry-run-all:
	@for host in $(HLC_HOSTS); do \
		echo "==> dry-run: $$host"; \
		nixos-rebuild dry-run --flake .#$$host || exit 1; \
	done
	@echo "==> All hosts passed dry-run."

# Deploy to a live node over SSH
# Usage: make update-node HOST=hlc-401 IP=10.23.50.41
update-node:
ifndef HOST
	$(error HOST is not set. Usage: make update-node HOST=hlc-401 IP=10.23.50.41)
endif
ifndef IP
	$(error IP is not set. Usage: make update-node HOST=hlc-401 IP=10.23.50.41)
endif
	nixos-rebuild switch --flake .#$(HOST) --target-host bob@$(IP) --use-remote-sudo

# Build SD card image for Pi4 control-plane nodes (uses hlc-401 as reference)
build-image-rpi4:
	nix build $(NIX_FLAGS) .#nixosConfigurations.hlc-401.config.system.build.sdImage -L

# Build SD card image for Pi5 worker nodes (uses hlc-501 as reference)
build-image-rpi5:
	nix build $(NIX_FLAGS) .#nixosConfigurations.hlc-501.config.system.build.sdImage -L

# Phase B/C — not yet implemented
provision:
	# Phase B — nixos-anywhere unattended provisioning
	@echo "Not yet implemented. See specs/001-nixos-rpi-cluster/plan.md Phase B."

update-cluster:
	# Phase C — rolling cluster update with quorum safety
	@echo "Not yet implemented. See specs/001-nixos-rpi-cluster/plan.md Phase C."

encrypt-secret:
	# Phase B — sops-nix secret encryption
	@echo "Not yet implemented. See specs/001-nixos-rpi-cluster/plan.md Phase B."
