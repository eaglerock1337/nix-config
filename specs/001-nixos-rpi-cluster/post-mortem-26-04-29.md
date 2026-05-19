# 4/29/26 Post-Mortem

This post-mortem is to discuss the issues surrounding the attempt to handle the first step of the spec, the issues with the debug session, and to give appropriate context for redesigning the spec and the plan from scratch as well as for listing action-items to be taken for further research.

## Incident Overview

The incident over the weekend on 4/25 and 4/26. In short, the first attempt to implement the plan and first tasks failed upon the first attempt of flashing the SD card and booting up an rpi. The entire weekend was wasted debugging the issues and no progress was made over the weekend. The days following, the project coordinator (me, Peter) did solo research and found the original setup prior to Claude involvement was working, unlike the current branch work. Key bad assumptions and root causes were found.

### Incident Timeline

- Week of 4/20
  - spec-kit onboarded to `nix-config` repo
  - work started on consitution and first spec + plans
  - deliberations, clarifications, refining of tasklist
- Friday, 4/24
  - First attempt of implementing `TASKS.md`
  - First attempt of flashing SD card
  - Failure to login was detected
- Saturday, 4/25
  - Debugging sessions started
  - Multiple changes, tests, and fixes tested to no avail
  - Occasional success logging in (e.g. from Silicon through Gibson)
  - PS1 issues discovered
  - Removal of modules from HLC node for debugging
  - Same failures persisted
- Sunday, 4/26
  - Resumption of debugging
  - No change in login behavior despite many steps
  - Peter flagged potential remediatory steps which were ignored
  - Critically, looking into the flashing process was ignored
  - Final debugging attempts disabled network connectivity completely for nodes
  - Give up here, angry and cursing.

### Follow-up research

I have taken the liberty to follow-up on this alone to determine what was wrong and have multiple findings:

- `build-image` `Makefile` step issues
  - After calling out the the potential for the changes to still be in the SD image, Claude assumed the operator didn't build the image, despite me doing so
  - Researching, I found the `--rebuild` step was necessary for the image to be rebuilt as expected
- Reverting of project to `main`
  - Once I determined the issue with the image build process, I retried my baseline
  - Flashing the SD card off of the `main` branch still works perfectly
- Use of the incorrect project
  - The `nix-community` version of `nixos-raspberrypi` is archived and has not been worked on for some time
  - One NixOS maintainer, `nvmd`, has continued work on the project and is actively involved in getting rpi5 support to maturity on NixOS
  - This was clearly documented in the NixOS Wiki, which was provided to Claude as part of its research to work with
- Incorrect agent behavior
  - The agent consistently assumed what the operator was saying was wrong and attempted to provide proof of such
  - This delayed the detection of the Makefile build issues as well
  - These bad assumptions cost days of development time and aggravation

### Root Cause

The following have been determined to be the root cause of the project issues over the weekend:

- Assuming the operator was wrong when he was empirically correct
- Claude going off on assumptions despite being asked not to
- The wrong `build-image` command causing bad assumptions to the debugging process (e.g. the image never removed the faulty PS1 despite being configured as such)
- The wrong project being used for getting NixOS installed on Raspberry Pi
- Upstream NixOS Wiki steps being ignored, despite them being the most up-to-date and accurate documentation
- Not listening to the operator during debugging on where to look into issues

## Background

The following is some background knowledge germane to the project which should be considered the most up-to-date and accurate description of the project and the network it will be running on.

### Happy Little Cloud Project History

#### HLC mk1

The project was originally started before the year 2020, with 6 Raspberry Pi 3's being used in a small cluster enclosure, and included a USB power supply, 8-port switch, and mini Wifi Router/Gateway using OpenWRT. The intended persistent storage was to be a single 64GB USB drive plugged directly into the router and shared over the network. Kubernetes was installed using `microk8s` on Ubuntu.

The project never held any real workloads. The only project that ran on it was a simple deployment called `hlc-blinky` which caused the LED lights on the Pis to flash, and was used as a basic demonstration of scaling up and down a deployment on Kubernetes. No further work was done.

#### HLC mk2

The second iteration of the project brought us much closer to the current configuration. This introduced the NavePoint short-depth, wall-mounted server rack as well as the 12-bay 2U Raspberry Pi Chassis. To the 6 rpis, 2 more Pi3s and 4 Pi4's were added to fill out the cluster.

The tech stack was switched to using `k3s` and using Debian as the baseline image. Ansible playbooks were used to semi-automate the Pi provisoning once they were on the network. Kubernetes was installed using k3s with the Pi4's acting as control+worker nodes handling embedded etcd.

ArgoCD was installed on the cluster and Helm charts for different stateless services were successfully implemented on this version of the cluster and are still running today. Storage with an external HDD failed as the Pi3's did not have the ability to power these drives and I didn't have room to provision USB.

#### HLC mk3 (prior to this work)

The third version of the cluster was to include the current setup (4 pi4's, 8 pi5's) and introduce USB3 drives on every node, as well as nvme SSDs on each pi5. The project was stymied by a lack of support for Raspberry Pi 5's in any distribution I wanted to run. I put the project side until I found out about NixOS and started working on setting up Silicon. Afterwards, I found documenation that supported running NixOS on the Pi5's using the vendor kernel, which sparked this project and spec.

### Network Setup

The network that the HLC works around is a small home network using Unifi hardware (Dream Machine SE and Switch Pro 48). The following VLANs are configured:

> NOTE: All VLANs except for the default are hosted on the Switch Pro 48 to take advantage of layer-3 connectivity and the switches intra-vlan routing. The Default network is the main network for now, but the eventual goal will be to switch to the main network as the primary VLAN.

- 1 (Default) - 10.23.1.0/24 (Residing on the DMSE, as opposed to the rest on the switch)
- 40 (Guest Network) - 10.23.40.0/24 (Guest network for basic, segregated Internet connectivity)
- 42 (Main Network) - 10.23.42.0/24 (Currently unused and will eventually replace VLAN 1)
- 44 (IoTrashfire) - 10.23.44.0/24 (Segregated network strictly for IoT devices)
- 50 (marks.dev) - 10.23.50.0/24 (Happy Little Cloud's network)
- 52 (eagleworld.net) 10.23.52.0/24 (Future network for the Ecto-1 Cluster)

#### Important Devices

The following devices are important to know about in context of this project:

- Gibson - 10.23.1.150 - Primary desktop + gaming machine, port is tagged on VLANs 50 & 52
  - Gibson is the primary DMZ between the user network and the server networks
  - When working via other systems (e.g. Silicon), I first make a jump through Gibson for connectivity and security
- Pihole - 10.23.1.120 - Pi Hole - Local DNS for the network, reachable across all servers
  - Reachable by VLAN50, but not over port 53 yet
  - Will eventually be the primary DNS server, but need local hosts files to compensate for now
  - This will change once the main network migration is complete, as VLAN rules will be carvable across the Switch Pro 48
- Dream Machine - 10.23.1.1 - Network router
  - Usable as a DNS server at this address for upstream DNS short term
  - Should have basic entries for server FQDNs (e.g. hlc-501.marks.dev will resolve even if hlc-501 does not)

## North Star

As a refresher and a definitive list of goals, this is the new north star goal of the current project and spec:

### System State

- 9 Raspberry Pis (hlc-401 and all 8 pi5s) up and running on NixOS using `nvmd` fork of `nixos-raspberrypi`
- Baseline service user setup (`bob`) with debugging utilities, custom PS1, and vital programs
- All necessary programs for being part of a `k3s`-provisoned Kubernetes cluster
- Partitioning scheme:
  - `/boot` on rpi SD card
  - `/` on md-based RAID-1 across both 64GB USB3 drives
  - `/srv/ssd` on 1TB nvme SSD
- Boot scheme:
  - Should boot to USB drives if available
  - If USB unavailable:
    - Fall back to SD card in case of issues (e.g. for mdadm disk recovery)
    - The basic liveUSB environment part of SD card imaging works perfect for this
    - Some basic utilities should be added (e.g. mdadm) on top of the basic user config
- Cluster Storage should be usable by storage provisioner (either Longhorn, OpenEBS, or equivalent) at the following paths:
  - `/srv/ssd` - Primary nvme m.2 storage - `1TB`
    - To be used for most standard workloads, replicated cross-node
  - `/srv/usb` - Pre-replicated storage on USB3 RAID array (mounted via /)
    - To be used for databases and other specialized workloads as-needed

### Operator Workflow

The following should be the full workflow for provisioning a node for HLC:

- On Gibson, ensure repo is updated per standard `git` practices
- Run `make flash-image` for the appropriate host and SD card device
- Remove SD card, physically insert into the rpi, and plug-in rpi for initial boot
- Back on Gibson, ensure the node is online via `make smoke-test`
- On the host itself, ensure the physical devices have proper labels
- Run `nixos-anywhere` command (either on Gibson or the host) to install NixOS on the necessary disks (using `disko` and other necessary parts of the stack)
- After provisioning, the system should now be ready to log in to and immediately start working with `k3s` with all necessary nix packages installed.
- Operator to take over with hand-provisioning of nodes and replicating the existing cluster on hlc-40

## Out of Scope

To refine the process and simplify, the following should be considered out of spec, either removed from this project or to be handled elsewhere

- Automation of joining and provisioning of the cluster (to be handled in a future spec)
- Updating of Kuberenetes or other k3s-based management (to be handled in a future spec)
- Consideration of network VLAN migration (only relevant when other work is done elsewhere)
- Management of ArgoCD or server workloads (handled by happy-little-cloud repo)
- Duplication of existing cluster on hlc-402, hlc-403, and hlc-404 and cutover (to be handled by next spec)
- Any specific configs for the ecto-1 cluster (all that's required for now is that the new filesystem structure supports its future addition)

## Restarting

The process should be completely revamped, starting with redesigning the spec and the first state of cluster operations. The following is a high-level plan of the work that we need to do to reach a completed state of Spec 001:

### Phase 1 - New baseline on correct upstream project

- Restoration of existing code to baseline `main` branch before working again
- Setting up of necessary Claude skills/hooks/context to optimize spec-kit workflows and install guardrails to mitigate future issues
- Switching to use of the proper `nvmd` fork of `nixos-raspberrypi` on the `main` branch and duplicating the existing hlc-501 setup
- Setting up the SD card provisioning and updating the Makefile to the workflow supported by `nvmd`
  - SD card provisioning should ONLY include the most basic utilities going forward, not custom configuration
- Operator to validate SD card by flashing hlc-501 and testing node comes online as expected

### Phase 2 - Project scaffolding

- Set up scaffolding of project to support generic server cluster configs as well as HLC-specific configs (and be ready to work with ecto-1 specific configs in the future)
- Set up all 12 rpi definitions (only 9 to be used for now before cutover) in deduplicated fashion
- Set up modules for scoped configs that can be modularly pulled in appropriate for each user
- Set up home-manager configs for server users and modularlize existing configs to allow for standardization across certain parts of the configs (and keeping workstation-specific/i3 environment stuff separate)
- Set up `configuration.txt` files for each node, but only keep node-specific configs there
- `flake.nix` configs should include minimal top-level inclusions (`configuration.txt`, cluster-specific configs, and device-specific configs), with later modules included in the appropriate top-level module
- SD card configuration to be kept separate with its own barebones configuration specifically for bootstrapping/troubleshooting
- Operator to validate in two ways:
  - Appropriate nixos-rebuild switch commands executed remotely from Gibson or locally on the node
  - Fresh provisioning of another node (e.g. hlc-502) via SD and subsequent setup

### Phase 3 - Raspberry Pi 4 onboarding

- Onboarding of Raspberry Pi 4's should be added to the project
- Add appropriate modules for rpi4-specific hardware configuration
- Ensure both rpi4s and rpi5s are fully supported in the new setup
- Operator to validate by flashing SD card and bootstrapping hlc-401, ensuring it comes online as expected

### Phase 4 - Set up nixos-anywhere provisioning

- Develop a system for provisoning nodes from baseline SD card configuration using `nixos-anywhere` and `disko` for disk imaging
- This should configure the md-based RAID-1 array on the USB3 drives
- Appropriate filesystems should be chosen for optimizing its use-case
- The nix install should now boot to the USB disks with the nvme disk mounted under /srv/ssd, but fall back to the SD card for troubleshooting if there was a filesystem issue (not sure how to do this in a headless fashion without access to grub)
- Operator to validate both rpi4 and rpi5 configs in two ways:
  - Provisioning of previous node on the network
  - Fresh provisioning of new system via fresh SD card

### Phase 5 - Basic system setup

- Set up a standard PS1 and `bash` shell environment that is shared with Silicon and workstations to create a uniform workflow across all NixOS nodes
- I would like the PS1 to be stylized with something small but HLC-inspired (similar to Silicon's `////` text inspired by the ZX Spectrum). If we can't come up with something, let's default to the Silicon PS1
- PS1 should look different depending on if the system is remote-accessed or if it is local (again, similar to Silicon)
- Set up a dynamic MOTD for each server node that should end up looking exactly as follows (hlc-401 as an example):

  ```bash
  ##########################################
  #             __  ____    ______         #
  #            / / / / /   / ____/         #
  #           / /_/ / /   / /              #
  #          / __  / /___/ /___            #
  #         /_/ /_/_____/\____/            #
  #                                        #
  #          "Happy Little Cloud"          #
  #                                        #
  ##########################################

        Cluster node: hlc-401.marks.dev

  "Let's build just a happy little cloud."
                                  ~ Bob Ross
  ```

- Set up a sysadmin toolbox for remote management of the cluster with standard command-line utilities. These utilities should be kept in their own separate file and included on ALL NixOS nodes (including Silicon). Each package should have an inline comment describing its purpose for troubleshooting purposes (for quick operator reference by browsing the nix modules).
- Set up home manager configs giving sensible defaults to the different applications. For example, a neovim config will probably be good to include, as well as other recommended application dotfiles. These should be shared with workstations as well.
- Operator to validate rpi4 and rpi5 configs as well as on both existing and new server setups to ensure both workflows are working

### Phase 6 - Kubernetes and k3s prerequisities

- Add generic cluster configurations for setting up Kubernetes and k3s, including all necessary dependencies (e.g. Docker)
- Ensure useful debugging tools (e.g. k9s) are provided for local and remote server management
- Convenient `k` shortcut for `kubectl` commands setup (use the official Kubernetes documentation)
- Operator to validate on both pi versions and existing/new setups as above

## Important Research/Context

The following are vital findings from the post-mortem that should be highlighted as important for this project and the repo as a whole:

- The Official NixOS Wiki:
  - [NixOS on ARM](https://nixos.wiki/wiki/NixOS_on_ARM)
  - [NixOS on Rpi4](https://nixos.wiki/wiki/NixOS_on_ARM/Raspberry_Pi_4)
  - [NixOS on Rpi5](https://nixos.wiki/wiki/NixOS_on_ARM/Raspberry_Pi_5)
  - NOTE: these do not mention the latest `nvmd` fork of NixOS but provide valuable context
- [The `nvmd` fork of `nixos-anywhere` with the latest findings](https://github.com/nvmd/nixos-raspberrypi/)
  - This repo includes the latest documentation in `README.md` on its `develop` branch
  - This repo should be considered the upstream source-of-truth with regards to setting up rpis
  - The `main` branch is what is recommended to use for provisioning workloads
- [spec-kit repo](https://github.com/github/spec-kit)
  - Contains valuable context on spec-kit and for help with optimizing workflows
- [Claude Code best practices](https://code.claude.com/docs/en/best-practices)
  - Useful context for determining how to optimize performance as well as minimizing token usage

## Action Items

The following are action items that should be taken by Claude prior to the resumption of the plan design, as these are outstanding questions and concerns regarding the procedures of using spec-kit as well as resuming the plan to get the cluster on NixOS:

- [ ] Clarify the best command to use when debugging issues as part of the spec-kit ecosystem and workflow (is it /debug or something else?)
- [ ] Research in detail the best procedure for setting up SD images using the `nvmd` fork of `nixos-raspberrypi`. The SD should be barebones configuration with just enough provisioning to get on the network (`bob` user with ssh key _should_ be enough). Some things to consider:
  - The best way to leverage caching available
  - How to replicate the sd card flash process currently used with the `nix-community` setup
- [ ] Research the utilization of home-manager and how it can be best integreated into the server setup. Server users (both `bob` and `slimer` in the future, just `bob` for now) should have a comprehensive `bash` shell for operatator usage and should have sensible configuratons for all necessary tools.
- [ ] Research the times when it is appropriate to use `--rebuild` as part of `nix build` and when it is not. It appears as though caching will ignore changes to the repo without the rebuild step, but defaulting to it could ,ake for extra unnecessary building upon project maturity.
- [ ] Research the necessary hardware/firmware configuration needed (e.g. for `config.txt`). Heatsinks are installed on the rpi4s and official heatsink+fan for the rpi5s to enable overclocking.
- [ ] Identify which Claude resources (skills, hooks, etc.) should be considered as part of the workflow to refine the future work loop.
- [ ] Determine the recommended spec-kit workflow for best handling the project moving forward.
