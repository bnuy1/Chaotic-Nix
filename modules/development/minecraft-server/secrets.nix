{ ... }:
{
  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  sops.secrets."minecraft/rcon_password" = { };
  sops.secrets."minecraft/restic_password" = { };

  virtualisation.oci-containers.containers.minecraft = {
    # pass the decrypted file paths dynamically to the environment variables
    environment = {
      RCON_PASSWORD_FILE = config.sops.secrets."minecraft/rcon_password".path;
    };
  };
}
