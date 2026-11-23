# Phone calls on the host through Nixi's handset (nixoarchy-snowflake#115).
# The phone pairs with this host as a Bluetooth hands-free unit: PipeWire's
# telephony service carries the call, and WirePlumber links its audio.
# This adds only:
# - an echo-cancelled mic for the call's uplink, its own and not meetingai's
#   (that one is on p620 only and belongs to another app);
# - two WirePlumber rules: a phone card auto-connects hands-free only, so its
#   music stays on the phone, and the call's uplink takes the echo-cancelled mic.
# Pairing stays a one-time owner step (docs/GUIDE.md "Take calls on Nixi" in the
# snowflake repo): pair, trust, connect, then "Media audio" off on the phone.
{ config, lib, ... }:
let
  cfg = config.features.nixiCalls;
in
{
  options.features.nixiCalls.enable = lib.mkEnableOption "phone calls on this host through Nixi's handset (Bluetooth hands-free)";

  config = lib.mkIf cfg.enable {
    home-manager.users.olafkfreund.xdg.configFile = {
      # Monitor mode: the reference is the default sink's monitor, where the
      # caller's voice plays, so the source is the mic without the caller.
      "pipewire/pipewire.conf.d/61-nixi-call-echo-cancel.conf".text = ''
        context.modules = [
          {
            name = libpipewire-module-echo-cancel
            # A missing or failing module must never stop PipeWire at login.
            flags = [ ifexists nofail ]
            args = {
              library.name = aec/libspa-aec-webrtc
              monitor.mode = true
              capture.props = {
                node.name = "nixi-call-echo-cancel-capture"
              }
              source.props = {
                node.name = "nixi-call-echo-cancel-source"
                node.description = "Nixi call mic (echo-cancelled)"
              }
              sink.props = {
                node.name = "nixi-call-echo-cancel-sink"
                node.description = "Nixi call echo canceller (not an output)"
              }
            }
          }
        ]
      '';
      # "z-" so it loads after the hand-made bluetooth-a2dp-autoconnect.conf:
      # rules load in file-name order and the later match wins.
      "wireplumber/wireplumber.conf.d/z-nixi-phone.conf".text = ''
        monitor.bluez.rules = [
          {
            matches = [ { device.form-factor = "phone" } ]
            actions = { update-props = { bluez5.auto-connect = [ hfp_ag ] } }
          }
          {
            matches = [
              {
                api.bluez5.profile = "headset-audio-gateway"
                media.class = "Stream/Input/Audio"
              }
            ]
            actions = { update-props = { target.object = "nixi-call-echo-cancel-source" } }
          }
        ]
      '';
    };
  };
}
