{

  Primary-User = "fur3";
  Secondary-User = "raina";

  # Used by stylix
  defaultBackroundImage = ../../assets/wallpapers/Stocking.png;

  # Git Configuration ( For Pulling Software Repos )
  gitUsername = "Ha2k4r";
  gitEmail = "enigma558@proton.me";

  Secondary-User_gitUsername = "Indigo-69";
  Secondary-User_gitEmail = "wyfi08g@proton.me";

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
  extraMonitorSettings = "";

  # Waybar Settings (used when barChoice = "waybar")
  clock24h = false;

  browser = "librewolf";

  keyboardLayout = "us";
  keyboardVariant = "";
  consoleKeyMap = "us";

  # Enable NFS
  enableNFS = true;

  # Enable Printing Support
  printEnable = true;

  # Enable Thunar GUI File Manager
  # Dolphin is default File Manager
  thunarEnable = false;
}
