{
  description = "Base NixOS Vagrant boxes";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      # Every ./images/<variant>.nix becomes a box named after the variant.
      variants = map (lib.removeSuffix ".nix") (builtins.attrNames (builtins.readDir ./images));

      # Apple Silicon hosts run Arm guests, Intel hosts x86_64 guests.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      mkSystem =
        variant: system:
        lib.nixosSystem {
          inherit system;
          modules = [
            ./configuration.nix
            ./images/${variant}.nix
            # Stable file name so the release asset URL is predictable.
            { image.baseName = "nixos-${variant}-${system}"; }
          ];
        };

      # The x86_64-linux configuration keeps the plain variant name; other
      # systems get a suffix, e.g. vmware-aarch64-linux.
      configName = variant: system: if system == "x86_64-linux" then variant else "${variant}-${system}";
    in
    {
      nixosConfigurations = lib.listToAttrs (
        lib.concatMap (
          variant:
          map (system: lib.nameValuePair (configName variant system) (mkSystem variant system)) systems
        ) variants
      );

      packages = lib.genAttrs systems (
        system:
        lib.genAttrs variants (
          variant: self.nixosConfigurations.${configName variant system}.config.system.build.image
        )
      );
    };
}
