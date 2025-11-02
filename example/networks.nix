{
  docker.networks = {

    front = {
      options = {
        driver = "bridge";
        ipv6 = true;
        subnet = [
          "192.168.5.1/24"
        ];
      };
    };

    lan = {
      options = {
        driver = "macvlan";
        subnet = "192.168.2.0/24";
        gateway = "192.168.2.1";
      };
      labels = {
        foo = "bar";
      };
      driverOptions = {
        parent = "end0";
      };
      serviceOptions = {
        description = "test service";
      };
    };
  };

}
