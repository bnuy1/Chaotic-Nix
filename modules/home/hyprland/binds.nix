{host, ...}: let
  vars = import ../../../hosts/${host}/variables.nix;
  inherit
    (vars)
    barChoice
    browser
    terminal
    ;
in {

  wayland.windowManager.hyprland.settings = {
    "$mainMod" = "SUPER";
	bind =
	[
	  "$mainMod, Q, exec, $terminal"
	  "$mainMod, W, exec, $browser"
	  "$mainMod, C, killactive,"
	  "$mainMod, M, exit,"
	  "$mainMod, E, exec, $fileManager"
	  "$mainMod, V, togglefloating,"
	  "$mainMod, R, exec, $menu"
	  "$mainMod, P, exec, hyprpicker"
	  "$mainMod, F, fullscreen,"

	  # Move focus with mainMod + arrow keys
	  "$mainMod, left, movefocus, l"
	  "$mainMod, right, movefocus, r"
	  "$mainMod, up, movefocus, u"
	  "$mainMod, down, movefocus, d"

	  # Switch workspaces
	  "$mainMod, 1, workspace, 1"
	  "$mainMod, 2, workspace, 2"
	  "$mainMod, 3, workspace, 3"
	  "$mainMod, 4, workspace, 4"
	  "$mainMod, 5, workspace, 5"
	  "$mainMod, 6, workspace, 6"
	  "$mainMod, 7, workspace, 7"
	  "$mainMod, 8, workspace, 8"
	  "$mainMod, 9, workspace, 9"
	  "$mainMod, 0, workspace, 10"

	  # Move window to workspace
	  "$mainMod SHIFT, 1, movetoworkspace, 1"
	  "$mainMod SHIFT, 2, movetoworkspace, 2"
	  "$mainMod SHIFT, 3, movetoworkspace, 3"
	  "$mainMod SHIFT, 4, movetoworkspace, 4"
	  "$mainMod SHIFT, 5, movetoworkspace, 5"
	  "$mainMod SHIFT, 6, movetoworkspace, 6"
	  "$mainMod SHIFT, 7, movetoworkspace, 7"
	  "$mainMod SHIFT, 8, movetoworkspace, 8"
	  "$mainMod SHIFT, 9, movetoworkspace, 9"
	  "$mainMod SHIFT, 0, movetoworkspace, 10"

	  # Special workspace
	  "$mainMod, S, togglespecialworkspace, magic"
	  "$mainMod SHIFT, S, movetoworkspace, special:magic"

	  # Scroll workspaces
	  "$mainMod, mouse_down, workspace, e+1"
	  "$mainMod, mouse_up, workspace, e-1"
	];

	bindm =
	[
	  "$mainMod, mouse:272, movewindow"
	  "$mainMod, mouse:273, resizewindow"
	];

	bindel =
	[
	  ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
	  ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
	  ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
	  ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
	  ",XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+"
	  ",XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-"
	];

	bindl =
	[
	  ", XF86AudioNext, exec, playerctl next"
	  #", XF86AudioPause, exec, playerctl play-pause"
	  #", XF86AudioPlay, exec, playerctl play-pause"
	  ", XF86AudioPrev, exec, playerctl previous"
	];

  };

}
