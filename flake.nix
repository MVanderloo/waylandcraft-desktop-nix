{
  description = "A Waylandcraft desktop session for NixOS";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/17de0b976395537756f30a3e78f2f06e5cec89ed";

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      allowedUnfreePackageNames = [
        "sodium"
        "waylandcraft-minecraft-home"
      ];
      projectPkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfreePredicate =
            package: builtins.elem (nixpkgs.lib.getName package) allowedUnfreePackageNames;
        };
      packagesFor = system: import ./nix/packages.nix { pkgs = projectPkgsFor system; };
      waylandcraftModule =
        moduleArgs@{ pkgs, ... }:
        import ./nix/module.nix (
          moduleArgs
          // {
            defaultPackageSet = packagesFor pkgs.stdenv.hostPlatform.system;
          }
        );
    in
    {
      nixosModules = {
        default = self.nixosModules.waylandcraft-desktop;
        waylandcraft-desktop = waylandcraftModule;
      };

      packages = forAllSystems (
        system:
        let
          pkgs = projectPkgsFor system;
        in
        (packagesFor system).exportedPackages
        // {
          # Kept out of `checks` because its first build includes a complete
          # NixOS VM.
          supervision-vm = import ./tests/supervision.nix { inherit pkgs self; };
        }
      );

      checks = forAllSystems (
        system:
        import ./nix/checks.nix {
          inherit self;
          nixpkgsLib = nixpkgs.lib;
          pkgs = projectPkgsFor system;
          packages = packagesFor system;
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShellNoCC {
            packages = [
              pkgs.just
              pkgs.nixfmt
            ];
          };
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
