# Shared by every box in ./images.
{ modulesPath, pkgs, ... }:
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

  # Keep the boxes small.
  documentation.man.enable = false;
  documentation.nixos.enable = false;

  system.stateVersion = "26.05";
}
