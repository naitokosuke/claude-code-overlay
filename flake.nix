{
  description = "Claude Code CLI binaries.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Pre-commit hooks
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
    pre-commit-hooks,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    outputs = flake-utils.lib.eachSystem systems (system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg:
          builtins.elem (nixpkgs.lib.getName pkg) [
            "claude"
          ];
      };
    in rec {
      # Pre-commit hooks configuration
      checks = {
        pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            alejandra.enable = true;
            deadnix.enable = true;
            statix.enable = true;
          };
        };
      };
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
        inherit (self.checks.${system}.pre-commit-check) shellHook;
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
      # Overlay that provides claude-code package
      overlays.default = _final: prev: {
        claude-code = outputs.packages.${prev.system}.default;
      };
    };
}
