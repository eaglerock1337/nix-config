NIX_FLAGS   := --extra-experimental-features 'nix-command flakes'
HLC_DOMAIN  ?= marks.dev

.PHONY: build-image flash-image local-dry local-switch update \
        dry-run build smoke-test ip \
        provision provision-stage1 provision-mount provision-stage2 \
        provision-stage3 provision-reinstall \
        reprovision reprovision-stage1 \
        update-node rollback help

# Derive IP from HOST via hlc-VNN → 10.23.50.(V*10+N) convention.
# count ≤ 9:  octet = V*10+N  (e.g. hlc-501 → 51)
# count 10-19: octet = 100+V*10+(N mod 10)
# Override for non-standard situations: IP=<addr> make target HOST=<host>
_DERIVED_IP = $(shell echo '$(HOST)' | awk -F- 'NF==2 {v=substr($$2,1,1)+0; n=substr($$2,2)+0; if(n<=9) print "10.23.50."v*10+n; else print "10.23.50."100+v*10+n%10}')
IP ?= $(_DERIVED_IP)

# Decommissioned set — these hosts dry-run and build only; no live-node ops
DECOM_HOSTS := hlc-402 hlc-403 hlc-404 hlc-507

define check_decom
	@if echo '$(DECOM_HOSTS)' | tr ' ' '\n' | grep -qx '$(HOST)'; then \
		echo "ERROR: $(HOST) is in the decommissioned set — live-node targets are not permitted."; \
		exit 1; \
	fi
endef

# Abort if root filesystem is on md OR any md array is assembled.
# Uses output comparison — SSH failure (empty output) also aborts (fail-safe).
define check_raid_clear
	@echo "==> pre-flight: checking $(HOST) has no RAID (root device or assembled array)"
	@raid_status=$$(ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 \
		bob@$(HOST).$(HLC_DOMAIN) \
		'{ df / | grep -q /dev/md || grep -q "^md[0-9]" /proc/mdstat; } && echo RAID || echo CLEAR' \
		2>/dev/null); \
	if [ "$$raid_status" != "CLEAR" ]; then \
		echo "ERROR: $(HOST) has active RAID or md root filesystem — live provisioned node detected."; \
		echo "       Boot from SD card before provisioning, or use 'make rollback HOST=$(HOST)'."; \
		exit 1; \
	fi
endef

help:
	@echo "Targets:"
	@echo "  build-image HOST=<host> [REBUILD=1]      Build SD card image for a pi node"
	@echo "  flash-image HOST=<host> DEV=<dev>         Flash built image to SD card device"
	@echo "  local-dry                                 Dry-run NixOS config for local host"
	@echo "  local-switch                              Apply NixOS config for local host"
	@echo "  update                                    Update all flake inputs"
	@echo "  dry-run HOST=<host>                       Dry-run toplevel for a cluster host"
	@echo "  build HOST=<host>                         Build toplevel for a cluster host"
	@echo "  smoke-test HOST=<host>                    SSH reachability check via FQDN"
	@echo "  ip HOST=<host>                            Print derived IP for a host"
	@echo "  provision HOST=<host>                    Two-phase provision (stage1-3 + smoke-tests)"
	@echo "  provision-stage1 HOST=<host>             disko: partition + format + mount disks"
	@echo "  provision-mount HOST=<host>              Mount /boot/firmware (W-011)"
	@echo "  provision-stage2 HOST=<host>             Install provision-minimal config + reboot"
	@echo "  provision-stage3 HOST=<host>             Wait for reboot + push full config"
	@echo "  provision-reinstall HOST=<host>          RAID-retry: skip disko, reinstall + full config"
	@echo "  reprovision HOST=<host>                  Reprovision USB RAID; preserve NVMe /srv data"
	@echo "  reprovision-stage1 HOST=<host>           disko USB RAID only (NVMe skipped)"
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

local-dry:
	sudo nixos-rebuild dry-run --flake .#$$(hostname)

local-switch:
	sudo nixos-rebuild switch --flake .#$$(hostname)

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

# Two-phase provision (R-016): stage2 installs provision-minimal config (small
# closure); stage3 pushes the full config via update-node (differential nix copy).
provision: provision-stage1 provision-mount provision-stage2
	@echo "==> mid-provision smoke-test $(HOST)"
	$(MAKE) smoke-test HOST=$(HOST)
	@echo "==> provision-stage3 $(HOST): pushing full config"
	$(MAKE) provision-stage3 HOST=$(HOST)
	@echo "==> final smoke-test $(HOST)"
	$(MAKE) smoke-test HOST=$(HOST)

provision-stage1:
ifndef HOST
	$(error HOST is not set. Usage: make provision HOST=hlc-501)
endif
	$(call check_decom)
	$(call check_raid_clear)
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
	@echo "==> provision-stage2 $(HOST): install provision-minimal config + bootloader + reboot"
	# R-016: use -provision flake output (small closure) for reliable copy to SD-booted Pi
	nix run $(NIX_FLAGS) github:nix-community/nixos-anywhere -- \
		--flake .#$(HOST)-provision \
		--target-host bob@$(HOST).$(HLC_DOMAIN) \
		--disko-mode disko \
		--phases install,reboot

provision-stage3:
ifndef HOST
	$(error HOST is not set. Usage: make provision-stage3 HOST=hlc-501)
endif
	$(call check_decom)
	@echo "==> provision-stage3 $(HOST): waiting for reboot then pushing full config"
	@echo "--- waiting for $(HOST) to come back online..."
	@waited=0; while [ $$waited -lt 120 ]; do \
		if ping -c 1 -W 2 $(IP) >/dev/null 2>&1 && \
		   ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 bob@$(IP) true 2>/dev/null; then \
			echo "--- $(HOST) is online after $${waited}s"; \
			break; \
		fi; \
		sleep 5; \
		waited=$$((waited + 5)); \
	done; \
	if [ $$waited -ge 120 ]; then \
		echo "ERROR: $(HOST) did not come back online within 120s"; \
		exit 1; \
	fi
	@echo "--- pushing full config via update-node"
	$(MAKE) update-node HOST=$(HOST)

reprovision: reprovision-stage1 provision-mount provision-stage2
	@echo "==> mid-reprovision smoke-test $(HOST)"
	$(MAKE) smoke-test HOST=$(HOST)
	@echo "==> reprovision-stage3 $(HOST): pushing full config"
	$(MAKE) provision-stage3 HOST=$(HOST)
	@echo "==> final reprovision smoke-test $(HOST)"
	$(MAKE) smoke-test HOST=$(HOST)

reprovision-stage1:
ifndef HOST
	$(error HOST is not set. Usage: make reprovision HOST=hlc-501)
endif
	$(call check_decom)
	$(call check_raid_clear)
	@echo "==> reprovision-stage1 $(HOST): disko USB RAID only (NVMe at /srv preserved)"
	# Uses $(HOST)-bare flake output: skipNvmeFormat=true excludes NVMe from disko.
	# Install phase (provision-stage2) uses full .#$(HOST) config so fstab includes /srv.
	# W-010, W-012 apply here as for provision-stage1.
	nix run $(NIX_FLAGS) github:nix-community/nixos-anywhere -- \
		--flake .#$(HOST)-bare \
		--target-host bob@$(HOST).$(HLC_DOMAIN) \
		--disko-mode disko \
		--phases disko

update-node:
ifndef HOST
	$(error HOST is not set. Usage: make update-node HOST=hlc-501)
endif
	$(call check_decom)
	@echo "==> update-node $(HOST) at $(IP)"
	# gibson has no nixos-rebuild; build locally, copy closure, activate remotely.
	# Requires bob in nix.settings.trusted-users on the target (set in hlc/default.nix).
	nix build $(NIX_FLAGS) \
		.#nixosConfigurations.$(HOST).config.system.build.toplevel -L \
	&& TOPLEVEL=$$(readlink -f result) \
	&& echo "==> Copying closure to $(HOST)..." \
	&& nix copy $(NIX_FLAGS) --no-check-sigs --to ssh-ng://bob@$(IP) $$TOPLEVEL \
	&& echo "==> Activating on $(HOST)..." \
	&& ssh bob@$(IP) "sudo nix-env -p /nix/var/nix/profiles/system --set $$TOPLEVEL" \
	&& ssh bob@$(IP) "sudo $$TOPLEVEL/bin/switch-to-configuration switch"

provision-reinstall:
ifndef HOST
	$(error HOST is not set. Usage: make provision-reinstall HOST=hlc-501)
endif
	$(call check_decom)
	@echo "==> provision-reinstall $(HOST): RAID-retry (disko already done, install failed)"
	@# Pre-flight: verify RAID exists but root is NOT md-backed (SD-booted after failed install)
	@raid_status=$$(ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 \
		bob@$(HOST).$(HLC_DOMAIN) \
		'root_md=0; raid_exists=0; \
		 df / | grep -q /dev/md && root_md=1; \
		 grep -q "^md[0-9]" /proc/mdstat 2>/dev/null && raid_exists=1; \
		 if [ "$$root_md" = "1" ]; then echo MD_ROOT; \
		 elif [ "$$raid_exists" = "1" ]; then echo RAID_EXISTS; \
		 else echo NO_RAID; fi' \
		2>/dev/null); \
	if [ "$$raid_status" = "MD_ROOT" ]; then \
		echo "ERROR: $(HOST) has md-backed root — use make update-node instead."; \
		exit 1; \
	elif [ "$$raid_status" = "NO_RAID" ]; then \
		echo "ERROR: $(HOST) has no RAID array — use make provision instead."; \
		exit 1; \
	elif [ "$$raid_status" != "RAID_EXISTS" ]; then \
		echo "ERROR: could not determine RAID status for $(HOST) (SSH failure?)."; \
		exit 1; \
	fi
	@echo "--- RAID exists, root is SD — proceeding with reinstall"
	$(MAKE) provision-mount HOST=$(HOST)
	$(MAKE) provision-stage2 HOST=$(HOST)
	@echo "==> mid-reinstall smoke-test $(HOST)"
	$(MAKE) smoke-test HOST=$(HOST)
	@echo "==> reinstall stage3: pushing full config"
	$(MAKE) provision-stage3 HOST=$(HOST)
	@echo "==> final reinstall smoke-test $(HOST)"
	$(MAKE) smoke-test HOST=$(HOST)

rollback:
ifndef HOST
	$(error HOST is not set. Usage: make rollback HOST=hlc-501)
endif
	$(call check_decom)
	@echo "==> rollback $(HOST) at $(IP)"
	# Roll back to the previous NixOS generation on the remote node.
	ssh bob@$(IP) "sudo nix-env --rollback -p /nix/var/nix/profiles/system"
	ssh bob@$(IP) "sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch"

