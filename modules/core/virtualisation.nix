{ pkgs, ... }:
{
  # AppArmor
  security.apparmor.enable = true;
  # Only enable either docker or podman -- Not both
  virtualisation = {
    docker = {
      enable = true;
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };

    podman.enable = false;

    libvirtd = {
      enable = true;
    };

    virtualbox.host = {
      enable = false;
      enableExtensionPack = true;
    };
  };

  programs = {
    virt-manager.enable = false;
  };

  environment.systemPackages = with pkgs; [
    virt-viewer # View Virtual Machines
    lazydocker
    docker-client
  ];
}
