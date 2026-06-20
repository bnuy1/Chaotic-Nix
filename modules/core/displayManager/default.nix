{ lib, config, vars, ... }:
let
  # parse "sddm-graphical" → { name = "sddm"; graphical = true; }
  raw = vars.displayManager;
  dmParsed = {
    sddm           = { name = "sddm"; graphical = true;  };
    sddm-graphical = { name = "sddm"; graphical = true;  };
    sddm-headless  = { name = "sddm"; graphical = false; };
    tui            = { name = "tui";   graphical = false; };
    tui-headless   = { name = "tui";   graphical = false; };
    tui-graphical  = { name = "tui";   graphical = true;  };
    ly             = { name = "ly";    graphical = false; };
    ly-headless    = { name = "ly";    graphical = false; };
    ly-graphical   = { name = "ly";    graphical = true;  };
  }.${raw} or (throw "invalid displayManager \"${raw}\"");
in {
  options.custom.displayManagerParsed = lib.mkOption {
    type = lib.types.attrs;
    internal = true;
    readOnly = true;
  };
  config.custom.displayManagerParsed = dmParsed;
  imports = [
    ./sddm.nix
    ./ly.nix
  ];
}
