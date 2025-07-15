{ config, pkgs, lib, ... }:

{
  programs.vscode = {
    enable = true;

    profiles.default = {
      extensions = (with pkgs.vscode-extensions; [
        bbenoist.nix
        vscode-icons-team.vscode-icons
        ms-python.python
        esbenp.prettier-vscode
        dbaeumer.vscode-eslint
      ]) ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
        {
          publisher = "tomphilbin";
          name = "gruvbox-themes";
          version = "1.0.0";
          sha256 = "sha256-DnwASBp1zvJluDc/yhSB87d0WM8PSbzqAvoICURw03c=";
        }
      ];
    
      userSettings = {
        editor = {
          tabSize = 2;
          formatOnSave = true;
          fontFamily = "FiraCode Nerd Font";
          fontSize = 14;
          fontLigatures = true;
          inlineSuggest.enabled = true;
          bracketPairColorization.enabled = true;
        };

        workbench = {
          colorTheme = "Gruvbox Dark (Soft)";
          iconTheme = "vscode-icons";
        };

        terminal.integrated.fontSize = 14;
      };
    };
  };
}
