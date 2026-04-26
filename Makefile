NIX_FLAGS := --extra-experimental-features 'nix-command flakes'

# Constitution v1.1.0 § Cluster Topology:
#   WORK_SET    — active NixOS rollout (flash, build, canary, switch ALL valid).
#   DECOM_SET   — Debian-on-old-cluster, untouchable until parity cutover.
#                 Configs evaluate (dry-run only). NEVER flash, NEVER switch.
#   HLC_HOSTS   — union; used for `dry-run-all` ONLY.
WORK_SET := hlc-401 hlc-501 hlc-502 hlc-503 hlc-504 hlc-505 hlc-506 hlc-507 hlc-508
DECOM_SET := hlc-402 hlc-403 hlc-404
HLC_HOSTS := $(WORK_SET) $(DECOM_SET)

.PHONY: build-image flash-image silicon-dry silicon-switch update help \
        dry-run dry-run-all update-node build-image-rpi4 build-image-rpi5 \
        provision update-cluster encrypt-secret \
        build smoke-test smoke-test-all canary rollback ip

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
	@echo "  update-node HOST=hlc-401 IP=...   Plain switch (canary OTHER node first)"
	@echo "  build-image-rpi4                   Build SD image (Pi4, uses hlc-401)"
	@echo "  build-image-rpi5                   Build SD image (Pi5, uses hlc-501)"
	@echo ""
	@echo "Phase A safety (constitution v1.1.0 § Safety & Change Management):"
	@echo "  build HOST=hlc-501                 Full toplevel build (gate before flashing)"
	@echo "  smoke-test HOST=hlc-501 IP=...    ping + non-PTY ssh + PTY ssh + sudo -n"
	@echo "  smoke-test-all                     smoke-test every WORK_SET host (reads docs/cluster-ips.txt)"
	@echo "  canary HOST=hlc-501 IP=...        build -> switch -> smoke-test -> auto-rollback on fail"
	@echo "  rollback HOST=hlc-501 IP=...      manual rollback + smoke-test"
	@echo "  ip HOST=hlc-501                    print recorded IP for HOST from docs/cluster-ips.txt"

# --- Image build (existing) ---

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
	@if echo "$(DECOM_SET)" | grep -wq "$(HOST)"; then \
		echo "REFUSED: $(HOST) is in DECOM_SET (constitution v1.1.0 § Cluster Topology)."; \
		echo "         Decommission cutover is a future feature spec. Aborting."; \
		exit 1; \
	fi
	@echo "WARNING: About to flash $(DEV). Ctrl+C to abort."
	@sleep 5
	zstdcat result/sd-image/*.img.zst | sudo dd if=/dev/stdin of=$(DEV) bs=4M conv=fsync status=progress

silicon-dry:
	sudo nixos-rebuild dry-run --flake .#silicon

silicon-switch:
	sudo nixos-rebuild switch --flake .#silicon

update:
	nix flake update $(NIX_FLAGS)

# --- Cluster dry-run / plain switch (existing) ---

dry-run:
ifndef HOST
	$(error HOST is not set. Usage: make dry-run HOST=hlc-401)
endif
	nix build $(NIX_FLAGS) --dry-run .#nixosConfigurations.$(HOST).config.system.build.toplevel

dry-run-all:
	@for host in $(HLC_HOSTS); do \
		echo "==> dry-run: $$host"; \
		nix build $(NIX_FLAGS) --dry-run .#nixosConfigurations.$$host.config.system.build.toplevel || exit 1; \
	done
	@echo "==> All hosts passed dry-run."

update-node:
ifndef HOST
	$(error HOST is not set. Usage: make update-node HOST=hlc-401 IP=10.23.50.41)
endif
ifndef IP
	$(error IP is not set. Usage: make update-node HOST=hlc-401 IP=10.23.50.41)
endif
	@if echo "$(DECOM_SET)" | grep -wq "$(HOST)"; then \
		echo "REFUSED: $(HOST) is in DECOM_SET. nixos-rebuild switch forbidden."; \
		exit 1; \
	fi
	nixos-rebuild switch --flake .#$(HOST) --target-host bob@$(IP) --use-remote-sudo

build-image-rpi4:
	nix build $(NIX_FLAGS) .#nixosConfigurations.hlc-401.config.system.build.sdImage -L

build-image-rpi5:
	nix build $(NIX_FLAGS) .#nixosConfigurations.hlc-501.config.system.build.sdImage -L

# --- Phase B/C placeholders (unchanged) ---

provision:
	@echo "Not yet implemented. See specs/001-nixos-rpi-cluster/plan.md Phase B."

update-cluster:
	@echo "Not yet implemented. See specs/001-nixos-rpi-cluster/plan.md Phase C."

encrypt-secret:
	@echo "Not yet implemented. See specs/001-nixos-rpi-cluster/plan.md Phase B."

# --- Phase A safety targets (new — tasks T005–T011) ---

# T006 — Full toplevel build. Catches errors `dry-run` misses (e.g. anything
# that only shows up at closure-build time). Required gate before flashing.
build:
ifndef HOST
	$(error HOST is not set. Usage: make build HOST=hlc-501)
endif
	nix build $(NIX_FLAGS) \
		.#nixosConfigurations.$(HOST).config.system.build.toplevel \
		-L --no-link

# T005 — Reachability + ssh + sudo round-trip. See scripts/smoke-test.sh.
smoke-test:
ifndef HOST
	$(error HOST is not set. Usage: make smoke-test HOST=hlc-501 IP=10.23.50.51)
endif
ifndef IP
	$(error IP is not set. Usage: make smoke-test HOST=hlc-501 IP=10.23.50.51)
endif
	@scripts/smoke-test.sh $(HOST) $(IP)

# T010 — smoke-test every WORK_SET host. Reads tab-separated docs/cluster-ips.txt
# (`<hostname>\t<ip>\t<mac>`). Decommissioned-set hosts intentionally excluded.
# Exits non-zero on first failure.
smoke-test-all:
	@if [ ! -f docs/cluster-ips.txt ]; then \
		echo "docs/cluster-ips.txt missing — populate per task T041/T045 etc."; \
		exit 1; \
	fi
	@for host in $(WORK_SET); do \
		ip=$$(grep -w "^$$host" docs/cluster-ips.txt | cut -f2); \
		if [ -z "$$ip" ]; then \
			echo "==> SKIP $$host (no IP recorded yet)"; \
			continue; \
		fi; \
		scripts/smoke-test.sh $$host $$ip || exit 1; \
	done
	@echo "==> All recorded WORK_SET hosts passed smoke-test."

# T007 — Build, switch, smoke-test, auto-rollback on smoke-test failure.
canary:
ifndef HOST
	$(error HOST is not set. Usage: make canary HOST=hlc-501 IP=10.23.50.51)
endif
ifndef IP
	$(error IP is not set. Usage: make canary HOST=hlc-501 IP=10.23.50.51)
endif
	@if echo "$(DECOM_SET)" | grep -wq "$(HOST)"; then \
		echo "REFUSED: $(HOST) is in DECOM_SET. Canary forbidden."; \
		exit 1; \
	fi
	@echo "==> canary $(HOST) @ $(IP): build"
	@$(MAKE) --no-print-directory build HOST=$(HOST)
	@echo "==> canary $(HOST) @ $(IP): switch"
	@nixos-rebuild switch --flake .#$(HOST) --target-host bob@$(IP) --use-remote-sudo || \
		{ echo "switch failed; system unchanged"; exit 1; }
	@echo "==> canary $(HOST) @ $(IP): smoke-test"
	@if ! scripts/smoke-test.sh $(HOST) $(IP); then \
		echo "==> smoke-test FAILED — auto-rollback"; \
		nixos-rebuild switch --rollback --flake .#$(HOST) --target-host bob@$(IP) --use-remote-sudo; \
		exit 1; \
	fi
	@echo "==> canary $(HOST) @ $(IP): green"

# T008 — Manual rollback (no forward switch first).
rollback:
ifndef HOST
	$(error HOST is not set. Usage: make rollback HOST=hlc-501 IP=10.23.50.51)
endif
ifndef IP
	$(error IP is not set. Usage: make rollback HOST=hlc-501 IP=10.23.50.51)
endif
	nixos-rebuild switch --rollback --flake .#$(HOST) --target-host bob@$(IP) --use-remote-sudo
	@scripts/smoke-test.sh $(HOST) $(IP)

# T009 — Print recorded IP for HOST from docs/cluster-ips.txt.
ip:
ifndef HOST
	$(error HOST is not set. Usage: make ip HOST=hlc-501)
endif
	@grep -w "^$(HOST)" docs/cluster-ips.txt | cut -f2
