{ config, ... }:
{
  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  sops.secrets."matrix/registration_token" = {
    owner = "root";
    mode = "0400";
  };

  sops.secrets."coturn/static_auth_secret" = {
    owner = "root";
    mode = "0400";
  };
}
