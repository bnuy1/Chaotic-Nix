{ config, lib, pkgs, inputs, vars, ... }:

let
  cfg = config.services.netboot;
  bootFile = "bootx64.efi";

  sshKeys = lib.concatMap (u: u.sshKeys or []) (vars.users or []);
  hostKeys = if builtins.pathExists ./host-keys.nix then import ./host-keys.nix else [];
  netbootKeys = sshKeys ++ hostKeys;

  ipxeWithCert = (pkgs.ipxe.override {
    additionalOptions = [ "CERT_CMD" ];
  }).overrideAttrs (old: {
    makeFlags = (old.makeFlags or []) ++ [
      "CERT=${netbootSslCert}/cert.pem"
      "TRUST=${netbootSslCert}/cert.pem"
    ];
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

  netbootSslCert = pkgs.runCommand "netboot-ssl-cert" {
    nativeBuildInputs = [ pkgs.openssl ];
    listenIp = cfg.listenIp;
  } ''
    mkdir -p $out
    openssl req -x509 -newkey rsa:4096 \
      -keyout $out/key.pem \
      -out $out/cert.pem \
      -days 3650 -nodes \
      -subj "/CN=$listenIp" \
      -addext "subjectAltName=IP:$listenIp"
    chmod 644 $out/cert.pem
    chmod 640 $out/key.pem
  '';

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
  kernelTarget = netbootConfig.pkgs.stdenv.hostPlatform.linux-kernel.target;

  autoexecScript = pkgs.writeText "autoexec.ipxe" ''
    #!ipxe
    kernel https://${cfg.listenIp}:${toString cfg.httpsPort}/bzImage init=${build.toplevel}/init loglevel=4 ''${cmdline}
    initrd https://${cfg.listenIp}:${toString cfg.httpsPort}/initrd
    boot
  '';
in
{
  imports = [
    ../vpn
  ];

  options.services.netboot = {
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
      description = "Port for HTTP server (serves CA cert to iPXE)";
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

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ ipxeWithCert ];

    services.dnsmasq = {
      enable = true;
      settings = {
        interface = cfg.interface;
        bind-interfaces = true;
        port = 0;
        dhcp-range = cfg.dhcpRange;
        dhcp-match = "set:ipxe,175";
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
      };

      virtualHosts."netboot-https" = {
        listen = [
          {
            addr = cfg.listenIp;
            port = cfg.httpsPort;
            ssl = true;
          }
        ];
        root = "${cfg.tftpRoot}/nixos";
        addSSL = true;
        sslCertificate = "${netbootSslCert}/cert.pem";
        sslCertificateKey = "${netbootSslCert}/key.pem";
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
      "L+ ${cfg.tftpRoot}/${bootFile} - - - - ${ipxeWithCert}/ipxe.efi"
      "L+ ${cfg.tftpRoot}/autoexec.ipxe - - - - ${autoexecScript}"
      "L+ ${cfg.tftpRoot}/nixos/bzImage - - - - ${build.kernel}/${kernelTarget}"
      "L+ ${cfg.tftpRoot}/nixos/initrd - - - - ${build.netbootRamdisk}/initrd"
      "L+ ${cfg.tftpRoot}/ca.crt - - - - ${netbootSslCert}/cert.pem"
    ];

    networking.firewall.allowedUDPPorts = [ 67 69 ];
    networking.firewall.allowedTCPPorts = [
      cfg.httpPort
      cfg.httpsPort
    ];
  };
}
