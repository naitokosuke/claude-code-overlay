{
  description = "Claude Code CLI binaries.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Used for shell.nix
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    outputs = flake-utils.lib.eachSystem systems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in rec {
      # The packages exported by the Flake:
      #  - default - latest /released/ version
      #  - <version> - tagged version
      packages = import ./default.nix {inherit system pkgs;};

      # "Apps" so that `nix run` works. If you run `nix run .` then
      # this will use the latest default.
      apps = rec {
        default = apps.claude;
        claude = flake-utils.lib.mkApp {drv = packages.default;};
      };

      # nix fmt
      formatter = pkgs.alejandra;

      devShells.default = pkgs.mkShell {
        nativeBuildInputs = with pkgs; [
          curl
          jq
        ];
      };

      # For compatibility with older versions of the `nix` binary
      devShell = self.devShells.${system}.default;
    });
  in
    outputs
    // {
      # Overlay that can be imported so you can access the packages
      # using claudepkgs.default or whatever you'd like.
      overlays.default = final: prev: {
        claudepkgs = outputs.packages.${prev.system};
      };
    };
}
