# Simple shell for building qwen-code
{ pkgs ? import <nixpkgs> {} }:

let
  qwen-code = pkgs.callPackage ./default.nix {};
in
  qwen-code