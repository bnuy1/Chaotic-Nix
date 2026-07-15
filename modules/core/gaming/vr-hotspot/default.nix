{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.services.questHotspot;
  dnsmasqConf = pkgs.writeText "dnsmasq-quest.conf" ''
    interface=Quest5G
    bind-interfaces
    dhcp-range=${cfg.dhcpRange}
    dhcp-option=option:router,${cfg.gateway}
    dhcp-option=option:dns-server,8.8.8.8,8.8.4.4
    dhcp-leasefile=/var/lib/quest-hotspot/dnsmasq.leases
    no-resolv
    server=8.8.8.8
    server=8.8.4.4
    port=0
  '';
in
{
  options.services.questHotspot = {
    enable = lib.mkEnableOption "Quest 2 5GHz WiFi hotspot";

    phy = lib.mkOption {
      type = lib.types.str;
      default = "phy1";
      description = "iw phy name for the wireless adapter";
    };

    mac = lib.mkOption {
      type = lib.types.str;
      default = "76:19:f8:17:de:b6";
      description = "MAC address for the AP virtual interface";
    };

    ssid = lib.mkOption {
      type = lib.types.str;
      default = "Quest-5G";
    };

    password = lib.mkOption {
      type = lib.types.str;
      description = "WPA2 passphrase for the hotspot (stored in SOPS)";
    };

    channel = lib.mkOption {
      type = lib.types.int;
      default = 149;
    };

    gateway = lib.mkOption {
      type = lib.types.str;
      default = "10.42.0.1";
    };

    dhcpRange = lib.mkOption {
      type = lib.types.str;
      default = "10.42.0.10,10.42.0.200,255.255.255.0,24h";
    };

    upstreamInterface = lib.mkOption {
      type = lib.types.str;
      default = "wlan0";
      description = "Interface with internet access to NAT through";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.defaultSopsFile = ./secrets.yaml;
    sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    sops.secrets."quest-hotspot/password" = { };

    environment.systemPackages = [
      pkgs.hostapd
      pkgs.iw
    ];

    systemd.tmpfiles.rules = [
      "d /var/lib/quest-hotspot 0755 root root -"
      "d /run/quest-hotspot 0755 root root -"
    ];

    systemd.services.quest-hotspot = {
      description = "Quest 2 5GHz WiFi Hotspot";
      after = [ "network-online.target" "sops-nix.service" ];
      wants = [ "network-online.target" "sops-nix.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.iw
        pkgs.hostapd
        pkgs.iproute2
        pkgs.coreutils
        pkgs.gnugrep
      ];

      preStart = ''
        WIFI_PASS=$(tr -d '\n' < ${config.sops.secrets."quest-hotspot/password".path})
        printf '%s\n' \
          "interface=Quest5G" \
          "driver=nl80211" \
          "ssid=${cfg.ssid}" \
          "hw_mode=a" \
          "channel=${toString cfg.channel}" \
          "country_code=US" \
          "ieee80211n=1" \
          "ieee80211ax=1" \
          "wmm_enabled=1" \
          "ht_capab=[HT40+][LDPC][TX-STBC][RX-STBC1]" \
          "auth_algs=1" \
          "wpa=2" \
          "wpa_passphrase=$WIFI_PASS" \
          "wpa_key_mgmt=WPA-PSK" \
          "rsn_pairwise=CCMP" \
          > /run/quest-hotspot/hostapd-quest.conf

        # Create AP interface if needed
        if ! ip link show Quest5G >/dev/null 2>&1; then
          PHY=""
          for p in /sys/class/ieee80211/phy*; do
            if grep -q mt7921 "$p/device/uevent" 2>/dev/null; then
              PHY=$(basename "$p")
              break
            fi
          done
          if [ -z "$PHY" ]; then
            echo "ERROR: mt7921 adapter not found"
            exit 1
          fi
          iw phy "$PHY" interface add Quest5G type __ap addr ${cfg.mac}
        fi
        ip link set Quest5G up
        ip addr add ${cfg.gateway}/24 dev Quest5G 2>/dev/null || true
        iw dev Quest5G set txpower fixed 2200 2>/dev/null || true
        if [ -d /sys/class/net/wlan1 ]; then
          ip link set wlan1 down 2>/dev/null || true
        fi
      '';

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.bash}/bin/bash -c 'exec ${pkgs.hostapd}/bin/hostapd /run/quest-hotspot/hostapd-quest.conf'";
        ExecStartPost = "${pkgs.bash}/bin/bash -c 'sleep 2 && iw dev Quest5G set txpower fixed 2200 2>/dev/null || true && ip addr add ${cfg.gateway}/24 dev Quest5G 2>/dev/null || true'";
        ExecStop = "${pkgs.bash}/bin/bash -c 'ip link set Quest5G down 2>/dev/null || true'";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    systemd.services.quest-dnsmasq = {
      description = "DHCP server for Quest 2 hotspot";
      after = [ "quest-hotspot.service" ];
      wants = [ "quest-hotspot.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.dnsmasq ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.dnsmasq}/bin/dnsmasq --keep-in-foreground --user=root --conf-file=${dnsmasqConf}";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    networking.nat = {
      enable = true;
      internalInterfaces = [ "Quest5G" ];
      externalInterface = cfg.upstreamInterface;
    };

    networking.firewall.trustedInterfaces = [ "Quest5G" ];

    services.dnsmasq.settings.bind-interfaces = true;
  };
}
