{
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
     terraform
     terraformer 
     terraform-docs
  ];
}
