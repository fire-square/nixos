{ pkgs, config, ... }:

{
  imports = [
    ./modules
    ./hardware/whale-vm.nix
    ./mounts/whale-vm.nix
  ];

  networking.nft-firewall.enable = false;
  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

  # age.secrets.woodpecker-agent.file = ./secrets/credentials/woodpecker-agent.age;
  # virtualisation.oci-containers.containers.woodpecker-agent = {
  #   image = "docker.io/woodpeckerci/woodpecker-agent:v0.15.3";
  #   volumes = [ "/var/run/docker.sock:/var/run/docker.sock" ];
  #   environment = {
  #     WOODPECKER_SERVER = "rat.n.frsqr.xyz:9000";
  #     WOODPECKER_MAX_PROCS = "4";
  #   };
  #   environmentFiles = [ config.age.secrets.woodpecker-agent.path ];
  # };

  networking = {
    hostName = "beaver";

    nebula-frsqr.enable = true;

    defaultGateway = {
      address = "192.168.12.1";
      interface = "enp1s0";
    };

    interfaces = {
      enp1s0 = {
        ipv4 = {
          addresses = [{
            address = "192.168.12.3";
            prefixLength = 24;
          }];
        };
      };
    };
  };
}
