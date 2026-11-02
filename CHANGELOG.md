# Changelog

## [0.4.0](https://github.com/nixos-contrib/nix-boxes/compare/v0.3.0...v0.4.0) (2026-11-02)


### Features

* add Parallels Desktop Vagrant box ([#2](https://github.com/nixos-contrib/nix-boxes/issues/2)) ([5e41183](https://github.com/nixos-contrib/nix-boxes/commit/5e411838a20ca200b46574843cacdf458e0a8c7e))


### Bug Fixes

* **vmware:** a USB keyboard and mouse for the GUI window ([a5a8c53](https://github.com/nixos-contrib/nix-boxes/commit/a5a8c533428fa03c122c8ed78cc613226541757a))

## [0.3.0](https://github.com/nixos-contrib/nix-boxes/compare/v0.2.0...v0.3.0) (2026-11-01)


### Features

* publish a Vagrant catalog of each box, so that vagrant box update works ([bad5c5b](https://github.com/nixos-contrib/nix-boxes/commit/bad5c5b49d88e808513b645bff047d40a177440a))
* **vmware:** grow the box disk to 40 GiB after the build ([7fb74dd](https://github.com/nixos-contrib/nix-boxes/commit/7fb74dda957c0267ab3d66823f401e5a9bfe5ba7))


### Bug Fixes

* make a first vagrant up of the VMware box finish on NixOS ([#9](https://github.com/nixos-contrib/nix-boxes/issues/9)) ([ee81698](https://github.com/nixos-contrib/nix-boxes/commit/ee81698319f5747da0727edf6ce08682b863da24))
* make the VMware box start and clone on Fusion ([#6](https://github.com/nixos-contrib/nix-boxes/issues/6)) ([085ebd6](https://github.com/nixos-contrib/nix-boxes/commit/085ebd6baeae145ca9ea6b32af7dd7a6d543cc3e))

## [0.2.0](https://github.com/nixos-contrib/nix-boxes/compare/v0.1.0...v0.2.0) (2026-11-01)


### Features

* disable the firewall in the boxes by default ([#4](https://github.com/nixos-contrib/nix-boxes/issues/4)) ([c321139](https://github.com/nixos-contrib/nix-boxes/commit/c321139f5f075a5053a5df561755d1d7151c1933))

## 0.1.0 (2026-11-01)


### Features

* add VMware Fusion Vagrant box ([6a2d429](https://github.com/nixos-contrib/nix-boxes/commit/6a2d42950eb62f0d2cbb54bc65784a5c72928fad))


### Bug Fixes

* copy the VMDK by name into the vmware box ([759f9b7](https://github.com/nixos-contrib/nix-boxes/commit/759f9b711a3548d94dd2c7e738fc443ec8ac2633))
