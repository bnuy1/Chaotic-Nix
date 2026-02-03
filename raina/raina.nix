{ config, lib, pkgs, ...}: 

let
  #home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
  nvim-config = builtins.fetchGit "https://github.com/Indigo-69/kickstart.nvim.git";
in
{
#  imports = 
#    [
#      (import "${home-manager}/nixos")
#    ];

  users.users.raina = {
    isNormalUser = true;
    description = "R";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.bash;
    
    openssh.authorizedKeys.keys = [
    # Public Key
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINYmpDO0d8/WMd1FAbvBuZ6TEUoQ/ycJrMm+XRn+RIne raina@Arch"
    ];
  };

  home-manager.users.raina = { pkgs, ... }: {
    # Wont work without this lol
    home.stateVersion = "25.11";

    # List of pkgs for the home environment
    home.packages = with pkgs; [
      # General utilities
      btop
      hyfetch
      fastfetch
      fd

      # Nvim stuff
      gcc
      unzip
      ripgrep
      nodejs
      go
      stylua
      pyright
      bash-language-server
      nil
      rustup
    ];

    programs.bash = {
      enable = true;
      shellAliases = {
        ls = "ls -a --color";
        nrs = "sudo nixos-rebuild switch";
        nnix = "nvim /etc/nixos";
      };
    };

    programs.starship = {
      enable = true;
      settings = {
	add_newline = false;
	hostname = {
	  format = "[$hostname]($style) in ";
	};
	memory_usage = {
	  disabled = false;
	  threshold = -1;
	  format = "w/ $symbol[$ram( | $swap)]($style) ";
	};
      };
    };

    programs.neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
      extraLuaConfig = lib.fileContents "${nvim-config}/init.lua";
    };
    # Put neovim config files in the directory
    xdg.configFile."nvim".source = nvim-config;

    programs.git = {
      enable = true;
      lfs.enable = true;
      settings.user.name = "Indigo-69";
      settings.user.email = "wyfi08g@proton.me";
      settings = {
        init.defaultBranch = "main";
        safe.directory = "/etc/nixos";
      };
    };
  };
}
