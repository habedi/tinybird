{
  description = "A tiny Wasm-based application platform for microcontrollers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, zig-overlay }:
    let
      # Development happens on a Linux machine the board plugs into, on either amd64 or arm64.
      supportedSystems = [ "x86_64-linux"
                           "aarch64-linux"
                           "aarch64-darwin"];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          zig = zig-overlay.packages.${system}."0.17.0";
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              # Zig pinned to 0.17.0 matching MicroZig 0.17.20
              zig

              # Build and coverage tools
              gnumake
              kcov

              # Flashing and the serial console
              picotool
              picocom

              # uv manages the Python tools (pre-commit) through
              # pyproject.toml.
              uv
            ];
          };
        }
      );
    };
}
