{
  config,
  ...
}: {
  xdg.configFile."hypr/hyprlock.conf".text = ''

    background {
        monitor =
        path = /home/${config.home.username}/Pictures/wallpapers/gruvbox/hypr/fly_agaric_mushroom_fall_foliage_117318_1920x1080.jpg
        blur_size = 7
        blur_passes = 3 # 0 disables blurring
        noise = 0.0117
        contrast = 0.8000
        brightness = 0.8000
        vibrancy = 0.1600
        vibrancy_darkness = 0.0
    }

    image {
        path = /home/${config.home.username}/Pictures/PXL_20221014_102401611.PORTRAIT~3.jpg
        size = 350
        border_size = 4
        border_color = rgb(40, 40, 40)
        rounding = -1
        position = 0, 200
        halign = center
        valign = center
    }

    input-field {
        monitor =
        size = 250, 50
        outline_thickness = 3
        dots_size = 0.2 # Scale of input-field height, 0.2 - 0.8
        dots_spacing = 0.64 # Scale of dots' absolute size, 0.0 - 1.0
        dots_center = true
        outer_color = rgb(40, 40, 40)
        inner_color = rgb(40, 40, 40)
        font_color = rgb(235, 219, 178)
        fade_on_empty = false
        placeholder_text = "Password..."
        hide_input = false
        position = 0, 50
        check_color = rgb(235, 219, 178)
        fail_color = rgb(254, 128, 25)
        halign = center
        valign = bottom
    }

    # Current time
    label {
        monitor =
        text = cmd[update:1000] echo "<b><big> $(date +"%H:%M:%S") </big></b>"
        color = rgb(235, 219, 178)
        font_size = 64
        font_family = JetBrains Mono Nerd Font 10
        position = 0, 16
        halign = center
        valign = center
    }

  '';
}
