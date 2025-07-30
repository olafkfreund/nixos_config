# Shell for building qwen-code with global npm install approach
{ pkgs ? import <nixpkgs> {} }:

let
  qwen-code = pkgs.callPackage ./final.nix {};
in
  qwen-code