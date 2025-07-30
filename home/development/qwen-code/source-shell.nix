# Shell for building qwen-code from source
{ pkgs ? import <nixpkgs> {} }:

let
  qwen-code = pkgs.callPackage ./source-build.nix {};
in
  qwen-code