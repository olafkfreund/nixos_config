{ pkgs, config, lib, inputs, ... }:
{
  programs.alacritty = {
    enable = true;
    settings = {
      keyboard.bindings = [
        { key = "V";  mods = "Control"; action = "Paste"; }
        { key = "C";  mods = "Control"; action = "Copy"; }
        { key = "N";  mods = "Control|Shift"; action = "CreateNewWindow"; }
      ];

      window.startup_mode = "Windowed";
      window.decorations = "none";
      window.blur = true;
      scrolling.history = 10000;
      selection.save_to_clipboard = true;
      terminal.osc52 = "CopyPaste";
      mouse_bindings = [
          {
            mouse = "Right";
            action = "Paste";
          }
      ];
    };
  };
}
