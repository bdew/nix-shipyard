{
  nixpkgs,
  dockerModule,
  ...
}:

nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    (
      { config, ... }:
      {
        system.stateVersion = "25.05";
        boot.loader.grub.device = "nodev";
        fileSystems = {
          "/" = {
            device = "/dev/disk/by-label/NIXOS";
            fsType = "ext4";
          };
        };
        virtualisation.oci-containers.backend = "docker";
        virtualisation.docker.enable = true;
      }
    )
    dockerModule
    ./networks.nix
    ./volumes.nix
    ./containers.nix
  ];
}
