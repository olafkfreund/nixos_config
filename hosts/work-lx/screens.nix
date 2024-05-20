{ config, vars, ... }: {

home-manager.extraSpecialArgs = { 
    vars = { 
        hostName = "work-lx"; 
        class = "laptop"; 
        screen = { 
            name = "eDP-1"; 
            ultrawide = false; 
            hidpi = false; 
            width = 1920; 
            height = 1200; 
            refresh = 60; 
            }; 
        }; 
    };
}
