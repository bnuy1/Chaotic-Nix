{
  config,
  lib,
  pkgs,
  ...
}:

let
  domain = "bnuy.dev";
  chatDomain = "chat.${domain}";
  coturn-realm = "turn.${domain}";
in
{
  # open the firewall
  networking.firewall.allowedTCPPorts = [
    6167
    8080
    8443
    3478
    5349
  ];

  services = {
    matrix-continuwuity = {
      enable = true;
      settings.global = {
        address = [
          "0.0.0.0"
          "192.168.0.69"
        ];
        server_name = "chat.bnuy.dev";
        new_user_displayname_suffix = "🏳️‍🌈";
        turn_secret_file = "/run/credentials/continuwuity.service/turn-secret";
        #database_path = "/var/lib/continuwuity";

        #port = [6167];

        max_request_size = 20000000; # in bytes, ~20 MB
        allow_registration = true;
        registration_token = "ilovemalsomuch"; # A registration token is required when registration is allowed.
        allow_federation = false;
        allow_encryption = true;
        #CONTINUWUITY_ALLOW_CHECK_FOR_UPD 'true'
        trusted_servers = [ "bnuy.dev" ];
        #CONTINUWUITY_LOG: warn,state_res=warn
        # TURN URIs that clients should connect to
        turn_uris = [
          "turn:turn.bnuy.dev?transport=udp"
          "turn:turn.bnuy.dev?transport=tcp"
          "turns:turn.bnuy.dev?transport=udp"
          "turns:turn.bnuy.dev?transport=tcp"
        ];
      };
    };

    # Set up livekit for voice calls with continuwuity
    #services.livekit = {
    #  enable = true;
    #};
    coturn = {
      enable = true;
      no-cli = true;
      no-tcp-relay = false;

      # these ports are default, exiplicit here for human reasons
      tls-listening-port = 5349;
      alt-tls-listening-port = 5350;
      listening-port = 3478;
      alt-listening-port = 3479;

      # port range for clients communications, pick at your option
      min-port = 43000;
      max-port = 43200;

      # to limit users ask for a pre-shared secret string
      use-auth-secret = true;
      static-auth-secret = "zshglhovtbcobwqncgpaduntddjia";

      # your DNS must resolv this subdomain (choose any name
      # you want, `turn' is just a common choice), ensure A and
      # AAAA records, SRV records are optional for Matrix
      realm = "turn.bnuy.dev";

      # not a good Nix practice, but quick and simple
      # ACME module save certs there
      cert = "/var/lib/acme/turn.domain.tld/full.pem";
      pkey = "/var/lib/acme/turn.domain.tld/key.pem";
      extraConfig = ''
        # Disallow older versions of TLS encryption
        no-tlsv1
        no-tlsv1_1
        # Monitoring 
        # prometheus
        # for debugging:
        # verbose
        # ban private IP ranges:
        no-multicast-peers
        denied-peer-ip=0.0.0.0-0.255.255.255
        denied-peer-ip=10.0.0.0-10.255.255.255
        denied-peer-ip=100.64.0.0-100.127.255.255
        denied-peer-ip=127.0.0.0-127.255.255.255
        denied-peer-ip=169.254.0.0-169.254.255.255
        denied-peer-ip=172.16.0.0-172.31.255.255
        denied-peer-ip=192.0.0.0-192.0.0.255
        denied-peer-ip=192.0.2.0-192.0.2.255
        denied-peer-ip=192.88.99.0-192.88.99.255
        denied-peer-ip=192.168.0.0-192.168.255.255
        denied-peer-ip=198.18.0.0-198.19.255.255
        denied-peer-ip=198.51.100.0-198.51.100.255
        denied-peer-ip=203.0.113.0-203.0.113.255
        denied-peer-ip=240.0.0.0-255.255.255.255
        denied-peer-ip=::1
        denied-peer-ip=64:ff9b::-64:ff9b::ffff:ffff
        denied-peer-ip=::ffff:0.0.0.0-::ffff:255.255.255.255
        denied-peer-ip=100::-100::ffff:ffff:ffff:ffff
        denied-peer-ip=2001::-2001:1ff:ffff:ffff:ffff:ffff:ffff:ffff
        denied-peer-ip=2002::-2002:ffff:ffff:ffff:ffff:ffff:ffff:ffff
        denied-peer-ip=fc00::-fdff:ffff:ffff:ffff:ffff:ffff:ffff:ffff
        denied-peer-ip=fe80::-febf:ffff:ffff:ffff:ffff:ffff:ffff:ffff
      ''; # extraConfig
    }; # coturn
  };
}
