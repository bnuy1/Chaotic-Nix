{
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

    style = ''
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
          color: #ffffff;
      }

      #workspaces button {
          padding: 0 5px;
          margin: 0 3px;
          color: #ffffff;
          border-bottom: 3px solid transparent;
      }

      #workspaces button.focused {
          background: rgba(100, 114, 125, 0.2);
          border-bottom: 3px solid #ffffff;
      }

      #submap {
          background: transparent;
          border-bottom: 3px solid #ffffff;
      }

      #clock, #battery, #cpu, #memory, #network, #pulseaudio, #temperature, #backlight, #idle_inhibitor {
          padding: 0 6px;
          margin: 0 5px;
      }

      #clock {
          background-color: transparent;
          color: #ffffff;
      }

      #battery.charging {
          color: #ffffff;
      }

      @keyframes blink {
          to {
              background-color: rgba(1, 1, 1, 0.6);
          }
      }

      #battery.warning:not(.charging) {
          background: #f53c3c;
          color: #ffffff;
          animation-name: blink;
          animation-duration: 0.5s;
          animation-timing-function: linear;
          animation-iteration-count: infinite;
          animation-direction: alternate;
      }

      #cpu {
          background: transparent;
          border-bottom: 3px solid #ffffff;
          color: #ffffff;
      }

      #memory {
          background: transparent;
          border-bottom: 3px solid #ffffff;
          color: #ffffff;
      }

      #network {
          background: transparent;
          color: #ffffff;
      }

      #network.disconnected {
          background: transparent;
          color: crimson;
      }

      #pulseaudio {
          background: transparent;
          color: #ffffff;
      }

      #pulseaudio.muted {
          border-bottom: 3px solid #ff0000;
      }

      #tray {
          background-color: transparent;
      }
    '';
  };
}
