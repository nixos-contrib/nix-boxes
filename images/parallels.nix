{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:
let
  inherit (config.image) baseName filePath;

  # The raw EFI disk the box is made from.
  rawImage = import "${modulesPath}/../lib/make-disk-image.nix" {
    inherit config lib pkgs;
    inherit (config.virtualisation) diskSize;
    inherit baseName;
    format = "raw";
    partitionTableType = "efi";
  };
in
{
  # Provides the disk layout and bootloader: an EFI system partition and a root
  # partition that grows to fill the disk on first boot.
  imports = [ "${modulesPath}/virtualisation/disk-image.nix" ];

  # Parallels Desktop on Apple Silicon runs Arm guests with UEFI.
  image.format = "raw";
  image.efiSupport = true;

  # Some VM firmware only supports console mode 0, and systemd-boot otherwise
  # fails to boot with "error switching console mode". It is the firmware's
  # default mode, so it's safe everywhere.
  boot.loader.systemd-boot.consoleMode = lib.mkDefault "0";

  # Parallels Tools: shared folders, time sync and the guest agent. The package
  # is unfree, so allow just it.
  hardware.parallels.enable = true;
  nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "prl-tools";

  # The box's VM has a SATA disk and a virtio network adapter.
  boot.initrd.availableKernelModules = [
    "ahci"
    "sd_mod"
    "virtio_pci"
  ];

  # Package the disk as a Vagrant box for the parallels provider. The box is
  # built by hand, since Parallels Desktop can't run in CI, see
  # scripts/raw-to-parallels-box.sh.
  image.extension = lib.mkForce "box";
  system.nixos.tags = [ "vagrant" ];
  system.build.image = lib.mkForce (
    pkgs.runCommand "vagrant-parallels-box"
      {
        nativeBuildInputs = with pkgs; [
          coreutils
          gnused
          gnutar
          gzip
          python3
          qemu-utils
        ];
      }
      ''
        mkdir $out
        bash ${../scripts/raw-to-parallels-box.sh} \
          ${rawImage}/${baseName}.img \
          ${../templates/parallels/box-aarch64.pvs} \
          $out/${filePath} \
          ${baseName} \
          ${config.hardware.parallels.package.version}
      ''
  );
}
