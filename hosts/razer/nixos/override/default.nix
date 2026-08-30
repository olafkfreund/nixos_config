_: {
  # Razer-specific package overrides (this host only; p620/p510 stay stock).
  nixpkgs.overlays = [
    # --use-angle=gl: on Razer's Intel-iris + Mesa + Ozone/Wayland stack, ANGLE's
    # default backend can't import Wayland dmabufs as EGLImages (eglCreateImage
    # EGL_BAD_MATCH), looping the GPU process and glitching pages. Native GL uses
    # Mesa's EGL directly and fixes it. AMD (p620) doesn't hit this, so keep it here.
    (_: prev: {
      google-chrome = prev.google-chrome.override {
        commandLineArgs = "--use-angle=gl";
      };
    })
  ];
}
