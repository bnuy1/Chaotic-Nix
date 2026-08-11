{ config, lib, pkgs, inputs, vars, ... }:

let
  cfg = config.services.netboot;
  bootFile = "bootx64.efi";
  # Network address of listenIp's /24 (used for PXE-proxy DHCP range)
  listenIpSubnet =
    (lib.concatStringsSep "." (lib.take 3 (lib.splitString "." cfg.listenIp))) + ".0";

  sshKeys = lib.concatMap (u: u.sshKeys or []) (vars.users or []);
  hostKeys = if builtins.pathExists ./host-keys.nix then import ./host-keys.nix else [];
  netbootKeys = sshKeys ++ hostKeys;

  # bnuy LAN CA root (step-ca on singularity). iPXE TRUST embeds this CA so
  # clients validate the runtime step-ca leaf cert served by netboot-https.
  # No self-signed certs anywhere (user policy); the leaf itself is issued at
  # runtime by the netboot-cert systemd service below.
  netbootTrustCa = ../step-ca/root_ca.crt;

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
      "TRUST=${netbootTrustCa}"
    ];
    installPhase = (old.installPhase or "") + ''
      rm -f $out/undionly.kpxe.0
    '';
  });

  # WireGuard is being replaced entirely by headscale. The netboot host will
  # join the tailnet as a headscale client (services.vpn) and be reachable only
  # by bnuy per the tailnet ACLs. All WireGuard integration below is commented
  # out until that headscale client is wired into the netboot host's config.
  # wgKeys = if builtins.pathExists ./wg-keys.nix then import ./wg-keys.nix else null;
  #
  # fallbackHostWgKeys = pkgs.runCommand "netboot-host-wg-keys" {
  #   nativeBuildInputs = [ pkgs.wireguard-tools ];
  # } ''
  #   mkdir -p $out
  #   wg genkey | tee $out/private | wg pubkey > $out/public
  # '';
  #
  # fallbackClientWgKeys = pkgs.runCommand "netboot-client-wg-keys" {
  #   nativeBuildInputs = [ pkgs.wireguard-tools ];
  # } ''
  #   mkdir -p $out
  #   wg genkey | tee $out/private | wg pubkey > $out/public
  # '';
  #
  # hostWgPublicKey = if wgKeys != null then wgKeys.hostPublicKey
  #   else lib.strings.trim (builtins.readFile "${fallbackHostWgKeys}/public");
  # clientWgPublicKey = if wgKeys != null then wgKeys.clientPublicKey
  #   else lib.strings.trim (builtins.readFile "${fallbackClientWgKeys}/public");
  # hostPrivateKeyFile = if wgKeys != null then wgKeys.hostPrivateKeyFile
  #   else "${fallbackHostWgKeys}/private";
  # clientPrivateKeyFile = if wgKeys != null then wgKeys.clientPrivateKeyFile
  #   else "${fallbackClientWgKeys}/private";

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

        # WireGuard access to the netboot host is being replaced by headscale;
        # the kexec image will join the tailnet via a headscale client instead.
        # networking.wireguard.interfaces.wg0 = {
        #   ips = [ "10.0.0.2/24" ];
        #   privateKeyFile = clientPrivateKeyFile;
        #   peers = [
        #     {
        #       publicKey = hostWgPublicKey;
        #       endpoint = "${cfg.listenIp}:51820";
        #       allowedIPs = [ "10.0.0.0/24" ];
        #       persistentKeepalive = 25;
        #     }
        #   ];
        # };

        environment.systemPackages = with pkgs; [
          neovim
          # wireguard-tools
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
  # kernel.target moved to passthru in newer nixpkgs
  kernelFile = netbootConfig.config.boot.kernelPackages.kernel.passthru.target
    or netbootConfig.config.boot.kernelPackages.kernel.target
    or "bzImage";

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
    item --key n nixos    [n] NixOS Kexec (SSH)
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
      description = "Network interface for DHCP and TFTP. Should be a dedicated LAN-only interface.";
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
      default = "${listenIpSubnet},proxy";
      description = ''
        dnsmasq DHCP range. Defaults to PXE-proxy mode: dnsmasq answers only
        PXE/boot requests and NEVER allocates leases, so the network's real
        DHCP server stays authoritative and this server cannot break the network.
        Override only if you intentionally want to hand out leases.
      '';
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
      # NOT 8443: that port is the headscale control-plane listener on 0.0.0.0
      # (vpn.bnuy.dev). If netboot-https bound the exact LAN IP on 8443, nginx
      # would route every connection to it — including the phone's VPN TLS
      # handshake via the router port-forward — and serve this cert instead of
      # the LE one, breaking the control plane. Netboot is LAN-only, so it can
      # take any free port.
      default = 8445;
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

    # PXE-proxy DHCP: answers boot requests on cfg.interface only, allocates no
    # leases (dhcpRange defaults to "<subnet>,proxy"). Cannot interfere with the
    # network's real DHCP server.
    services.dnsmasq = {
      enable = true;
      settings = {
        log-dhcp = true;
        interface = cfg.interface;
        port = 0;
        dhcp-range = cfg.dhcpRange;
        dhcp-match = [
          "set:ipxe,175"
        ];
        # dnsmasq only treats a client as PXE if its vendor class matches one of
        # these (default: "PXEClient"). iPXE identifies itself as "iPXE", so
        # register it too, otherwise proxy mode silently drops iPXE requests.
        dhcp-pxe-vendor = [
          "PXEClient,iPXE"
        ];
        dhcp-boot = [
          "tag:!ipxe,${bootFile}"
          "tag:ipxe,autoexec.ipxe"
        ];
        # Proxy-mode gotcha (dnsmasq >= 2.83): for UEFI clients (arch >= 6) the
        # DISCOVER reply deliberately omits both option 43 and the boot file when
        # exactly one matching pxe-service exists ("pxe_uefi_workaround"). The
        # client is expected to re-ask on port 4011, but common UEFI firmware
        # never does -> it gets an IP and then times out.
        # Fix: keep no plain pxe-service matching the EFI arch (7/9) so the
        # workaround returns 0, which lets dhcp-boot fill the BOOTP file field +
        # siaddr directly in the offer. Client arch: UEFI x86-64 firmware sends
        # option 93 = 7 (BC_EFI); iPXE may report 9 (x86-64_EFI) or 0 (x86PC).
        pxe-service = [
          "x86PC,\"NixOS iPXE\",${bootFile},${cfg.listenIp}"
          "tag:ipxe,BC_EFI,\"NixOS\",autoexec.ipxe,${cfg.listenIp}"
          "tag:ipxe,x86-64_EFI,\"NixOS\",autoexec.ipxe,${cfg.listenIp}"
        ];
        # iPXE fetches its boot script from DHCP option 175. Plain dhcp-option is
        # NOT sent in proxy replies; dhcp-option-pxe is.
        # encap:43,6,8 = PXE discovery control suboption (43.6) = 8: "use the
        # bootfile in this DHCP message, skip boot-server discovery". Some UEFI
        # firmware ignores the bootfile field without this hint.
        dhcp-option-pxe = [
          "encap:43,6,8"
          # Some firmware reads options 66/67 (TFTP server / bootfile) instead of
          # the BOOTP file field; the client explicitly requests them in option 55.
          "66,${cfg.listenIp}"
          "67,${bootFile}"
          "175,https://${cfg.listenIp}:${toString cfg.httpsPort}/autoexec.ipxe"
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
        sslCertificate = "/var/lib/netboot/ssl/cert.pem";
        sslCertificateKey = "/var/lib/netboot/ssl/key.pem";
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

    # WireGuard server for the netboot host: replaced by headscale (the netboot
    # host becomes a tailnet client reachable only by bnuy). Commented out until
    # the headscale client module is enabled on this host (services.vpn).
    # services.vpn = {
    #   enable = true;
    #   interface = "wg0";
    #   listenPort = 51820;
    #   host = {
    #     address = "10.0.0.1/24";
    #     privateKeyFile = hostPrivateKeyFile;
    #   };
    #   peers = [
    #     {
    #       publicKey = clientWgPublicKey;
    #       allowedIPs = [ "10.0.0.2/32" ];
    #       persistentKeepalive = 25;
    #     }
    #   ];
    # };

    systemd.tmpfiles.rules = [
      "d ${cfg.tftpRoot} 0755 root root -"
      "d ${cfg.tftpRoot}/nixos 0755 root root -"
      "d ${cfg.tftpRoot}/iso-files 0755 root root -"
      "d /srv/iso 0755 root root -"
      "d /srv/iso/sysutils 0755 root root -"
      "d /srv/iso/sysutils/hardware 0755 root root -"
      "d /srv/iso/sysutils/recovery 0755 root root -"
      "d /srv/iso/sysutils/antivirus 0755 root root -"
      "d /var/lib/netboot/ssl 0755 root root -"
      "L+ ${cfg.tftpRoot}/${bootFile} - - - - ${ipxeBoot}/ipxe-legacy.efi"
      "L+ ${cfg.tftpRoot}/autoexec.ipxe - - - - ${autoexecScript}"
      "L+ ${cfg.tftpRoot}/ca.crt - - - - ${netbootTrustCa}"
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

    # Issue/refresh the LAN leaf cert from the bnuy step-ca (no LE: netboot has
    # no public name, it is LAN-only on cfg.listenIp). Served by netboot-https,
    # validated by iPXE via the embedded TRUST CA. Runs before nginx at boot so
    # a clean start never serves a missing cert; refreshes daily.
    systemd.services.netboot-cert = {
      description = "Netboot: issue LAN TLS cert from bnuy step-ca";
      before = [ "nginx.service" ];
      wantedBy = [ "nginx.service" "multi-user.target" ];
      after = [ "step-ca.service" ];
      path = [ pkgs.step-cli pkgs.openssl pkgs.coreutils pkgs.diffutils pkgs.systemd ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 30;
        TimeoutStartSec = 0;
      };
      script = ''
        set -eu
        if [ -f /var/lib/netboot/ssl/cert.pem ] \
           && openssl x509 -checkend $((7 * 86400)) -noout -in /var/lib/netboot/ssl/cert.pem 2>/dev/null; then
          exit 0
        fi
        mkdir -p /var/lib/netboot/ssl
        ${pkgs.step-cli}/bin/step ca certificate \
          --ca-url https://127.0.0.1:9000 \
          --root ${netbootTrustCa} \
          --provisioner admin \
          --provisioner-password-file ${config.sops.secrets."step-ca/password".path} \
          --san ${cfg.listenIp} \
          --not-after=2160h \
          netboot /var/lib/netboot/ssl/cert.pem /var/lib/netboot/ssl/key.pem
        chmod 0644 /var/lib/netboot/ssl/cert.pem /var/lib/netboot/ssl/key.pem
        # Reload only when nginx is already up (see vpn-headscale-cert for the
        # deadlock this avoids at boot).
        systemctl is-active --quiet nginx.service \
          && systemctl reload nginx.service || true
      '';
    };

    systemd.timers.netboot-cert = {
      description = "Netboot: daily cert refresh";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };
  };
}
