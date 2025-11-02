{
  docker.volumes = {
    testvol = {
    };
    othervol = {
      labels = {
        foo = "bar";
        bin = "bz";
      };
    };
  };
}
