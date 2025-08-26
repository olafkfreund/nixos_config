_: {
  services.logind.settings = {
    Login = {
      HandleLidSwitch = "ignore";
      HandleLidSwitchDocked = "ignore";
    };
  };
}
