{
  lib,
  config,
  options,
  ...
}:
let

  helpers = import ./helpers.nix { inherit lib; };
  nets = import ./containers-networks.nix { inherit lib config helpers; };
  volumes = import ./containers-volumes.nix { inherit lib config helpers; };
  options = import ./containers-options.nix { inherit lib; };

  mkPassThroughCfg = cfg: lib.filterAttrs (n: v: options.isPassthrough n) cfg;

  mkExtraContainerCfg = cfg: {
    extraOptions =
      cfg.extraOptions ++ (nets.extraOptions cfg.networks) ++ (volumes.extraOptions cfg.volumes);
  };

  mkOciContainer = cfg: ((mkPassThroughCfg cfg) // (mkExtraContainerCfg cfg));

  mkContainerService =
    name: cfg:
    let
      services = (nets.serviceNames cfg.networks) ++ (volumes.serviceNames cfg.volumes);
    in
    lib.mkMerge [
      {
        after = services;
        requires = services;
      }
      cfg.serviceOptions
    ];

in

{
  options = {
    docker.containers = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (lib.types.submodule options.definition);
      description = "Docker container definitions";
    };
  };
  config = {
    virtualisation.oci-containers.containers = lib.mapAttrs' (
      name: cfg: lib.nameValuePair name (mkOciContainer cfg)
    ) config.docker.containers;

    systemd.services = lib.mapAttrs' (
      n: v: lib.nameValuePair v.serviceName (mkContainerService n v)
    ) config.docker.containers;
  };
}
