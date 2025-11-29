{
  lib,
  helpers,
  config,
  ...
}:
let
  mkMountArgFromObj = name: cfg: [
    "--mount"
    (helpers.mkKvOpts ({ dst = name; } // cfg))
  ];

  mkMountArgPart =
    part:
    let
      split = (lib.splitString "=" part);
    in
    {
      name = builtins.elemAt split 0;
      value =
        if builtins.length split == 1 then
          true
        else if builtins.length split == 2 then
          builtins.elemAt split 1
        else
          builtins.throw "invalid mount argument: ${part}";
    };

  mkMountArgFromString =
    name: type: parts:
    let
      src = builtins.elemAt parts 0;
      rest = builtins.map mkMountArgPart (lib.drop 1 parts);
    in
    mkMountArgFromObj name (
      {
        inherit type src;
      }
      // (builtins.listToAttrs rest)
    );

  mkMountArgBind =
    name: path:
    mkMountArgFromObj name {
      type = "bind";
      src = path;
      ro = true;
    };

  mkMountArg =
    name: cfg:
    (
      if builtins.isString cfg then
        if (builtins.substring 0 1 cfg) == "/" then
          mkMountArgFromString name "bind" (lib.splitString ":" cfg)
        else
          mkMountArgFromString name "volume" (lib.splitString ":" cfg)
      else if (lib.isDerivation cfg) || (lib.isPath cfg) then
        mkMountArgBind name cfg
      else
        mkMountArgFromObj name cfg
    );

  volumeNames =
    cfg:
    (
      if builtins.isString cfg then
        if (builtins.substring 0 1 cfg) == "/" then
          [ ]
        else
          [ (builtins.elemAt (lib.splitString ":" cfg) 0) ]
      else if cfg.type == "volume" then
        [ cfg.src ]
      else
        [ ]
    );

  mkServiceName = volumeName: "${config.docker.volumes.${volumeName}.serviceName}.service";

in
{
  extraOptions = volumes: lib.flatten (lib.mapAttrsToList mkMountArg volumes);

  serviceNames =
    volumes:
    builtins.map mkServiceName (lib.flatten (builtins.map volumeNames (builtins.attrValues volumes)));
}
