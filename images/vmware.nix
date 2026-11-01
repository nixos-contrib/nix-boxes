{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:
let
  cfg = config.vmware;
  inherit (config.image) baseName filePath;
  inherit (pkgs.stdenv.hostPlatform) isAarch64;

  # Apple Silicon Fusion runs Arm guests; Intel Fusion runs x86_64 guests.
  guestOS = if isAarch64 then "arm-other6xlinux-64" else "other6xlinux-64";

  # The disk must be named in the .vmx; Vagrant imports the first *.vmx.
  vmdk = "disk.vmdk";

  # Merged under the Vagrantfile of the user, so a minimal one still works.
  #
  # The guest is nixos, not the generic linux: the VMware plugin calls
  # configure_networks on every start, even with nothing to configure, and only
  # the distribution guests have it. The nixos guest only uploads a file to
  # /etc/nixos, it does not rebuild the system.
  #
  # /etc/fstab is a link into the store on NixOS, so it is read-only, and Vagrant
  # would write its empty #VAGRANT-BEGIN block to it ("Read-only file system").
  vagrantfile = pkgs.writeText "Vagrantfile" ''
    Vagrant.configure("2") do |config|
      config.vm.guest = :nixos
      config.vm.allow_fstab_modification = false
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

  options.vmware.boxDiskSizeGiB = lib.mkOption {
    type = lib.types.ints.positive;
    default = 40;
    description = ''
      Virtual size of the box's disk in GiB. The disk is sparse, so it only
      takes the space the system uses. A linked clone inherits the size of
      the box's disk and can't be grown afterwards, so the box has to be big
      enough up front. The first boot grows the root partition and its
      filesystem to fill it.
    '';
  };

  config = {
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
            pkgs.qemu-utils
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

          # The disk is as big as the installed system. Building a bigger one
          # makes the image build run out of memory, so grow it afterwards:
          # qemu-img can't resize a VMDK, so go through a sparse raw image.
          # The VMDK is named after image.fileName; the output also has a
          # nix-support directory, so don't glob.
          qemu-img convert -f vmdk -O raw \
            ${config.system.build.vmwareImage}/${config.image.fileName} $TMPDIR/disk.raw
          truncate -s ${toString cfg.boxDiskSizeGiB}G $TMPDIR/disk.raw
          qemu-img convert -f raw -O vmdk \
            -o subformat=${cfg.vmSubformat},compat6=${if cfg.vmCompat6 then "on" else "off"} \
            $TMPDIR/disk.raw ${vmdk}
          rm $TMPDIR/disk.raw

          tar --owner=0 --group=0 --sort=name --numeric-owner -czf $out/${filePath} .
        ''
    );
  };
}
