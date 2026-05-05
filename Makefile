NIX_FLAGS   := --extra-experimental-features 'nix-command flakes'
HLC_DOMAIN  ?= marks.dev

.PHONY: build-image flash-image silicon-dry silicon-switch update \
        dry-run build smoke-test ip \
        provision provision-stage1 provision-mount provision-stage2 \
        update-node rollback help

# Derive IP from HOST via hlc-VNN → 10.23.50.(V*10+N) convention.
# count ≤ 9:  octet = V*10+N  (e.g. hlc-501 → 51)
# count 10-19: octet = 100+V*10+(N mod 10)
# Override for non-standard situations: IP=<addr> make target HOST=<host>
_DERIVED_IP = $(shell echo '$(HOST)' | awk -F- 'NF==2 {v=substr($$2,1,1)+0; n=substr($$2,2)+0; if(n<=9) print "10.23.50."v*10+n; else print "10.23.50."100+v*10+n%10}')
IP ?= $(_DERIVED_IP)

# Decommissioned set — these hosts dry-run and build only; no live-node ops
DECOM_HOSTS := hlc-402 hlc-403 hlc-404

define check_decom
	@if echo '$(DECOM_HOSTS)' | tr ' ' '\n' | grep -qx '$(HOST)'; then \
		echo "ERROR: $(HOST) is in the decommissioned set — live-node targets are not permitted."; \
		exit 1; \
	fi
endef

help:
	@echo "Targets:"
	@echo "  build-image HOST=<host> [REBUILD=1]      Build SD card image for a pi node"
	@echo "  flash-image HOST=<host> DEV=<dev>         Flash built image to SD card device"
	@echo "  silicon-dry                               Dry-run NixOS config for silicon"
	@echo "  silicon-switch                            Apply NixOS config for silicon"
	@echo "  update                                    Update all flake inputs"
	@echo "  dry-run HOST=<host>                       Dry-run toplevel for a cluster host"
	@echo "  build HOST=<host>                         Build toplevel for a cluster host"
	@echo "  smoke-test HOST=<host>                    SSH reachability check via FQDN"
	@echo "  ip HOST=<host>                            Print derived IP for a host"
	@echo "  provision HOST=<host>                    Full provision (stage1 + mount + stage2)"
	@echo "  provision-stage1 HOST=<host>             disko: partition + format + mount disks"
	@echo "  provision-mount HOST=<host>              Mount /boot/firmware (W-011)"
	@echo "  provision-stage2 HOST=<host>             Install NixOS + bootloader + reboot"
	@echo "  update-node HOST=<host> [IP=<ip>]        Deploy config update to a provisioned node"
	@echo "  rollback HOST=<host> [IP=<ip>]           Roll back to prior NixOS generation"

ifdef REBUILD
_REBUILD_FLAG := --rebuild
endif

build-image:
ifndef HOST
	$(error HOST is not set. Usage: make build-image HOST=hlc-501)
endif
	time nix build $(NIX_FLAGS) \
		.#packages.aarch64-linux.$(HOST)-sdImage \
		$(_REBUILD_FLAG) \
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

# Phase 2 Foundational targets —————————————————————————————————————————————

dry-run:
ifndef HOST
	$(error HOST is not set. Usage: make dry-run HOST=hlc-501)
endif
	nix build $(NIX_FLAGS) \
		.#nixosConfigurations.$(HOST).config.system.build.toplevel \
		--dry-run -L

build:
ifndef HOST
	$(error HOST is not set. Usage: make build HOST=hlc-501)
endif
	nix build $(NIX_FLAGS) \
		.#nixosConfigurations.$(HOST).config.system.build.toplevel \
		-L

smoke-test:
ifndef HOST
	$(error HOST is not set. Usage: make smoke-test HOST=hlc-501)
endif
	$(call check_decom)
	@echo "==> smoke-test $(HOST)"
	@echo "--- ping $(IP)"
	ping -c 1 -W 3 $(IP)
	@echo "--- purge known_hosts for $(HOST).$(HLC_DOMAIN) and $(IP)"
	@ssh-keygen -R $(HOST).$(HLC_DOMAIN) 2>/dev/null || true
	@ssh-keygen -R $(IP) 2>/dev/null || true
	@echo "--- ssh to $(HOST).$(HLC_DOMAIN)"
	ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 bob@$(HOST).$(HLC_DOMAIN) uname -a
	@echo "==> smoke-test PASS: $(HOST)"

ip:
ifndef HOST
	$(error HOST is not set. Usage: make ip HOST=hlc-501)
endif
	@if [ -z '$(IP)' ]; then echo "ERROR: cannot derive IP for HOST=$(HOST)" >&2; exit 1; fi
	@echo $(IP)

# Phase 5–6 (US3–US4) targets ————————————————————————————————————————————————

provision: provision-stage1 provision-mount provision-stage2

provision-stage1:
ifndef HOST
	$(error HOST is not set. Usage: make provision HOST=hlc-501)
endif
	$(call check_decom)
	@echo "==> provision-stage1 $(HOST): disko (partition + format + mount)"
	# W-010: --phases skips kexec (fails on Pi vendor kernel 6.12.x)
	# W-012: mdadm resync stopped by udev rule in modules/sd/bootstrap.nix
	nix run $(NIX_FLAGS) github:nix-community/nixos-anywhere -- \
		--flake .#$(HOST) \
		--target-host bob@$(HOST).$(HLC_DOMAIN) \
		--disko-mode disko \
		--phases disko

provision-mount:
ifndef HOST
	$(error HOST is not set. Usage: make provision HOST=hlc-501)
endif
	$(call check_decom)
	@echo "==> provision-mount $(HOST): mount firmware partition"
	# W-011: nixos-anywhere does not mount pre-existing filesystems absent from the
	# disko schema before the bootloader phase. The Pi firmware bootloader installer
	# (nixos-generations-builder.sh) requires /boot/firmware to be mounted before it
	# can copy firmware files. Mount mmcblk0p1 here so the install phase finds it.
	ssh root@$(HOST).$(HLC_DOMAIN) \
		"mkdir -p /mnt/boot/firmware && mount /dev/mmcblk0p1 /mnt/boot/firmware"

provision-stage2:
ifndef HOST
	$(error HOST is not set. Usage: make provision HOST=hlc-501)
endif
	$(call check_decom)
	@echo "==> provision-stage2 $(HOST): install NixOS + bootloader + reboot"
	nix run $(NIX_FLAGS) github:nix-community/nixos-anywhere -- \
		--flake .#$(HOST) \
		--target-host bob@$(HOST).$(HLC_DOMAIN) \
		--disko-mode disko \
		--phases install,reboot

update-node:
ifndef HOST
	$(error HOST is not set. Usage: make update-node HOST=hlc-501)
endif
	$(call check_decom)
	@echo "==> update-node $(HOST) at $(IP)"
	sudo nixos-rebuild switch --flake .#$(HOST) \
		--target-host bob@$(IP)

rollback:
ifndef HOST
	$(error HOST is not set. Usage: make rollback HOST=hlc-501)
endif
	$(call check_decom)
	@echo "==> rollback $(HOST) at $(IP)"
	sudo nixos-rebuild --rollback --flake .#$(HOST) \
		--target-host bob@$(IP) \
		--use-remote-sudo

