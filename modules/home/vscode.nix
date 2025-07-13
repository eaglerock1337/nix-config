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
      tomphilbin.gruvbox-themes
      bbenoist.nix
      vscode-icons-team.vscode-icons
      ms-python.python
      esbenp.prettier-vscode
      dbaeumer.vscode-eslint
    ];

    userSettings = {
      "editor.tabSize" = 2;
      "editor.formatOnSave" = true;
      "files.autoSave" = "onFocusChange";
      "workbench.colorTheme" = "Gruvbox Dark (Soft)";
      "workbench.iconTheme" = "vscode-icons";
      "editor.fontFamily" = "FiraCode Nerd Font";
      "editor.fontLigatures" = true;
      "editor.fontSize" = 18;
      "terminal.integrated.fontSize" = 18;
    };
  };
}
