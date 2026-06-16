{ pkgs, lib, vars, ... }:
{
  # AppArmor
  security.apparmor.enable = true;
  # Only enable either docker or podman -- Not both
  virtualisation = {
    docker = {
      enable = vars.dockerEnable or false;
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };

    podman.enable = vars.podmanEnable or false;

    libvirtd = {
      enable = vars.libvirtdEnable or false;
    };

    virtualbox.host.enable = false;
  };

  programs = {
    virt-manager.enable = vars.virt-managerEnable or false;
  };

  environment.systemPackages = with pkgs; (
    [ virt-viewer ]
    ++ lib.optionals (vars.dockerEnable or false) [ lazydocker docker-client ]
  );
}
