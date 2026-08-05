{ config, pkgs, host, inputs, lib, vars, ... }:

let
  hmLib = inputs.home-manager.lib;
  dm = config.custom.displayManagerParsed;

  shells = {
    bash = pkgs.bashInteractive;
    fish = pkgs.fish;
  };

  systemAliases = {
    nrs = "sudo nixos-rebuild switch";
  };

  buildUserConfig = user:
    {
      isNormalUser = user.isNormalUser or true;
      extraGroups = user.extraGroups or [ ];
      shell = shells.${user.shell or "bash"};
    }
    // lib.optionalAttrs (!(user.minimal or false)) {
      createHome = true;
    }
    // lib.optionalAttrs (user ? homeDirectory && user.homeDirectory != null && user.homeDirectory != "") {
      home = user.homeDirectory;
    }
    // lib.optionalAttrs (user ? description && user.description != null) {
      description = user.description;
    }
    // lib.optionalAttrs ((user.sshKeys or [ ]) != [ ]) {
      openssh.authorizedKeys.keys = user.sshKeys;
    }
    // lib.optionalAttrs (user ? initialPassword && user.initialPassword != null) {
      initialPassword = user.initialPassword;
    }
    // lib.optionalAttrs (user ? hashedPassword && user.hashedPassword != null) {
      hashedPassword = user.hashedPassword;
    };
in {
  users.users = builtins.listToAttrs (map (user: {
    name = user.name;
    value = buildUserConfig user;
  }) vars.users);

  home-manager = {
    useUserPackages = true;
    useGlobalPkgs = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs host vars dm; };

    users = builtins.listToAttrs (map (user: {
      name = user.name;
      value = { pkgs, ... }:
        # Minimal users (e.g. service accounts) get no home-manager config
        if user.minimal or false then {
          home.username = user.name;
          home.homeDirectory =
            if user ? homeDirectory && user.homeDirectory != null && user.homeDirectory != ""
            then user.homeDirectory
            else "/home/${user.name}";
          home.stateVersion = "25.11";
          home.pointerCursor.enable = true;
        }
        else let
          userAliases =
            if !(builtins.elem "wheel" (user.extraGroups or [ ]))
            then builtins.removeAttrs systemAliases [ "nrs" ]
            else systemAliases;
        in {
          home.username = user.name;
          home.homeDirectory =
            if user ? homeDirectory && user.homeDirectory != null && user.homeDirectory != ""
            then user.homeDirectory
            else "/home/${user.name}";
          home.stateVersion = "25.11";

          home.pointerCursor.enable = true;

          home.sessionVariables = {
            EDITOR = vars.editor or "nvim";
            VISUAL = vars.editor or "nvim";
            SUDO_EDITOR = vars.editor or "nvim";
          } // lib.optionalAttrs ((vars.browser or null) != null) {
            BROWSER = vars.browser;
          };

          imports = lib.optional (!(user.minimal or false)) ../home ++ [
            (let
              nixvimFile =
                if user ? nixvimConfig && user.nixvimConfig != null
                then user.nixvimConfig
                else if builtins.pathExists ../home/nixvim/${user.name}.nix
                then user.name
                else "base";
              nixvimPath = ../home/nixvim/${nixvimFile}.nix;
            in
              if builtins.pathExists nixvimPath then nixvimPath
              else throw ''
                Nixvim config "${nixvimFile}.nix" not found at modules/home/nixvim/.
                Available: ${builtins.toString (builtins.attrNames (builtins.readDir ../home/nixvim))}
                Set nixvimConfig = "default" for shared config, or create the file.
              '')
          ];

          home.packages = map (name:
            lib.getAttrFromPath (lib.splitString "." name) pkgs
          ) (user.extraPkgs or [ ]);

          home.activation = lib.optionalAttrs dm.graphical {
            copyWallpapers = hmLib.hm.dag.entryAfter [ "writeBoundary" ] ''
              TARGET_DIR="/home/${user.name}/Pictures/Wallpapers"
              SRC_PATH="${../../assets/wallpapers}"
              mkdir -p "$TARGET_DIR"
              # Symlink nix-managed wallpapers alongside user's own images
              for f in "$SRC_PATH"/*; do
                dest="$TARGET_DIR/$(basename "$f")"
                # Skip if already linking to the same store path
                if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$f" ]; then
                  continue
                fi
                # Replace stale symlink/file only, not the whole dir
                rm -f "$dest"
                ln -s "$f" "$dest"
              done
            '';
          };

          programs.ssh = lib.mkIf (user ? githubSSHKey) {
            enable = true;
            enableDefaultConfig = false;
            settings."github.com" = {
              hostname = "github.com";
              identityFile = user.githubSSHKey;
              identitiesOnly = true;
            };
          };

          programs.git = {
            enable = true;
            settings.user = {
              name = "${user.gitUsername or ""}";
              email = "${user.gitEmail or ""}";
            };
          };

          programs.bash = {
            enable = true;
            shellAliases = userAliases // (user.shellAliases or { });
          };

          programs.fish.shellAliases =
            userAliases // { ls = "ls --color"; } // (user.shellAliases or { });
        };
    }) vars.users);
  };
}
