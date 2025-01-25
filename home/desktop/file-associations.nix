let
  google-chrome.desktop = ["google-chrome-stable"];
  archiveManager = ["archive"];
  feh.desktop = ["feh"];
in {
  # XDG MIME types
  associations = {
    "application/x-extension-htm" = google-chrome.desktop;
    "application/x-extension-html" = google-chrome.desktop;
    "application/x-extension-shtml" = google-chrome.desktop;
    "application/x-extension-xht" = google-chrome.desktop;
    "application/x-extension-xhtml" = google-chrome.desktop;
    "application/xhtml+xml" = google-chrome.desktop;
    "text/html" = google-chrome.desktop;
    "x-scheme-handler/about" = google-chrome.desktop;
    "x-scheme-handler/chrome" = google-chrome.desktop;
    "x-scheme-handler/ftp" = google-chrome.desktop;
    "x-scheme-handler/http" = google-chrome.desktop;
    "x-scheme-handler/https" = google-chrome.desktop;
    "x-scheme-handler/unknown" = google-chrome.desktop;
    "x-scheme-handler/mailto" = thunderbird.desktop;

    "audio/*" = ["mpv"];
    "video/*" = ["mpv"];
    "image/*" = ["feh"];

    "application/json" = google-chrome.desktop;

    "application/pdf" = ["zathura"];

    # Archives / compressed files
    "application/x-7z-compressed" = archiveManager;
    "application/x-7z-compressed-tar" = archiveManager;
    "application/x-bzip" = archiveManager;
    "application/x-bzip-compressed-tar" = archiveManager;
    "application/x-compress" = archiveManager;
    "application/x-compressed-tar" = archiveManager;
    "application/x-cpio" = archiveManager;
    "application/x-gzip" = archiveManager;
    "application/x-lha" = archiveManager;
    "application/x-lzip" = archiveManager;
    "application/x-lzip-compressed-tar" = archiveManager;
    "application/x-lzma" = archiveManager;
    "application/x-lzma-compressed-tar" = archiveManager;
    "application/x-tar" = archiveManager;
    "application/x-tarz" = archiveManager;
    "application/x-xar" = archiveManager;
    "application/x-xz" = archiveManager;
    "application/x-xz-compressed-tar" = archiveManager;
    "application/zip" = archiveManager;
    "application/gzip" = archiveManager;
    "application/bzip2" = archiveManager;
    "application/vnd.rar" = archiveManager;

    # Images
    "image/jpeg" = feh.desktop;
    "image/png" = feh.desktop;
    "image/gif" = feh.desktop;
    "image/webp" = feh.desktop;
    "image/tiff" = feh.desktop;
    "image/x-tga" = feh.desktop;
    "image/vnd-ms.dds" = feh.desktop;
    "image/x-dds" = feh.desktop;
    "image/bmp" = feh.desktop;
    "image/vnd.microsoft.icon" = feh.desktop;
    "image/vnd.radiance" = feh.desktop;
    "image/x-exr" = feh.desktop;
    "image/x-portable-bitmap" = feh.desktop;
    "image/x-portable-graymap" = feh.desktop;
    "image/x-portable-pixmap" = feh.desktop;
    "image/x-portable-anymap" = feh.desktop;
    "image/x-qoi" = feh.desktop;
    "image/svg+xml" = feh.desktop;
    "image/svg+xml-compressed" = feh.desktop;
    "image/avif" = feh.desktop;
    "image/heic" = feh.desktop;
    "image/jxl" = feh.desktop;
  };
}
