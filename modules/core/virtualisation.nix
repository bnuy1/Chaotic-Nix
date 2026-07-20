{ pkgs, lib, vars, ... }:
let
  dockerEnable = vars.dockerEnable or false;
in
{
  security.apparmor.enable = true;

  virtualisation = {
    docker = {
      enable = dockerEnable;
    };

    podman.enable = vars.podmanEnable or false;

    libvirtd.enable = vars.libvirtdEnable or false;
  };

  virtualisation.docker.rootless = lib.mkIf dockerEnable {
    enable = true;
    setSocketVariable = true;
  };

  programs = {
    virt-manager.enable = vars.virtManagerEnable or false;
  };

  environment.systemPackages = with pkgs; (
    [ ]
    ++ lib.optionals dockerEnable [ virt-viewer lazydocker docker-client ]
    ++ lib.optionals (vars.libvirtdEnable or false) [ virt-viewer ]
  );
}
