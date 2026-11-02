{
  description = "Base NixOS Vagrant boxes";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      # Every ./images/<variant>.nix becomes a box named after the variant.
      variants = map (lib.removeSuffix ".nix") (builtins.attrNames (builtins.readDir ./images));

      # Apple Silicon hosts run Arm guests, Intel hosts x86_64 guests. Variants
      # not listed here are built for both.
      allSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      variantSystems = {
        # Parallels Desktop only runs Arm guests on Apple Silicon so far.
        parallels = [ "aarch64-linux" ];
      };
      systemsOf = variant: variantSystems.${variant} or allSystems;

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
          map (system: lib.nameValuePair (configName variant system) (mkSystem variant system)) (
            systemsOf variant
          )
        ) variants
      );

      packages = lib.genAttrs allSystems (
        system:
        lib.genAttrs (lib.filter (variant: lib.elem system (systemsOf variant)) variants) (
          variant: self.nixosConfigurations.${configName variant system}.config.system.build.image
        )
      );
    };
}
