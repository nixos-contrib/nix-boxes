# Shared by every box in ./images.
{
  lib,
  modulesPath,
  pkgs,
  ...
}:
{
  # Provides the vagrant user, its insecure SSH key, passwordless sudo and the
  # packages Vagrant relies on, as required of a base box:
  # https://developer.hashicorp.com/vagrant/docs/boxes/base
  imports = [ "${modulesPath}/virtualisation/vagrant-guest.nix" ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  environment.systemPackages = with pkgs; [
    git
    vim
  ];

  # These are local development VMs on Vagrant's NAT network, where forwarded
  # ports and services in the VM should just work. Turn it back on if you use
  # bridged networking (public_network).
  networking.firewall.enable = lib.mkDefault false;

  # Vagrant runs every command in a login shell (bash -l), and the /etc/bash_logout
  # of NixOS prints an escape that sets the title of the terminal when it exits.
  # Vagrant takes it as the last output of the command: mktemp gives "]0;" instead
  # of a path, and the key types it reads from sshd -T get a line of one word,
  # which fails with "odd number of arguments for Hash". Nothing reads a title here.
  programs.bash.logout = lib.mkDefault "";

  # Keep the boxes small.
  documentation.man.enable = false;
  documentation.nixos.enable = false;

  system.stateVersion = "26.05";
}
