{
  pkgs,
  lib,
  config,
  ...
}:

let
  docker-images = pkgs.writeText "docker-images.txt" (
    lib.concatStringsSep "\n" (
      lib.uniqueStrings (
        map (container: container.image) (
          builtins.filter (
            container: builtins.isAttrs container && container ? image && builtins.isString container.image
          ) (builtins.attrValues config.docker.containers)
        )
      )
    )
  );
  docker-preloader = pkgs.writers.writePython3 "docker-preloader" {
    libraries = [ ];
    flakeIgnore = [ "E501" ]; # ignores line-length linter warnings
  } ./preloader.py;
in
{
  options.docker.preloader = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to preload Docker images before switching system configurations.";
  };

  config = lib.mkIf config.docker.preloader {
    system.preSwitchChecks.docker-preloader = ''
      ${docker-preloader} ${docker-images} ${lib.getExe config.virtualisation.docker.package} "$2"
    '';
  };
}
