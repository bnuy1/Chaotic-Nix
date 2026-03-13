{ host, ... }:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz";
  inherit (import ../../hosts/${host}/variables.nix) systemUsername;
  inherit (import ../../hosts/${host}/variables.nix) gitUsername;
  inherit (import ../../hosts/${host}/variables.nix) gitEmail;
in
{
  imports = [
    (import "${home-manager}/nixos")
  ];

  # In the future it would be cool to have a arbatrary number of users that would be itterated through like a list

  users.users.fur3.isNormalUser = true;

  home-manager = {
    useUserPackages = true;
    useGlobalPkgs = true;
    backupFileExtension = "backup";

    # Per user configs

    users.${systemUsername} =
      { pkgs, ... }:
      {
        #install common apps
        imports = [ ../home ];
        programs.bash.enable = true;

        programs.git = {
          enable = true;
          lfs.enable = true;
          settings = {
            user = {
              name = "${gitUsername}";
              email = "${gitEmail}";
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
  };
}
