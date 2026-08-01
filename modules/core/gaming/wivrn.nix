{
  lib,
  vars,
  pkgs,
  ...
}:
{
  # WiVRn: OpenXR wireless streaming to standalone headsets (replaces ALVR).
  # Module opens 9757 tcp/udp; 5353/udp mDNS discovery is opened below.
  services.wivrn = {
    enable = vars.wivrnEnable or false;
    openFirewall = true;
    autoStart = true;
    highPriority = true; # cap_sys_nice for low-latency reprojection
    steam.enable = true; # let WiVRn launch Steam VR games from the headset
    steam.importOXRRuntimes = true; # Steam discovers the WiVRn OpenXR runtime
    config = {
      enable = true;
      json = {
        # Modern: route OpenVR games through xrizer (WiVRn upstream recommendation).
        # Not documented on the NixOS wiki, which only shows the LEGACY option.
        openvr-compat-path = "${pkgs.xrizer}/lib/xrizer";
        # LEGACY: OpenComposite (unmaintained) is what the NixOS wiki documents:
        # openvr-compat-path = "${pkgs.opencomposite}/lib/opencomposite";
      };
    };
  };

  services.avahi.openFirewall = lib.mkIf (vars.wivrnEnable or false) true;
}
