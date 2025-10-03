{ lib, config, ... }:
{
  imports = [
    ./networks.nix
    ./volumes.nix
    ./containers.nix
  ];

  config = {
    warnings =
      (lib.optional (config.virtualisation.docker.enable != true) (
        "virtualisation.docker.enable should be true when using nix-shipyard"
      ))
      ++ (lib.optional (config.virtualisation.oci-containers.backend != "docker") (
        "virtualisation.oci-containers.backend should be set to \"docker\" when using nix-shipyard"
      ));
  };
}
