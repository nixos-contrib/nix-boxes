{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:
let
  inherit (config.image) baseName filePath;
  inherit (pkgs.stdenv.hostPlatform) isAarch64;

  # Apple Silicon Fusion runs Arm guests; Intel Fusion runs x86_64 guests.
  guestOS = if isAarch64 then "arm-other6xlinux-64" else "other6xlinux-64";

  # The disk must be named in the .vmx; Vagrant imports the first *.vmx.
  vmdk = "disk.vmdk";

  vagrantfile = pkgs.writeText "Vagrantfile" ''
    Vagrant.configure("2") do |config|
      config.vm.guest = :linux
    end
  '';

  vmx = pkgs.writeText "box.vmx" ''
    .encoding = "UTF-8"
    config.version = "8"
    virtualHW.version = "20"
    displayName = "${baseName}"
    guestOS = "${guestOS}"
    firmware = "efi"
    memsize = "2048"
    numvcpus = "2"
    pciBridge0.present = "TRUE"
    pciBridge4.present = "TRUE"
    pciBridge4.virtualDev = "pcieRootPort"
    pciBridge4.functions = "8"
    pciBridge5.present = "TRUE"
    pciBridge5.virtualDev = "pcieRootPort"
    pciBridge5.functions = "8"
    pciBridge6.present = "TRUE"
    pciBridge6.virtualDev = "pcieRootPort"
    pciBridge6.functions = "8"
    pciBridge7.present = "TRUE"
    pciBridge7.virtualDev = "pcieRootPort"
    pciBridge7.functions = "8"
    nvme0.present = "TRUE"
    nvme0:0.present = "TRUE"
    nvme0:0.fileName = "${vmdk}"
    ethernet0.present = "TRUE"
    ethernet0.connectionType = "nat"
    ethernet0.virtualDev = "e1000e"
    ethernet0.addressType = "generated"
    ethernet0.startConnected = "TRUE"
    tools.syncTime = "TRUE"
  '';
in
{
  # Provides the UEFI VMDK builder plus open-vm-tools.
  imports = [ "${modulesPath}/virtualisation/vmware-image.nix" ];

  # Fusion exposes the disk over NVMe.
  boot.initrd.availableKernelModules = [ "nvme" ];

  # The disk is sparse, so its size costs little in the box, but a system built with a flake needs
  # far more room than the "auto" size, which fits only the installed system. The root partition
  # grows to fill the disk on first boot.
  virtualisation.diskSize = lib.mkDefault (40 * 1024);

  # Package the VMDK as a Vagrant box for the vmware_desktop provider:
  # https://developer.hashicorp.com/vagrant/docs/providers/vmware/boxes
  image.extension = lib.mkForce "box";
  system.nixos.tags = [ "vagrant" ];
  system.build.image = lib.mkForce (
    pkgs.runCommand "vagrant-vmware-box"
      {
        nativeBuildInputs = [
          pkgs.gnutar
          pkgs.gzip
        ];
      }
      ''
        mkdir workdir $out
        cd workdir

        # The files of the store are read-only, and so would be the ones of the box. Fusion has to
        # write the .vmx and the disk to snapshot and clone it, so the copies keep no mode.
        echo '{"provider":"vmware_desktop"}' > metadata.json
        cp --no-preserve=mode ${vagrantfile} Vagrantfile
        cp --no-preserve=mode ${vmx} box.vmx

        # The VMDK is named after image.fileName; the output also has a
        # nix-support directory, so don't glob.
        cp --no-preserve=mode ${config.system.build.vmwareImage}/${config.image.fileName} ${vmdk}

        tar --owner=0 --group=0 --sort=name --numeric-owner -czf $out/${filePath} .
      ''
  );
}
