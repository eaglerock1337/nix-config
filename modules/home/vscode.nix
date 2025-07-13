{ config, pkgs, lib, ... }:

let
  extensions = (with pkgs.vscode-extensions; [
    tomphilbin.gruvbox-themes
    bbenoist.nix
    vscode-icons-team.vscode-icons
    ms-python.python
    esbenp.prettier-vscode
    dbaeumer.vscode-eslint
  ]);
in {
  home.packages = with pkgs; [
    vscode-with-extensions
  ];

  programs.vscode = {
    enable = true;
    packages = pkgs.vscode;

    userSettings = {
      editor = {
        tabSize = 2;
        formatOnSave = true;
        fontFamily = "FiraCode Nerd Font";
        fontSize = 18;
        fontLigatures = true;
        inlineSuggest.enabled = true;
        bracketPairColorization.enabled = true;
      };

      workbench = {
        colorTheme = "Gruvbox Dark (Soft)";
        iconTheme = "vscode-icons";
      };

      terminal.integrated.fontSize = 18;
    };
  };
}
