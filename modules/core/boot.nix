{ pkgs, vars, lib, ... }:
let
  kernelOption = vars.kernel or "zen";
  kernelMap = {
    zen = pkgs.linuxPackages_zen;
    xanmod = pkgs.linuxPackages_xanmod;
    stable = pkgs.linuxPackages;
    lts = pkgs.linuxKernel.kernels.linux_6_12;
  };
  isHeadless = lib.hasSuffix "-headless" (vars.displayManager or "");
  secureBoot = vars.secureBoot or true;

  lonePlymouthTheme = pkgs.stdenv.mkDerivation {
    name = "lone-plymouth-theme";
    src = ../../assets/plymouth/lone;
    installPhase = ''
      mkdir -p $out/share/plymouth/themes/lone
      themePath=$out/share/plymouth/themes/lone
      sed "s|/usr/share/plymouth/themes/lone|$themePath|g" lone.plymouth > $out/share/plymouth/themes/lone/lone.plymouth
      cp lone.script progress-*.png $out/share/plymouth/themes/lone/
    '';
  };
in
{
  boot.kernelPackages = kernelMap.${kernelOption};

  boot.loader = {
    efi.canTouchEfiVariables = true;
    timeout = 2;
  };

  boot.lanzaboote = lib.mkIf secureBoot {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    configurationLimit = 5;
  };

  boot.loader.systemd-boot = lib.mkIf (!secureBoot) {
    enable = true;
    configurationLimit = 5;
  };

  boot.tmp.cleanOnBoot = true;

  # Parallel LUKS unlocking
  boot.initrd.systemd.enable = true;

  boot.kernelParams = [
    "preempt=full"
    "threadirqs"
  ] ++ lib.optionals (builtins.elem "amd" (vars.gpuDrivers or [])) [ "amdgpu.dc=1" ]
    ++ lib.optionals (!isHeadless) [ "splash" ] ++ [
    "slab_nomerge"
    "init_on_alloc=1"
    "init_on_free=1"
    "tpm_tis.interrupts=0"
  ];

  boot.plymouth = lib.mkIf (!isHeadless) {
    enable = true;
    themePackages = [ lonePlymouthTheme ];
    theme = lib.mkForce "lone";
  };

  boot.consoleLogLevel = 4;
}
