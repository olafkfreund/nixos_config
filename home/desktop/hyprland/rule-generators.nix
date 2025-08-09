# Simplified Rule Generators
{ ... }: {
  hyprland.ruleGenerators = {
    floatingWindow =
      { class
      , size ? "1000 1000"
      ,
      }: [
        "float, class:(${class})"
        "size ${size}, class:(${class})"
      ];
  };
}
