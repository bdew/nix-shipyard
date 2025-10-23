{ lib }:
rec {
  mkDashDashOpts =
    attrs:
    lib.flatten (
      lib.mapAttrsToList (
        k: v:
        (
          if (builtins.isString v) then
            [ "--${k}=${lib.escapeShellArg v}" ]
          else if (builtins.isList v) then
            (builtins.map (item: "--${k}=${lib.escapeShellArg item}") v)
          else if v then
            [ "--${k}" ]
          else
            [ ]
        )
      ) attrs
    );

  mkKvOpt =
    k: v:
    (
      if (v == true) then
        k
      else if builtins.isString v then
        "${k}=${lib.escapeShellArg v}"
      else
        builtins.throw "Invalid key-value value: ${v}"
    );

  mkKvOpts = attrs: lib.concatStringsSep "," (lib.mapAttrsToList mkKvOpt attrs);
}
