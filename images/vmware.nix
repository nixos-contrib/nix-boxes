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

        echo '{"provider":"vmware_desktop"}' > metadata.json
        cp ${vagrantfile} Vagrantfile
        cp ${vmx} box.vmx

        # The only file in the VMDK build output (named after image.fileName).
        cp ${config.system.build.vmwareImage}/* ${vmdk}

        tar --owner=0 --group=0 --sort=name --numeric-owner -czf $out/${filePath} .
      ''
  );
}
