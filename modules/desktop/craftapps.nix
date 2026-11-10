{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.features.craftapps;
  appsJson = lib.importJSON "${inputs.nix-craftapps}/apps.json";
  names = builtins.attrNames appsJson;
  desktopId = app: "${appsJson.${app}.desktopId}.desktop";

  # Exact MIME strings from each app's desktop file. Apps absent here (effectcraft, craft-anything) claim nothing.
  defaults = {
    wordcraft = [
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      "application/vnd.ms-word.document.macroEnabled.12"
      "application/vnd.openxmlformats-officedocument.wordprocessingml.template"
      "application/vnd.ms-word.template.macroEnabled.12"
      "application/msword"
      "application/msword-template"
      "application/vnd.oasis.opendocument.text"
      "application/rtf"
      "text/rtf"
    ];
    gridcraft = [
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      "application/vnd.ms-excel.sheet.macroEnabled.12"
      "application/vnd.ms-excel.sheet.binary.macroEnabled.12"
      "application/vnd.oasis.opendocument.spreadsheet"
      "text/csv"
      "text/tab-separated-values"
    ];
    deckcraft = [
      "application/x-deckcraft"
      "application/vnd.openxmlformats-officedocument.presentationml.presentation"
      "application/vnd.openxmlformats-officedocument.presentationml.template"
      "application/vnd.openxmlformats-officedocument.presentationml.slideshow"
    ];
    pdfcraft = [ "application/pdf" ];
    photocraft = [
      "application/x-photocraft"
      "image/x-paintnet"
      "image/openraster"
      "application/x-krita"
      "image/vnd.adobe.photoshop"
      "image/x-psd"
      "image/x-psb"
      "image/png"
      "image/jpeg"
      "image/tiff"
      "image/webp"
      "image/gif"
      "image/bmp"
      "image/x-tga"
      "image/x-icon"
      "image/vnd.microsoft.icon"
      "image/x-portable-anymap"
      "image/x-portable-bitmap"
      "image/x-portable-graymap"
      "image/x-portable-pixmap"
      "image/x-exr"
      "image/vnd.radiance"
      "image/avif"
      "image/qoi"
    ];
    lightcraft = [
      "image/heic"
      "image/heif"
      "image/x-adobe-dng"
      "image/x-sony-arw"
      "image/x-canon-cr2"
      "image/x-canon-cr3"
      "image/x-nikon-nef"
      "image/x-fuji-raf"
      "image/x-olympus-orf"
      "image/x-panasonic-rw2"
      "image/x-panasonic-rw"
      "image/x-pentax-pef"
    ];
    vectorcraft = [
      "image/svg+xml"
      "application/x-vectorcraft"
      "image/svg+xml-compressed"
      "application/illustrator"
      "application/x-ai-template"
      "application/x-vectorcraft-template"
      "image/emf"
      "image/wmf"
      "image/x-eps"
      "application/x-affinity"
    ];
    figcraft = [
      "application/x-figcraft"
      "application/x-sketch"
      "x-scheme-handler/figcraft"
    ];
    designcraft = [
      "application/x-designcraft"
      "application/vnd.adobe.indesign-idml-package"
    ];
    cadcraft = [
      "image/vnd.dxf"
      "image/vnd.dwg"
      "application/x-dxf"
      "application/acad"
    ];
    filmcraft = [ "application/x-filmcraft" ];
    soundcraft = [ "application/x-soundcraft-session" ];
  };

  # Shared types: the other Craft apps that also declare them.
  alsoClaimed = {
    "image/png" = [ "lightcraft" "figcraft" "vectorcraft" ];
    "image/jpeg" = [ "lightcraft" "figcraft" "vectorcraft" ];
    "image/tiff" = [ "lightcraft" "vectorcraft" ];
    "image/webp" = [ "lightcraft" "vectorcraft" ];
    "image/gif" = [ "vectorcraft" ];
    "image/bmp" = [ "vectorcraft" ];
    "image/svg+xml" = [ "figcraft" ];
    "application/pdf" = [ "vectorcraft" ];
    "image/vnd.dxf" = [ "vectorcraft" ];
  };

  enabled = lib.filterAttrs (app: _: cfg.apps.${app}) defaults;
  disabled = lib.filterAttrs (app: _: !cfg.apps.${app}) defaults;

  owners = lib.foldl' (acc: app: lib.foldl' (a: t: a // { ${t} = (a.${t} or [ ]) ++ [ app ]; }) acc defaults.${app })
    { }
    (builtins.attrNames defaults);
  duplicates = lib.filterAttrs (_: apps: builtins.length apps > 1) owners;

  # Types of disabled owners that other, enabled Craft apps would otherwise claim.
  removed = lib.filterAttrs (_: ids: ids != [ ]) (lib.listToAttrs (lib.concatMap
    (app: map
      (t: lib.nameValuePair t (map desktopId (builtins.filter (o: cfg.apps.${o} or false) (alsoClaimed.${t} or [ ]))))
      defaults.${app})
    (builtins.attrNames disabled)));

  checkFor = app:
    let
      file = "${config.programs.craftapps.apps.${app}.package}/share/applications/${appsJson.${app}.desktopId}.desktop";
      types = defaults.${app} ++ builtins.attrNames (lib.filterAttrs (_: apps: builtins.elem app apps) alsoClaimed);
    in
    ''
      m=";$(sed -n 's/^MimeType=//p' ${file});"
      ${lib.concatMapStrings (t: ''
        case "$m" in *";${t};"*) ;; *) echo "craftapps: ${app} does not declare ${t}" >&2; fail=1 ;; esac
      '') types}
    '';
in
{
  imports = [ inputs.nix-craftapps.nixosModules.default ];

  options.features.craftapps = {
    enable = lib.mkEnableOption "the ArtCraft Crafting Apps";
    apps = lib.genAttrs names (name: lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include ${name} (false excludes it).";
    });
    mcp = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Register an MCP server for every enabled app (`<app>-cli mcp`).";
    };
    skill = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the craftapps agent skill for every Home Manager agent with a skills option.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      programs.craftapps = {
        enable = true;
        mcp.enable = cfg.mcp;
        skill.enable = cfg.skill;
        apps = lib.mapAttrs (_: enable: { inherit enable; }) cfg.apps;
      };
    }
    {
      assertions = [{
        assertion = duplicates == { };
        message = "features.craftapps: MIME type claimed by two apps in defaults: ${lib.concatStringsSep ", " (builtins.attrNames duplicates)}";
      }];

      # mkForce: home/desktop/{evince,gnome} set their own defaults, and defaultApplications lists merge.
      home-manager.sharedModules = [{
        xdg.mimeApps = {
          enable = true;
          defaultApplications = lib.foldl' (acc: app: acc // lib.genAttrs defaults.${app} (_: lib.mkForce [ (desktopId app) ])) { }
            (builtins.attrNames enabled);
          associations.removed = removed;
        };
      }];

      system.checks = [
        (pkgs.runCommandLocal "craftapps-mime-check" { } ''
          fail=0
          ${lib.concatMapStrings checkFor (builtins.attrNames enabled)}
          [ "$fail" = 0 ] || exit 1
          touch $out
        '')
      ];
    }
  ]);
}
