{ config, inputs, ... }:
{

  systemd.services.sops-nix.enable = true;

  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  # because nix needs to have hardcoded strings, im able to bypass this by
  # setting a friggen root env param :/
  sops.secrets."minecraft_env" = {
    #  readable by the docker/podman service
    owner = "root"; # Or user if using rootless
    mode = "0440"; # read only to keep prying eyes away from our precious keys
  };

  sops.secrets."minecraft/RCON_PASSWORD" = {
    owner = "root";
    mode = "0444";
  };

  sops.secrets."minecraft/RESTIC_PASSWORD" = {
    owner = "root";
    mode = "0444";
  };

  sops.secrets."minecraft/VELOCITY_SECRET" = {
    # Write the secret to a plaintext file for velocity to forward player info to
    owner = "root";
    mode = "0644";
    path = "/var/lib/minecraft/velocity/forwarding.secret"; # this is straight up overkill
  };

  virtualisation.oci-containers.containers = {

    minecraft-survival = {
      environmentFiles = [ config.sops.secrets."minecraft_env".path ];
      environment.USE_VELOCITY = "true";
    };

    minecraft-lab = {
      environmentFiles = [ config.sops.secrets."minecraft_env".path ];
      environment.USE_VELOCITY = "true";
    };

    mc-backup = {
      environmentFiles = [ config.sops.secrets."minecraft_env".path ];
    };

    velocity = {
      environmentFiles = [ config.sops.secrets."minecraft_env".path ];
      #environment.FORWARDING_SECRET = "env:VELOCITY_SECRET";
    };
  };
}
