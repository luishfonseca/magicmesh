{
  description = "lhf.pt website";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-23.05";

    utils.url = "github:numtide/flake-utils";

    nix-filter.url = "github:numtide/nix-filter";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "utils";
    };

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "utils";
      inputs.rust-overlay.follows = "rust-overlay";
    };
  };

  outputs = { ... } @ inputs: inputs.utils.lib.eachDefaultSystem (system:
    let
      pkgs = import inputs.nixpkgs { inherit system; overlays = [ inputs.rust-overlay.overlays.default ]; };

      rust = pkgs.rust-bin.stable.latest;

      rust-dev = rust.default.override {
        extensions = [ "rust-src" "rust-analyzer" ];
      };

      crane = (inputs.crane.mkLib pkgs).overrideToolchain rust.minimal;

      deps = { prod }: crane.buildDepsOnly {
        CARGO_PROFILE = if prod then "release" else "dev";
        doCheck = false;
        src = inputs.nix-filter.lib.filter {
          root = ./.;
          include = [ "Cargo.toml" "Cargo.lock" ];
        };
      };

      build = { prod }: crane.buildPackage {
        CARGO_PROFILE = if prod then "release" else "dev";
        cargoArtifacts = deps { inherit prod; };
        src = inputs.nix-filter.lib.filter {
          root = ./.;
          include = [ "Cargo.toml" "Cargo.lock" "src" ];
        };
      };
    in
    rec {
      devShell = pkgs.mkShell {
        buildInputs = with pkgs; [ rust-dev ];
      };

      packages.magicmesh-prod = build { prod = true; };
      packages.magicmesh-dev = build { prod = false; };

      defaultPackage = packages.magicmesh-prod;
    });
}
