# nix-boxes

[![CI](https://github.com/nixos-contrib/nix-boxes/actions/workflows/ci.yml/badge.svg)](https://github.com/nixos-contrib/nix-boxes/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/nixos-contrib/nix-boxes)](https://github.com/nixos-contrib/nix-boxes/releases/latest)
[![NixOS 26.05](https://img.shields.io/badge/NixOS-26.05-5277C3?logo=nixos&logoColor=white)](https://nixos.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Prebuilt NixOS [Vagrant boxes](https://developer.hashicorp.com/vagrant/docs/boxes/base),
built with Nix. Every release ships the boxes as assets. For cloud images, see
[nix-images](https://github.com/nixos-contrib/nix-images).

> [!WARNING]
> This project is a work in progress and has not been tested yet. Boxes may be
> broken, and interfaces may change without notice.

## VMware Fusion

The `vmware` box is for the `vmware_desktop` provider, built for `aarch64-linux`
(Fusion on Apple Silicon) and `x86_64-linux` (Fusion on Intel). You need VMware
Fusion and the
[Vagrant VMware utility and plugin](https://developer.hashicorp.com/vagrant/docs/providers/vmware/installation).
Download the box from the release and add it:

```sh
curl -fLO https://github.com/nixos-contrib/nix-boxes/releases/download/<tag>/nixos-vmware-aarch64-linux.box
vagrant box add nixos-vmware nixos-vmware-aarch64-linux.box
```

Each release also has a `SHA256SUMS` file for checking the download. Then use
the box in a `Vagrantfile` (use `nixos-vmware-x86_64-linux.box` on Intel):

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "nixos-vmware"
  config.vm.provider "vmware_desktop" do |v|
    v.vmx["memsize"] = "4096"
    v.vmx["numvcpus"] = "4"
  end
end
```

## What's in the boxes

- NixOS 26.05 with flakes enabled, plus `git` and `vim`
  ([configuration.nix](configuration.nix))
- A `vagrant` user with the Vagrant insecure key (which Vagrant replaces on first
  `vagrant up`) and passwordless `sudo`, plus the packages Vagrant relies on
- VMware Fusion: UEFI boot, `open-vm-tools`, and a root partition that grows to
  fill the disk on first boot

The `vagrant` user has the well-known password `vagrant`. These boxes are meant
for local development VMs, not for exposure to untrusted networks.

Inside the VM, manage the system with your own flake, for example:

```sh
sudo nixos-rebuild switch --flake .#vmware-aarch64-linux
```

Use `.#vmware` for the x86_64 box.

## Customizing

Fork the repository and edit [configuration.nix](configuration.nix), which every
box shares. Each file in [images](images) is a provider variant that imports the
matching nixpkgs image module and packages the result as a Vagrant box. It builds
as `.#<variant>` and ships in every release as `nixos-<variant>-<system>.box`;
the `aarch64-linux` box is `.#packages.aarch64-linux.<variant>`, with the NixOS
configuration `.#<variant>-aarch64-linux`.

To build locally, you need a Linux machine or remote builder for the target
system:

```sh
nix build .#packages.aarch64-linux.vmware
nix build .#vmware
```

## Releasing

Releases are managed by [release-please](https://github.com/googleapis/release-please)
from [Conventional Commits](https://www.conventionalcommits.org/). Every push to
`main` builds the boxes, and release-please keeps a release PR open. Merging that
PR tags a release and attaches every box and `SHA256SUMS` to it.

A weekly `chore(flake)` PR updates nixpkgs and merges automatically. These
updates don't trigger a release by themselves.
