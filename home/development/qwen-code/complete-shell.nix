# Complete qwen-code package
{ pkgs ? import <nixpkgs> {} }:

let
  qwen-code = pkgs.callPackage ./complete.nix {};
in
  qwen-code