# Simple shell for building qwen-code with stdenv
{ pkgs ? import <nixpkgs> {} }:

let
  qwen-code = pkgs.callPackage ./simple.nix {};
in
  qwen-code