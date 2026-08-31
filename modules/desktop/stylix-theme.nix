{ pkgs
, lib
, config
, inputs
, ...
}:
let
  vars = import ../../hosts/common/shared-variables.nix;

  # The Omarchy theme is the source of truth for the palette.
  #
  # `omarchy theme set X` retints the 24 files Omarchy owns immediately and its
  # hook rewrites nixarchy-theme.nix at the flake root; this reads that name,
  # loads the theme's colors.toml out of the nixarchy package and hands Stylix
  # the same colours. So the next rebuild carries the Omarchy theme into
  # everything Omarchy cannot reach at runtime: Plymouth, GRUB, the console,
  # GTK, Qt, fonts, and the home-manager targets.
  #
  # The flake-root file exists because a flake cannot read outside its own
  # tree -- the same reason nixarchy-apply copies apps.nix in as
  # nixarchy-apps.nix.
  # Reached through `inputs`, NOT through config.programs.nixarchy.package:
  # nixarchy consumes stylix, so reading its config from the module that
  # defines stylix.base16Scheme closes the module fixpoint and evaluation dies
  # with "infinite recursion". The flake input has no such loop.
  omarchyThemeName = import ../../nixarchy-theme.nix;
  omarchyPkg = inputs.nixarchy.packages.${pkgs.stdenv.hostPlatform.system}.omarchy or null;
  omarchyThemeDir = "${omarchyPkg}/share/omarchy/themes/${omarchyThemeName}";
  omarchyColorsPath = "${omarchyThemeDir}/colors.toml";

  # Omarchy's colors.toml is a named-role palette, not base16, but its roles
  # cover all sixteen slots one-for-one. Three stock themes (last-horizon,
  # solitude, white) ship no `orange` or `brown`, hence the two fallbacks:
  # base09 and base0F are the "constants" and "deprecated" slots, so folding
  # them onto yellow and muted keeps those themes readable rather than failing
  # evaluation.
  omarchyToBase16 = c: {
    base00 = c.background; # default background
    base01 = c.lighter_background; # lighter background, status bars
    base02 = c.selection; # selection background
    base03 = c.muted; # comments, invisibles
    base04 = c.dark_foreground; # dark foreground, status bars
    base05 = c.foreground; # default foreground
    base06 = c.light_foreground; # light foreground
    base07 = c.bright_foreground; # light background
    base08 = c.red; # variables, diff deleted
    base09 = c.orange or c.yellow; # integers, constants
    base0A = c.yellow; # classes, search background
    base0B = c.green; # strings, diff inserted
    base0C = c.cyan; # support, escape chars
    base0D = c.blue; # functions, headings
    base0E = c.magenta; # keywords, diff changed
    base0F = c.brown or c.muted; # deprecated, closing tags
  };

  # Stylix wants "rrggbb" with no leading '#'; Omarchy writes "#rrggbb".
  stripHash = v: lib.removePrefix "#" v;

  # p510 has no nixarchy at all and imports this same module, and a theme name
  # that is not in the package (a user theme under ~/.config/omarchy/themes,
  # which the flake cannot see) would be a dead path. Both fall back to the
  # checked-in yaml rather than failing the build.
  useOmarchyTheme = omarchyPkg != null && builtins.pathExists omarchyColorsPath;

  omarchyScheme =
    lib.mapAttrs (_: stripHash)
      (omarchyToBase16 (builtins.fromTOML (builtins.readFile omarchyColorsPath)));
in
{
  config = {
    stylix = {
      enable = true;
      enableReleaseChecks = false;
      polarity = "dark";
      autoEnable = true;
      base16Scheme = if useOmarchyTheme then omarchyScheme else vars.baseTheme.schemeFile;
      image = vars.baseTheme.wallpaper;

      fonts = {
        monospace = {
          # adwaita-fonts ships AdwaitaMono-{Regular,Bold,Italic,BoldItalic}.ttf.
          # gnome-themes-extra (used previously) ships zero font files — that
          # was a silent misconfiguration.
          package = pkgs.adwaita-fonts;
          name = vars.baseTheme.font.mono;
        };
        sansSerif = {
          package = pkgs.noto-fonts;
          name = vars.baseTheme.font.sans;
        };
        serif = {
          package = pkgs.noto-fonts;
          name = vars.baseTheme.font.serif;
        };
        sizes = vars.baseTheme.font.sizes;
      };

      opacity = vars.baseTheme.opacity;

      cursor = {
        name = vars.baseTheme.cursor.name;
        package = pkgs.bibata-cursors;
        size = vars.baseTheme.cursor.size;
      };

      # Icons are artwork, not base16 colours, so no icon set tracks the
      # scheme automatically. Papirus is the closest fit available: it is
      # colour-neutral apart from its folders, and nixpkgs exposes a `color`
      # argument that runs papirus-folders over the build — "green" is the
      # stop nearest the HUD's phosphor accent (base0B). It replaces
      # the previous icon set, whose warm orange folders were the last
      # obviously off-palette surface left on the desktop.
      #
      # Driving the icon theme THROUGH Stylix (rather than fighting it) is what
      # stops Stylix clobbering the icon choice on every rebuild. Note the
      # modern `stylix.icons` namespace; the old `stylix.iconTheme` is
      # deprecated and emits a warning.
      #
      # Stylix installs this package itself — do NOT also add
      # pkgs.papirus-icon-theme to home.packages, or the plain and
      # green-foldered builds collide on the same share/icons/Papirus* paths.
      icons = {
        enable = true;
        package = pkgs.papirus-icon-theme.override { color = "green"; };
        dark = "Papirus-Dark";
        light = "Papirus-Light";
      };

      targets = {
        chromium.enable = false;

        # kmscon: stylix's kmscon target still sets the removed-in-nixpkgs-50
        # `services.kmscon.fonts` option, which now fails the build. We don't
        # theme the Linux text console anyway (Wayland sessions are what
        # matters here), so disable the target until upstream stylix updates.
        kmscon.enable = false;

        # regreet: stylix's regreet target still writes `programs.regreet.*`,
        # renamed in nixpkgs to `services.displayManager.regreet`, so every
        # eval prints 8 rename warnings (one per option it sets). The target
        # auto-enables on all Linux hosts, but this fleet greets with SDDM /
        # cosmic-greeter and never uses regreet. Disable until upstream
        # stylix migrates to the new option path.
        regreet.enable = false;

        # COSMIC's GTK theme sync is disabled on this fleet, so cosmic-comp
        # does NOT clobber ~/.config/gtk-{3,4}.0/gtk.css at runtime. Stylix
        # can own that file safely and theme GTK3 / non-libadwaita GTK4 apps
        # everywhere. libadwaita apps still ignore third-party themes by
        # upstream policy regardless of gtk.css contents.
        gtk.enable = true;

        # GNOME target writes org.gnome.desktop.interface/* via gsettings and
        # ships a generated GTK theme package. COSMIC stores its own theme in
        # ~/.config/cosmic/com.system76.CosmicTheme.* and ignores these
        # gsettings keys, so the two desktops stay isolated.
        gnome.enable = config.host.class != "headless-rdp";

        qt = {
          enable = true;
          platform = lib.mkForce "qtct";
        };

        # Off because it costs a cache miss for no visible gain. The target's
        # only effect is a postFixup that copies one base16 .xml into
        # $out/share/gtksourceview-4/styles/stylix.xml -- which changes
        # gtksourceview4's derivation hash, so it can no longer substitute from
        # cache.nixos.org and every host compiles it locally. That build then
        # fails: its test-buffer test aborts with SIGABRT under the sandbox
        # (22 of 23 pass), taking virt-manager and system-path down with it.
        #
        # What is given up is base16 syntax-highlighting colours inside the few
        # GtkSourceView apps here (virt-manager's XML editor, gedit). The app
        # chrome around them is still themed through the gtk target above.
        gtksourceview.enable = false;
      };
    };
  };
}
