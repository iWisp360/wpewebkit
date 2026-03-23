{
  description = "WPEWebKit Library";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs =
    { nixpkgs, ... }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    in
    {
      packages.${pkgs.stdenv.hostPlatform.system}.default = pkgs.callPackage ./default.nix { };
    };
}
