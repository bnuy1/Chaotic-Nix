{ pkgs, host, inputs, lib, ... }:

let
  vars = import ../../hosts/${host}/variables.nix;
  hmLib = inputs.home-manager.lib;

  primaryUserName = (builtins.head vars.users).name;

  userExtraConfig = {
    fur3 = {
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICDpAOcERg7AdXnDJrEjars/3dUPzVpIhYCYufTExq+m enigma558@proton.me"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAX35vvNbcI+GZDoPeRBf/418a2GRg4M+JuL5rFUTvXS mal@missNectarine"
      ];
      shell = pkgs.fish;
    };
    raina = {
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINYmpDO0d8/WMd1FAbvBuZ6TEUoQ/ycJrMm+XRn+RIne raina@Arch"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIbi7shzgg3q+mfHDcjPiSu1aklccEy8Wwh78SAsqWd8 raina@dyingStar"
      ];
      shell = pkgs.bash;
    };
  };

  isPrimary = user: user.name == primaryUserName;

  buildUserConfig = user: {
    isNormalUser = true;
    description = if isPrimary user then "Primary User" else "Secondary User";
    extraGroups = [ "networkmanager" "wheel" ];
  } // (userExtraConfig.${user.name} or {});
in
{
  users.users = builtins.listToAttrs (map (user: {
    name = user.name;
    value = buildUserConfig user;
  }) vars.users);

  ###### Home Manager Configuration #######
  home-manager = {
    useUserPackages = true;
    useGlobalPkgs = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs host vars; };

    users = builtins.listToAttrs (map (user:
      let
        primary = isPrimary user;
        extraPkgs = with pkgs; lib.optionals (!primary) [
          hyfetch
          fastfetch
          fd
          gcc
        ];
      in
      {
        name = user.name;
        value = { pkgs, ... }: {
          home.username = user.name;
          home.homeDirectory = "/home/${user.name}";
          home.stateVersion = "25.11";

          home.sessionVariables = lib.optionalAttrs primary {
            EDITOR = vars.editor or "nvim";
            VISUAL = vars.editor or "nvim";
            SUDO_EDITOR = vars.editor or "nvim";
            BROWSER = vars.browser or "librewolf";
          };

          imports = [
            ../home
            (let
              userFileExists = builtins.pathExists ../home/nixvim/${user.name}.nix;
              fileName = if userFileExists then user.name else "default";
            in
            ../home/nixvim/${fileName}.nix)
          ];

          home.packages = extraPkgs;

          home.activation = lib.optionalAttrs primary {
            copyWallpapers = hmLib.hm.dag.entryAfter [ "writeBoundary" ] ''
              TARGET_DIR="/home/${user.name}/Pictures/wallpapers"
              SRC_PATH="${../../assets/wallpapers}"

              /run/current-system/sw/bin/rm -rf "$TARGET_DIR" || true
              /run/current-system/sw/bin/mkdir -p "$TARGET_DIR"

              if [ -d "$SRC_PATH" ]; then
                /run/current-system/sw/bin/cp -rfL "$SRC_PATH"/. "$TARGET_DIR/" || true
              fi

              /run/current-system/sw/bin/chmod 0700 "$TARGET_DIR" || true
              /run/current-system/sw/bin/find "$TARGET_DIR" -type f -exec /run/current-system/sw/bin/chmod 0600 {} + || true
            '';
          };

          programs.git = {
            enable = true;
            settings = {
              user = {
                name = "${user.gitUsername}";
                email = "${user.gitEmail}";
              };
            };
          };

          programs.tmux = lib.mkIf primary {
            enable = vars.tmuxEnable or false;
          };
          programs.wezterm = lib.mkIf primary {
            enable = vars.weztermEnable or false;
          };
          programs.ghostty = lib.mkIf primary {
            enable = vars.ghosttyEnable or false;
          };
          programs.helix = lib.mkIf primary {
            enable = vars.helixEnable or false;
          };

          programs.bash = lib.mkIf (!primary) {
            enable = true;
            shellAliases = {
              ls = "ls -a --color";
              nrs = "nh os switch";
            };
          };
        };
      }) vars.users);
  };
}
