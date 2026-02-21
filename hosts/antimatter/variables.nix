{ config, lib, ... }:

{
  # Git Configuration ( For Pulling Software Repos )
  gitUsername = "Tyler Kelley";
  gitEmail = "tylerzanekelley@gmail.com";

  # Set Displau Manager
  # `tui` for Text login
  # `sddm` for graphical GUI (default)
  displayManager = "tui";

  # Emable/disable bundled applications
  tmuxEnable = false;
  weztermEnable = false;
  ghosttyEnable = false;
  # Note: This is evil-helix with VIM keybindings by default
  helixEnable = false;
  #To install: Enable here, zcli rebuild, then run zcli doom install
  doomEmacsEnable = false;

  # Hyprland Settings
  # Examples:
  # extraMonitorSettings = "monitor = Virtual-1,1920x1080@60,auto,1";
  # extraMonitorSettings = "monitor = HDMI-A-1,1920x1080@60,auto,1";
  # You can configure multiple monitors.
  # Inside the quotes, create a new line for each monitor.
  extraMonitorSettings = "

    ";

  # Waybar Settings (used when barChoice = "waybar")
  clock24h = false;

  browser = "brave";

  keyboardLayout = "us";
  keyboardVariant = "";
  consoleKeyMap = "us";

  # Enable NFS
  enableNFS = true;

  # Enable Printing Support
  printEnable = false;

  # Enable Thunar GUI File Manager
  # Dolphin is default File Manager
  thunarEnable = false;
}


