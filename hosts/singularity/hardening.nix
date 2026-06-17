{ ... }:
{
  boot.kernelParams = [
    "page_poison=1"
    "slab_nomerge"
    "init_on_alloc=1"
    "init_on_free=1"
  ];

  boot.kernel.sysctl = {
    "net.ipv4.tcp_syncookies" = "1";
    "net.ipv4.conf.all.rp_filter" = "1";
    "net.ipv4.conf.default.rp_filter" = "1";
    "net.ipv4.conf.all.accept_redirects" = "0";
    "net.ipv4.conf.default.accept_redirects" = "0";
    "net.ipv4.conf.all.secure_redirects" = "0";
    "net.ipv4.conf.default.secure_redirects" = "0";
    "net.ipv6.conf.all.accept_redirects" = "0";
    "net.ipv6.conf.default.accept_redirects" = "0";
    "net.ipv4.conf.all.log_martians" = "1";
    "net.ipv4.conf.default.log_martians" = "1";
    "net.ipv4.icmp_echo_ignore_broadcasts" = "1";
    "net.ipv4.icmp_ignore_bogus_error_responses" = "1";
  };
}
