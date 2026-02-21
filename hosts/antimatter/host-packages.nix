{pkgs, config, lib,  ...}: {
    environment.systemPackages = with pkgs; [
      usbutils
    ];
}
