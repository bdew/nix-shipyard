{
  description = "Nix docker management";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    {
      nixosModules.default = import ./module;

      nixosConfigurations.example = import ./example { inherit nixpkgs; dockerModule = self.nixosModules.default; };
    };
}
