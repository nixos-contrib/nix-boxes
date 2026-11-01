#!/usr/bin/env bash
#
# Builds a Vagrant box for the Parallels provider (Parallels Desktop) from a raw
# EFI disk image, without Parallels Desktop. The box contains:
# - <name>.pvm/config.pvs, rendered from a template cut from a box that
#   Parallels Desktop produced (EFI, one SATA disk, one virtio network adapter)
# - <name>.pvm/harddisk1.hdd/: the disk as an expanding Parallels image
#   (DiskDescriptor.xml plus one .hds with the fixed base image ID), converted
#   with qemu-img and rewritten into the "WithoutFreeSpace" layout Parallels
#   Desktop itself writes (qemu-img writes the "WithouFreSpacExt" one)
# - Vagrantfile, an empty file
# - metadata.json, with the provider and architecture
#
# Parallels Desktop creates the rest (NVRAM.dat, VmInfo.pvi) on first boot.
#
# Adapted from raw-to-vagrant-parallels.sh in AlmaLinux/cloud-images (MIT), see
# NOTICE. Unlike the original, every ID is derived from the disk contents, so
# the box is reproducible.
#
# Usage:
#   raw-to-parallels-box.sh <raw-image> <config.pvs template> <output.box> \
#     <name> <tools-version> [<numvcpus> <memsize-mb>]

set -euo pipefail

raw=$1
template=$2
out=$3
name=$4
tools_version=$5
numvcpus=${6:-2}
memsize=${7:-2048}

# The base image (the first snapshot) of a Parallels disk must carry this fixed
# ID, in the .hds file name and in DiskDescriptor.xml: Parallels does not find a
# base image with any other ID. Every disk Parallels Desktop creates uses it.
# See qemu's docs/interop/prl-xml.rst.
hds_uuid=5fbaabe3-6958-40ff-92a7-860e329aab41

work=$(mktemp -d)
pvm="$work/$name.pvm"
hdd="$pvm/harddisk1.hdd"
hds="$hdd/harddisk1.hdd.0.{$hds_uuid}.hds"
mkdir -p "$hdd"

# The disk: an expanding image with 1 MiB clusters, as Parallels creates it.
qemu-img convert -f raw -O parallels -o cluster_size=1M "$raw" "$hds"

# qemu-img writes the "WithouFreSpacExt" header, whose allocation table holds
# cluster numbers; Parallels Desktop writes "WithoutFreeSpace", whose table
# holds sector offsets. Rewrite it to match the disks Parallels Desktop makes.
python3 -I - "$hds" <<'PY'
import struct, sys
with open(sys.argv[1], "r+b") as f:
    header = bytearray(f.read(64))
    if header[:16] != b"WithouFreSpacExt":
        sys.exit(f"unexpected header {bytes(header[:16])!r}")
    tracks, bat_entries = struct.unpack_from("<II", header, 28)
    bat = list(struct.unpack(f"<{bat_entries}I", f.read(4 * bat_entries)))
    bat = [c * tracks for c in bat]
    if max(bat, default=0) > 0xFFFFFFFF:
        sys.exit("the disk is too large for the WithoutFreeSpace layout")
    header[:16] = b"WithoutFreeSpace"
    f.seek(0)
    f.write(header)
    f.write(struct.pack(f"<{bat_entries}I", *bat))
PY
qemu-img check -f parallels "$hds"
: >"$hdd/harddisk1.hdd"

# IDs derived from the final disk, so they are stable for a given build and
# differ between builds (Parallels registers the box by its VM UUID).
disk_sum=$(sha256sum "$hds" | cut -d' ' -f1)
uuid() {
  local h
  h=$(printf '%s:%s' "$1" "$disk_sum" | sha256sum | cut -c1-32)
  printf '%s-%s-4%s-8%s-%s' "${h:0:8}" "${h:8:4}" "${h:13:3}" "${h:17:3}" "${h:20:12}"
}
# A MAC address in the Parallels range (00:1C:42), as Parallels assigns them.
mac() {
  printf '001C42%s' "$(printf '%s:%s' "$1" "$disk_sum" | sha256sum | cut -c1-6 | tr 'a-f' 'A-F')"
}

disk_sectors=$(($(stat -c %s "$raw") / 512))
disk_size_mb=$((disk_sectors / 2048))
disk_size_on_disk_mb=$((($(stat -c %s "$hds") + 1048575) / 1048576))

cat >"$hdd/DiskDescriptor.xml" <<XML
<?xml version='1.0' encoding='UTF-8'?>
<Parallels_disk_image Version="1.0">
    <Disk_Parameters>
        <Disk_size>${disk_sectors}</Disk_size>
        <Cylinders>$((disk_sectors / (16 * 32)))</Cylinders>
        <PhysicalSectorSize>4096</PhysicalSectorSize>
        <LogicSectorSize>512</LogicSectorSize>
        <Heads>16</Heads>
        <Sectors>32</Sectors>
        <Padding>0</Padding>
        <Encryption>
            <Engine>{00000000-0000-0000-0000-000000000000}</Engine>
            <Data></Data>
            <Salt></Salt>
        </Encryption>
        <UID>{$(uuid disk-uid)}</UID>
        <Name>harddisk1 SSD</Name>
        <Miscellaneous>
            <CompatLevel>level2</CompatLevel>
            <SuspendState>0</SuspendState>
            <DupBlocksCnt>0</DupBlocksCnt>
            <CorruptBlocksCnt>0</CorruptBlocksCnt>
            <UnrefBlocksCnt>0</UnrefBlocksCnt>
            <OutOfDiskBlocksCnt>0</OutOfDiskBlocksCnt>
            <BatOverlapBlocksCnt>0</BatOverlapBlocksCnt>
            <BlocksCnt>0</BlocksCnt>
            <TruncatedBlocksCnt>0</TruncatedBlocksCnt>
            <ReferencedBlocksCnt>0</ReferencedBlocksCnt>
            <Bootable>1</Bootable>
            <ChangeState>1</ChangeState>
            <GuestToolsVersion>${tools_version}</GuestToolsVersion>
            <ShutdownState>0</ShutdownState>
        </Miscellaneous>
    </Disk_Parameters>
    <StorageData>
        <Storage>
            <Start>0</Start>
            <End>${disk_sectors}</End>
            <Blocksize>2048</Blocksize>
            <Image>
                <GUID>{${hds_uuid}}</GUID>
                <Type>Compressed</Type>
                <File>${hds##*/}</File>
            </Image>
        </Storage>
    </StorageData>
    <Snapshots>
        <Shot>
            <GUID>{${hds_uuid}}</GUID>
            <ParentGUID>{00000000-0000-0000-0000-000000000000}</ParentGUID>
        </Shot>
    </Snapshots>
</Parallels_disk_image>
XML

creation_date=$(date -u -d "@${SOURCE_DATE_EPOCH:-0}" '+%Y-%m-%d %H:%M:%S')
sed \
  -e "s/@VM_UUID@/$(uuid vm)/g" \
  -e "s/@VM_NAME@/${name}/" \
  -e "s/@CREATION_DATE@/${creation_date}/g" \
  -e "s/@TOOLS_VERSION@/${tools_version}/" \
  -e "s/@HDD_UUID@/$(uuid hdd)/" \
  -e "s/@DISK_SIZE_MB@/${disk_size_mb}/" \
  -e "s/@DISK_SIZE_ON_DISK_MB@/${disk_size_on_disk_mb}/" \
  -e "s/@NUMVCPUS@/${numvcpus}/" \
  -e "s/@MEMSIZE@/${memsize}/" \
  -e "s/@MAC@/$(mac guest)/" \
  -e "s/@HOST_MAC@/$(mac host)/" \
  "$template" >"$pvm/config.pvs"

# The template also contains literal "VIRTUAL@MOUSE@" and "VIRTUAL@KEYBOARD@"
# device names, which are not placeholders.
if grep -nE '@(VM_UUID|VM_NAME|CREATION_DATE|TOOLS_VERSION|HDD_UUID|DISK_SIZE_MB|DISK_SIZE_ON_DISK_MB|NUMVCPUS|MEMSIZE|MAC|HOST_MAC)@' "$pvm/config.pvs"; then
  echo "unrendered placeholders in config.pvs" >&2
  exit 1
fi

: >"$work/Vagrantfile"
echo '{"architecture":"arm64","provider":"parallels"}' >"$work/metadata.json"

# Parallels disks aren't compressed, hence the gzip.
tar -C "$work" --sort=name --owner=0 --group=0 --numeric-owner \
  --mtime="@${SOURCE_DATE_EPOCH:-0}" -cf - . | gzip -9n >"$out"
rm -rf "$work"
