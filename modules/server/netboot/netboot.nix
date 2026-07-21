{ config, lib, pkgs, inputs, vars, ... }:

let
  cfg = config.services.netboot;
  bootFile = "bootx64.efi";

  sshKeys = lib.concatMap (u: u.sshKeys or []) (vars.users or []);
  hostKeys = if builtins.pathExists ./host-keys.nix then import ./host-keys.nix else [];
  netbootKeys = sshKeys ++ hostKeys;

  netbootSslCert = pkgs.runCommand "netboot-ssl-cert" {
    nativeBuildInputs = [ pkgs.openssl ];
    listenIp = cfg.listenIp;
    serverName = if cfg.serverName != null then cfg.serverName else "";
  } ''
    mkdir -p $out
    if [ -n "$serverName" ]; then
      openssl req -x509 -newkey rsa:4096 \
        -keyout $out/key.pem \
        -out $out/cert.pem \
        -days 3650 -nodes \
        -subj "/CN=$serverName" \
        -addext "subjectAltName=DNS:$serverName,IP:$listenIp"
    else
      openssl req -x509 -newkey rsa:4096 \
        -keyout $out/key.pem \
        -out $out/cert.pem \
        -days 3650 -nodes \
        -subj "/CN=$listenIp" \
        -addext "subjectAltName=IP:$listenIp"
    fi
    chmod 644 $out/cert.pem
    chmod 640 $out/key.pem
  '';

  ipxeBase = pkgs.ipxe.override {
    enableDefaultPlatformTargets = false;
    additionalTargets = {
      "bin-x86_64-efi/ipxe-legacy.efi" = null;
    };
    firmwareBinary = "ipxe-legacy.efi";
    additionalOptions = [ "CONSOLE_CMD" ];
  };

  ipxeBoot = ipxeBase.overrideAttrs (old: {
    makeFlags = (old.makeFlags or []) ++ [
      "CERT=${netbootSslCert}/cert.pem"
      "TRUST=${netbootSslCert}/cert.pem"
    ];
    installPhase = (old.installPhase or "") + ''
      rm -f $out/undionly.kpxe.0
    '';
  });

  wgKeys = if builtins.pathExists ./wg-keys.nix then import ./wg-keys.nix else null;

  fallbackHostWgKeys = pkgs.runCommand "netboot-host-wg-keys" {
    nativeBuildInputs = [ pkgs.wireguard-tools ];
  } ''
    mkdir -p $out
    wg genkey | tee $out/private | wg pubkey > $out/public
  '';

  fallbackClientWgKeys = pkgs.runCommand "netboot-client-wg-keys" {
    nativeBuildInputs = [ pkgs.wireguard-tools ];
  } ''
    mkdir -p $out
    wg genkey | tee $out/private | wg pubkey > $out/public
  '';

  hostWgPublicKey = if wgKeys != null then wgKeys.hostPublicKey
    else lib.strings.trim (builtins.readFile "${fallbackHostWgKeys}/public");
  clientWgPublicKey = if wgKeys != null then wgKeys.clientPublicKey
    else lib.strings.trim (builtins.readFile "${fallbackClientWgKeys}/public");
  hostPrivateKeyFile = if wgKeys != null then wgKeys.hostPrivateKeyFile
    else "${fallbackHostWgKeys}/private";
  clientPrivateKeyFile = if wgKeys != null then wgKeys.clientPrivateKeyFile
    else "${fallbackClientWgKeys}/private";

  evalConfig = import "${toString pkgs.path}/nixos/lib/eval-config.nix";
  netbootConfig = evalConfig {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [
      "${toString pkgs.path}/nixos/modules/installer/netboot/netboot-minimal.nix"
      {
        services.openssh = {
          enable = true;
          settings.PasswordAuthentication = false;
        };
        users.users.root.openssh.authorizedKeys.keys = netbootKeys;

        networking.wireguard.interfaces.wg0 = {
          ips = [ "10.0.0.2/24" ];
          privateKeyFile = clientPrivateKeyFile;
          peers = [
            {
              publicKey = hostWgPublicKey;
              endpoint = "${cfg.listenIp}:51820";
              allowedIPs = [ "10.0.0.0/24" ];
              persistentKeepalive = 25;
            }
          ];
        };

        environment.systemPackages = with pkgs; [
          neovim
          wireguard-tools
          curl
          wget
          git
          rsync
        ] ++ cfg.extraPackages;

        system.stateVersion = lib.versions.majorMinor config.system.nixos.version;
      }
    ];
  };

  build = netbootConfig.config.system.build;
  kernelFile = netbootConfig.config.boot.kernelPackages.kernel.target;

  autoexecScript = pkgs.writeText "autoexec.ipxe" ''
    #!ipxe

    :start
    set menu-timeout 15000
    set menu-default nixos
    cpair --foreground 7 --background 4 0
    cpair --foreground 7 --background 4 1
    cpair --foreground 0 --background 7 2
    cpair --foreground 6 --background 4 3

    menu bnuy boot [''${net0/ip}]
    item --gap --
    item --gap --
    item --gap --
    item --key n nixos    [n] NixOS Kexec (SSH + WireGuard VPN)
    item --key i isos     [i] Boot ISO from /srv/iso/
    item --key u sysutils [u] Sysutils (hardware / recovery / antivirus)
    item --gap --     --------------------------------
    item --key s shell    [s] iPXE Shell
    item --key r reboot   [r] Reboot
    item --key e exit     [e] Exit to BIOS
    choose --default ''${menu-default} --timeout ''${menu-timeout} selected && goto ''${selected} || goto ''${menu-default}

    :nixos
    kernel https://${cfg.listenIp}:${toString cfg.httpsPort}/nixos/bzImage init=${build.toplevel}/init loglevel=4 ''${cmdline}
    initrd https://${cfg.listenIp}:${toString cfg.httpsPort}/nixos/initrd
    boot

    :isos
    chain https://${cfg.listenIp}:${toString cfg.httpsPort}/iso-menu.ipxe || goto start
    goto start

    :sysutils
    chain https://${cfg.listenIp}:${toString cfg.httpsPort}/sysutils.ipxe || goto start
    goto start

    :shell
    shell
    goto start

    :reboot
    reboot

    :exit
    exit
  '';
  wrapperInitrd = pkgs.runCommand "wrapper-initrd" {
    nativeBuildInputs = [ pkgs.busybox ];
  } ''
    mkdir -p $out/rootfs/bin $out/rootfs/etc/ssl/certs
    cp ${pkgs.busybox}/bin/busybox $out/rootfs/bin/
    cp ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt $out/rootfs/etc/ssl/certs/ca-certificates.crt
    cp ${./wrapper-initrd/init} $out/rootfs/init
    chmod +x $out/rootfs/init
    cd $out/rootfs
    find . | cpio -o -H newc | gzip > $out/initrd.gz
  '';

  genMenuSh = pkgs.runCommand "gen-menu.sh" { } ''
    mkdir -p $out/bin
    cp ${./gen-menu.sh} $out/bin/gen-menu.sh
    chmod +x $out/bin/gen-menu.sh
  '';

in
{
  imports = [
    ../vpn
  ];

  options = {
    services.netboot = {
      enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable PXE netboot server (DHCP + TFTP + HTTPS boot files)";
    };

    interface = lib.mkOption {
      type = lib.types.str;
      default = "wlan0";
      description = "Network interface for DHCP and TFTP";
    };

    listenIp = lib.mkOption {
      type = lib.types.str;
      default = "192.168.1.1";
      description = "IP address the netboot server listens on";
    };

    serverName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Optional domain name for external access.
        When set, autoexec URLs use this instead of listenIp,
        and the SSL cert includes DNS:serverName alongside IP:listenIp.
        Leave null for pure local/offline IP-based operation.
      '';
    };

    dhcpRange = lib.mkOption {
      type = lib.types.str;
      default = "192.168.1.100,192.168.1.150,12h";
      description = "DHCP lease range for PXE clients";
    };

    tftpRoot = lib.mkOption {
      type = lib.types.path;
      default = "/srv/tftp";
      description = "TFTP root directory";
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Port for HTTP server (serves kernel, initrd, ISOs)";
    };

    httpsPort = lib.mkOption {
      type = lib.types.port;
      default = 8443;
      description = "Port for HTTPS server (serves kernel + initrd)";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra packages to include in the netboot image";
    };
  };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ ipxeBoot genMenuSh pkgs.xorriso pkgs.p7zip pkgs.libarchive ];

    services.dnsmasq = {
      enable = true;
      settings = {
        interface = cfg.interface;
        port = 0;
        dhcp-range = cfg.dhcpRange;
        dhcp-match = [
          "set:ipxe,175"
        ];
        dhcp-boot = [
          "tag:!ipxe,${bootFile}"
          "tag:ipxe,autoexec.ipxe"
        ];
        enable-tftp = true;
        tftp-root = cfg.tftpRoot;
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts."netboot-http" = {
        listen = [
          {
            addr = cfg.listenIp;
            port = cfg.httpPort;
          }
        ];
        root = cfg.tftpRoot;
        locations."/iso/" = {
          alias = "/srv/iso/";
          extraConfig = "autoindex on;";
        };
        locations."/iso-files/" = {
          root = cfg.tftpRoot;
          extraConfig = "autoindex on;";
        };
      };

      virtualHosts."netboot-https" = {
        listen = [
          {
            addr = cfg.listenIp;
            port = cfg.httpsPort;
            ssl = true;
          }
        ];
        root = cfg.tftpRoot;
        addSSL = true;
        sslCertificate = "${netbootSslCert}/cert.pem";
        sslCertificateKey = "${netbootSslCert}/key.pem";
        locations."/iso/" = {
          alias = "/srv/iso/";
          extraConfig = "autoindex on;";
        };
        locations."/iso-files/" = {
          root = cfg.tftpRoot;
          extraConfig = "autoindex on;";
        };
      };
    };

    services.vpn = {
      enable = true;
      interface = "wg0";
      listenPort = 51820;
      host = {
        address = "10.0.0.1/24";
        privateKeyFile = hostPrivateKeyFile;
      };
      peers = [
        {
          publicKey = clientWgPublicKey;
          allowedIPs = [ "10.0.0.2/32" ];
          persistentKeepalive = 25;
        }
      ];
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.tftpRoot} 0755 root root -"
      "d ${cfg.tftpRoot}/nixos 0755 root root -"
      "d ${cfg.tftpRoot}/iso-files 0755 root root -"
      "d /srv/iso 0755 root root -"
      "d /srv/iso/sysutils 0755 root root -"
      "d /srv/iso/sysutils/hardware 0755 root root -"
      "d /srv/iso/sysutils/recovery 0755 root root -"
      "d /srv/iso/sysutils/antivirus 0755 root root -"
      "L+ ${cfg.tftpRoot}/${bootFile} - - - - ${ipxeBoot}/ipxe-legacy.efi"
      "L+ ${cfg.tftpRoot}/autoexec.ipxe - - - - ${autoexecScript}"
      "L+ ${cfg.tftpRoot}/ca.crt - - - - ${netbootSslCert}/cert.pem"
      "L+ ${cfg.tftpRoot}/nixos/bzImage - - - - ${build.kernel}/${kernelFile}"
      "L+ ${cfg.tftpRoot}/nixos/initrd - - - - ${build.netbootRamdisk}/initrd"
      "L+ ${cfg.tftpRoot}/wrapper-initrd.gz - - - - ${wrapperInitrd}/initrd.gz"
      "L+ ${cfg.tftpRoot}/wimboot - - - - ${pkgs.wimboot}/share/wimboot/wimboot.x86_64.efi"
    ];

    networking.firewall.allowedUDPPorts = [ 67 69 ];
    networking.firewall.allowedTCPPorts = [
      cfg.httpPort
      cfg.httpsPort
    ];

    systemd.services.gen-netboot-menu = {
      description = "Regenerate netboot ISO menu";
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Environment = [
          "ISO_DIR=/srv/iso"
          "OUTPUT=/srv/tftp/iso-menu.ipxe"
          "LISTEN_IP=${cfg.listenIp}"
          "HTTPS_PORT=${toString cfg.httpsPort}"
          "TFTP_ROOT=${cfg.tftpRoot}"
          "PATH=${lib.makeBinPath [ pkgs.xorriso pkgs.p7zip pkgs.libarchive pkgs.bash pkgs.coreutils pkgs.gnugrep pkgs.gnused pkgs.iproute2 pkgs.gawk ]}"
        ];
      };
      script = ''
        ${pkgs.bash}/bin/bash ${genMenuSh}/bin/gen-menu.sh
      '';
    };

    systemd.timers.gen-netboot-menu = {
      description = "Daily netboot ISO menu regeneration";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };
  };
}
