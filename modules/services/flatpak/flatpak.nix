{pkgs, ...}: {
  services.flatpak = {
    enable = true;
  };
  systemd.services.flatpak-repo = {
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];
    path = [pkgs.flatpak];
    serviceConfig = {
      Type = "oneshot";
      Restart = "on-failure";
      RestartSec = "5s";
    };
    script = ''
      # Try up to 3 times with increasing delays
      max_attempts=3
      attempt=1

      while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt to add flathub repository..."
        if flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo; then
          echo "Successfully added flathub repository."
          exit 0
        fi

        # If this isn't the last attempt, wait before retrying
        if [ $attempt -lt $max_attempts ]; then
          sleep_time=$((attempt * 5))
          echo "Failed to add flathub repository. Retrying in $sleep_time seconds..."
          sleep $sleep_time
        fi

        attempt=$((attempt + 1))
      done

      echo "Failed to add flathub repository after $max_attempts attempts."
      exit 1
    '';
  };
}
