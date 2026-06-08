{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    me_cleaner
    coreboot-utils
    coreboot-configurator
    coreboot-toolchain.x64
    flashrom
  ];
}
