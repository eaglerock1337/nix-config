{ config, pkgs, lib, ... }:

let
  vscodePackage = pkgs.vscode;  # You can use pkgs.vscodium instead
in {
  home.packages = [ vscodePackage ];

  # Optional: Install extensions declaratively
  programs.vscode = {
    enable = true;
    package = vscodePackage;

    extensions = with pkgs.vscode-extensions; [
      ms-python.python
      esbenp.prettier-vscode
      dbaeumer.vscode-eslint
      # Add more as needed
    ];

    userSettings = {
      "editor.tabSize" = 2;
      "editor.formatOnSave" = true;
      "files.autoSave" = "onFocusChange";
      "workbench.colorTheme" = "Default Dark+";
      "terminal.integrated.fontSize" = 14;
    };
  };
}
