{ lib
, python3
, fetchFromGitHub
, meson
, ninja
, pkg-config
, wrapGAppsHook4
, desktop-file-utils
, gobject-introspection
, libadwaita
, gtk4
, glib
, glib-networking
, gtksourceview5
, vte-gtk4
, webkitgtk_6_0
, dconf
, gsettings-desktop-schemas
, adwaita-icon-theme
, docutils
, # Audio dependencies
  portaudio
, gst_all_1
,
}:

python3.pkgs.buildPythonApplication rec {
  pname = "newelle";
  version = "1.2.5";
  format = "other"; # Uses Meson, not setuptools

  src = fetchFromGitHub {
    owner = "qwersyk";
    repo = "Newelle";
    rev = version;
    hash = "sha256-XqKT3D4DfYPcYThPrlWJjes12O3dRvejCV8zQ6WYb0w=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    wrapGAppsHook4
    gobject-introspection
    desktop-file-utils
    docutils
  ];

  buildInputs =
    [
      libadwaita
      gtk4
      glib
      glib-networking
      gtksourceview5
      vte-gtk4
      webkitgtk_6_0
      dconf
      gsettings-desktop-schemas
      adwaita-icon-theme
      portaudio
    ]
    ++ (with gst_all_1; [
      gstreamer
      gst-plugins-base
      gst-plugins-good
      gst-plugins-bad
    ]);

  propagatedBuildInputs = with python3.pkgs; [
    # Core
    pygobject3
    requests
    numpy

    # AI Providers
    openai
    ollama

    # Text processing
    lxml
    lxml-html-clean
    pylatexenc
    tiktoken
    markdownify
    cssselect

    # Audio
    pyaudio
    pydub
    gtts
    speechrecognition

    # Media/Graphics
    pillow
    matplotlib

    # Web/Content
    newspaper3k

    # llama-index components (for RAG)
    llama-index-core
    llama-index-embeddings-huggingface
  ];

  strictDeps = true;

  # Don't wrap twice
  dontWrapGApps = true;

  preFixup = ''
    # Combine wrapper args (schemas already compiled by Meson install)
    makeWrapperArgs+=(
      "''${gappsWrapperArgs[@]}"
      "--prefix" "PYTHONPATH" ":" "$out/share/newelle"
    )
  '';

  postInstall = ''
    # Ensure the binary has correct shebang
    patchShebangs $out/bin/newelle
  '';

  meta = with lib; {
    description = "Your Ultimate Virtual Assistant - AI chat interface for Linux";
    longDescription = ''
      Newelle is a GTK4/Libadwaita-based AI virtual assistant for Linux that
      supports multiple AI providers including OpenAI, Anthropic, Google Gemini,
      Ollama, and more. Features include voice input/output, chat branching,
      MCP server support, and integrated mini-apps (browser, terminal, file manager).
    '';
    homepage = "https://github.com/qwersyk/Newelle";
    changelog = "https://github.com/qwersyk/Newelle/releases/tag/${version}";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
    mainProgram = "newelle";
  };
}
