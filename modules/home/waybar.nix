{ config, lib, pkgs, ... }:

let
  c = config.stylix.base16Scheme;
in {
  stylix.targets.waybar.enable = true;

  programs.waybar = {
    enable = true;

    settings = [{
      layer = "top";
      height = 30;

      modules-left = ["hyprland/submap" "hyprland/workspaces"];
      modules-center = ["clock"];
      modules-right = ["network" "pulseaudio" "battery" "tray"];

      "hyprland/workspaces" = {
        "disable-scroll" = true;
        "all-outputs" = false;
        format = "{icon}";
      };

      "hyprland/submap" = {
        format = "<span style=\"italic\">{}</span>";
      };

      network = {
        "format-wifi" = "{signalStrength}% ";
        "format-ethernet" = "{ifname}: {ipaddr}/{cidr} ";
        "format-linked" = "{ifname} (No IP) ";
        "format-disconnected" = "Disconnected ⚠";
        "format-alt" = "{essid} {signalStrength}%";
      };

      pulseaudio = {
        format = "{volume}% {icon}   {format_source}";
        "format-bluetooth" = "{volume}% {icon} {format_source}";
        "format-muted" = "{icon}   {format_source}";
        "format-source" = "{volume}% ";
        "format-source-muted" = "";
        "format-icons" = {
          headphones = "";
          handsfree = "";
          headset = "";
          phone = "";
          portable = "";
          car = "";
          default = ["" "" ""];
        };
        "on-click" = "pavucontrol";
      };

      clock = {
        format = "{:%I:%M}  ";
        "format-alt" = "{:%A, %B %d, %Y (%I:%M)}  ";
        "tooltip-format" = "<tt><small>{calendar}</small></tt>";
        calendar = {
          mode = "year";
          "mode-mon-col" = 3;
          "weeks-pos" = "right";
          "on-scroll" = 1;
          format = {
            months = "<span color='#ffead3'><b>{}</b></span>";
            days = "<span color='#ecc6d9'><b>{}</b></span>";
            weeks = "<span color='#99ffdd'><b>W{}</b></span>";
            weekdays = "<span color='#ffcc66'><b>{}</b></span>";
            today = "<span color='#ff6699'><b><u>{}</u></b></span>";
          };
        };
        actions = {
          "on-click-right" = "mode";
          "on-scroll-up" = "tz_up";
          "on-scroll-down" = "tz_down";
        };
      };
    }];

    style = lib.mkForce ''
      @define-color foreground #${c.base05};
      @define-color background #${c.base00};
      @define-color color0 #${c.base00};
      @define-color color1 #${c.base08};
      @define-color color2 #${c.base0B};
      @define-color color3 #${c.base0A};
      @define-color color4 #${c.base0D};
      @define-color color5 #${c.base0E};
      @define-color color6 #${c.base0C};
      @define-color color7 #${c.base05};
      @define-color color8 #${c.base03};
      @define-color color9 #${c.base09};
      @define-color color10 #${c.base01};
      @define-color color11 #${c.base02};
      @define-color color12 #${c.base04};
      @define-color color13 #${c.base06};
      @define-color color14 #${c.base0F};
      @define-color color15 #${c.base07};

      * {
          border: none;
          border-radius: 0;
          font-family: "Font Awesome", Roboto, Helvetica, Arial, sans-serif;
          font-size: 13px;
          min-height: 0;
      }

      window#waybar {
          background: rgba(0,0,0, 0.5);
          border-bottom: 3px solid transparent;
          color: @foreground;
      }

      #workspaces button {
          padding: 0 5px;
          margin: 0 3px;
          color: @foreground;
          border-bottom: 3px solid transparent;
      }

      #workspaces button.focused {
          background: rgba(100, 114, 125, 0.2);
          border-bottom: 3px solid @color15;
      }

      #submap {
          background: transparent;
          border-bottom: 3px solid @color15;
      }

      #clock, #battery, #cpu, #memory, #network, #pulseaudio, #temperature, #backlight, #idle_inhibitor {
          padding: 0 6px;
          margin: 0 5px;
      }

      #clock {
          background-color: transparent;
          color: @foreground;
      }

      #battery.charging {
          color: @foreground;
      }

      @keyframes blink {
          to {
              background-color: rgba(1, 1, 1, 0.6);
          }
      }

      #battery.warning:not(.charging) {
          background: #f53c3c;
          color: @foreground;
          animation-name: blink;
          animation-duration: 0.5s;
          animation-timing-function: linear;
          animation-iteration-count: infinite;
          animation-direction: alternate;
      }

      #cpu {
          background: transparent;
          border-bottom: 3px solid @color5;
          color: @foreground;
      }

      #memory {
          background: transparent;
          border-bottom: 3px solid @color7;
          color: @foreground;
      }

      #network {
          background: transparent;
          color: @foreground;
      }

      #network.disconnected {
          background: transparent;
          color: crimson;
      }

      #pulseaudio {
          background: transparent;
          color: @foreground;
      }

      #pulseaudio.muted {
          border-bottom: 3px solid @color1;
      }

      #tray {
          background-color: transparent;
      }
    '';
  };
}
