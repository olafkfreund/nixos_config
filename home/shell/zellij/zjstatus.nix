{ inputs, nixpkgs, ...}:
{
  nixpkgs.overlays = with inputs; [
    (final: prev: {
      zjstatus = zjstatus.packages.${prev.system}.default;
    })
  ];
}
