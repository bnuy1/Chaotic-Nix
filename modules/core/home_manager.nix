{ config, pkgs, lib, ... }:

let
  home-manager = builtins.fetchTarball https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz;
in
{
  imports =
    [
      (import "${home-manager}/nixos")
    ];

  # In the future it would be cool to have a arbatrary number of users that would be itterated through like a list

  users.users.fur3.isNormalUser = true;
  home-manager.users.fur3 = { pkgs, ... }: {
    #install common apps
    imports = [ ../home ]; 
    programs.bash.enable = true;


    # Per user config
    programs.git = {
      enable = true;
      lfs.enable = true;
      settings = {
        user = {
          name  = "Ha2k4r";
          email = "enigma557@proton.me";
        };
        init.defaultBranch = "main";
        safe.directory = "/etc/nixos";
      };
    };

    services.dunst.enable = true;

    # The state version is required and should stay at the version you
    # originally installed.
    home.stateVersion = "25.11";
  };
}
