#!/usr/bin/env bash
# Writes the Vagrant version catalog of each box in a directory, next to the boxes.
#
# Usage: catalog.sh <tag> <dir>
#
# A box added from a catalog is the only kind `vagrant box update` can update, and
# the catalog is also where Vagrant reads the checksum of each box. The boxes are
# named nixos-<variant>-<system>.box and every variant gets nixos-<variant>.json,
# which lists the version of the tag and a box for each system. The name has no
# version in it, so https://nixos-contrib.github.io/nix-boxes/nixos-<variant>.json
# is always the newest release: the pages workflow serves the catalogs from the
# latest release, as GitHub sends the assets of a release as octet-stream and
# Vagrant takes a URL for a catalog only when the server says application/json.
# https://developer.hashicorp.com/vagrant/docs/boxes/format#box-versioning
set -euo pipefail

tag="$1"
dir="$2"
repo="${GITHUB_REPOSITORY:-nixos-contrib/nix-boxes}"
version="${tag#v}"

cd "$dir"

# The variants are the part of the file names between nixos- and the system.
variants=$(
  for box in nixos-*.box; do
    name="${box#nixos-}"
    echo "${name%-*-linux.box}"
  done | sort -u
)

for variant in $variants; do
  providers=$(
    for box in "nixos-$variant"-*-linux.box; do
      system="${box#"nixos-$variant-"}"
      system="${system%.box}"
      case "$system" in
        aarch64-linux) architecture=arm64 ;;
        x86_64-linux) architecture=amd64 ;;
        *)
          echo "unknown system in $box" >&2
          exit 1
          ;;
      esac

      # The provider is the one the box itself declares in its metadata.json.
      provider=$(tar -xzOf "$box" ./metadata.json | jq -r .provider)

      jq -n \
        --arg name "$provider" \
        --arg architecture "$architecture" \
        --arg url "https://github.com/$repo/releases/download/$tag/$box" \
        --arg checksum "$(sha256sum "$box" | cut -d' ' -f1)" \
        '{
          name: $name,
          architecture: $architecture,
          url: $url,
          checksum_type: "sha256",
          checksum: $checksum
        }'
    done | jq -s .
  )

  jq -n \
    --arg name "nixos-$variant" \
    --arg version "$version" \
    --argjson providers "$providers" \
    '{
      name: $name,
      description: "NixOS box from nixos-contrib/nix-boxes",
      versions: [{ version: $version, providers: $providers }]
    }' > "nixos-$variant.json"

  echo "nixos-$variant.json"
done
