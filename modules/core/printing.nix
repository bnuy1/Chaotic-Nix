{
  vars,
  pkgs,
  lib,
  ...
}:
{
  services = {
    printing = {
      enable = vars.printEnable or false;
      drivers = with pkgs; lib.optionals (vars.canonPrinterSupport or false) [ cnijfilter2 ];
    };
    avahi = {
      enable = vars.printEnable or false;
      nssmdns4 = true;
      openFirewall = true;
    };
    ipp-usb.enable = vars.printEnable or false;
  };

  custom.allowUnfreePackages = lib.optionals (vars.canonPrinterSupport or false) [
    "cnijfilter2"
  ];
}
