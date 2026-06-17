{
  vars,
  pkgs,
  lib,
  ...
}:
{
  services = {
    printing = {
      enable = vars.printEnable;
      drivers = with pkgs; lib.optionals vars.printEnable [ cnijfilter2 ];
    };
    avahi = {
      enable = vars.printEnable;
      nssmdns4 = true;
      openFirewall = true;
    };
    ipp-usb.enable = vars.printEnable;
  };

  custom.allowUnfreePackages = lib.optionals (vars.printEnable or false) [
    "cnijfilter2"
  ];
  # install a printer drivers specific to my setup
  environment.systemPackages = with pkgs; lib.optionals vars.printEnable [ cnijfilter2 ];
}
