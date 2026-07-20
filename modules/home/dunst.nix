{ lib, ... }:

{
  services.dunst = {
    enable = true;

    settings = {
      global = {
        monitor = 0;
        follow = "mouse";
        width = 300;
        height = 300;
        offset = "10x50";
        origin = "top-right";
        notification_limit = 20;
        progress_bar = true;
        indicate_hidden = "show";
        transparency = 5;
        frame_width = 1;
        separator_height = 0;
        padding = 10;
        horizontal_padding = 10;
        text_icon_padding = 10;
        separator_color = "frame";
        # frame_color handled by stylix
        startup_notification = false;
        corner_radius = 8;
        idle_threshold = 120;
        # font handled by stylix
        line_height = 2;
        markup = "full";
        format = "<b>%s</b>\\n%b";
        alignment = "left";
        vertical_alignment = "center";
        show_age_threshold = 60;
        ellipsize = "middle";
        ignore_newline = false;
        stack_duplicates = true;
        hide_duplicate_count = false;
        show_indicators = true;
      };

      urgency_low = {
        timeout = 5;
      };

      urgency_normal = {
        timeout = 8;
      };

      urgency_critical = {
        timeout = 0;
      };
    };
  };
}
