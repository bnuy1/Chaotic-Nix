{
  pkgs,
  host,
  inputs,
  ...
}:

let
  vars = import ../../hosts/${host}/variables.nix;
  # home manager library shortcut
  hmLib = inputs.home-manager.lib;
in
{
  users.users.${vars.Primary-User} = {
    isNormalUser = true;
    description = "Primary User";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICDpAOcERg7AdXnDJrEjars/3dUPzVpIhYCYufTExq+m enigma558@proton.me"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAX35vvNbcI+GZDoPeRBf/418a2GRg4M+JuL5rFUTvXS mal@missNectarine"
    ];
  };

  users.users.${vars.Secondary-User} = {
    isNormalUser = true;
    description = "Secondary User";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINYmpDO0d8/WMd1FAbvBuZ6TEUoQ/ycJrMm+XRn+RIne raina@Arch"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIbi7shzgg3q+mfHDcjPiSu1aklccEy8Wwh78SAsqWd8 raina@dyingStar"
    ];
  };

  ###### Home Manager Configuration #######
  home-manager = {
    useUserPackages = true;
    useGlobalPkgs = true;
    backupFileExtension = "backup";
    # passes inputs (containing nixvim) to the users files
    extraSpecialArgs = { inherit inputs host vars; };

    # Secondary User
    users.${vars.Secondary-User} =
      { pkgs, ... }:
      {

        home.username = "${vars.Secondary-User}";
        home.homeDirectory = "/home/${vars.Secondary-User}";
        home.stateVersion = "25.11";

        imports = [
          ../home
          # Dynamically imports ../home/nixvim/username.nix ITS SO COOL
          #(./. + "/../home/nixvim/${vars.Secondary-User}.nix")
        ];

        home.packages = with pkgs; [
          btop
          hyfetch
          fastfetch
          fd
          gcc
          ripgrep
        ];

        programs.bash = {
          enable = true;
          shellAliases = {
            ls = "ls -a --color";
            nrs = "sudo nixos-rebuild switch --flake .";
          };
        };

        programs.git = {
          enable = true;
          settings = {
            user = {
              name = "${vars.Secondary-User_gitUsername}";
              email = "${vars.Secondary-User_gitEmail}";
            };
          };
        };
      };

    # Configuration for the Primary User of the system
    users.${vars.Primary-User} =
      { pkgs, ... }:
      {
        # A broken, nonworking attempt to make wallpapers accross userspace
        home.activation.copyWallpapers = hmLib.hm.dag.entryAfter [ "writeBoundary" ] ''
          TARGET_DIR="/home/${vars.Primary-User}/Pictures/wallpapers"
          SRC_PATH="${../../assets/wallpapers}"

          # murder the previous wallpapers
          /run/current-system/sw/bin/rm -rf "$TARGET_DIR" || true
          /run/current-system/sw/bin/mkdir -p "$TARGET_DIR"

          if [ -d "$SRC_PATH" ]; then
            /run/current-system/sw/bin/cp -rfL "$SRC_PATH"/. "$TARGET_DIR/" || true
          fi

          #  Owner can do everything, others nothing
          /run/current-system/sw/bin/chmod 0700 "$TARGET_DIR" || true
          /run/current-system/sw/bin/find "$TARGET_DIR" -type f -exec /run/current-system/sw/bin/chmod 0600 {} + || true
        '';
        home.username = "${vars.Primary-User}";
        home.homeDirectory = "/home/${vars.Primary-User}";
        home.stateVersion = "25.11";
        home.sessionVariables = {
          EDITOR = "nvim";
          VISUAL = "nvim";
          SUDO_EDITOR = "nvim";
        };
        imports = [
          ../home
          # Dynamic import of ../home/nixvim/username.nix
	  (let
	    # test if it exists
	    userFileExists = builtins.pathExists ../home/nixvim/${vars.Primary-User}.nix;
	    
	    # find the filename string as potentially "default"
	    fileName = if userFileExists then vars.Primary-User else "default";
	  in
	  ../home/nixvim/${fileName}.nix)
          ];

        home.packages = with pkgs; [
          git
          btop
        ];
        programs.git = {
          enable = true;
          settings = {
            user = {
              name = "${vars.gitUsername}";
              email = "${vars.gitEmail}";
            };
          };
        };
      };
  };
}
