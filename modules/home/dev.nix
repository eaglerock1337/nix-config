{ config, pkgs, ... }:

let
  # Optional: Pin the Node version for consistency
  nodejs = pkgs.nodejs_20;
in {
  home.packages = with pkgs; [
    # --- Python ---
    python3
    python3Packages.virtualenv
    pipenv
    black
    mypy

    # --- Go ---
    go
    gopls # Language server
    golint
    delve # Debugger

    # --- Node.js / TypeScript ---
    nodejs
    nodePackages.npm
    nodePackages.typescript
    nodePackages.typescript-language-server
    nodePackages.eslint
    nodePackages.prettier

    # --- Ruby ---
    ruby
    rubyPackages_3_1.bundler
    rubyPackages_3_1.irb
    rubyPackages_3_1.solargraph  # Ruby LSP
    rubyPackages_3_1.rubocop

    # --- Misc Dev Tools ---
    direnv
    jq
    git
    gh  # GitHub CLI
  ];

  # Optional: configure environment variables
  home.sessionVariables = {
    GOPATH = "${config.home.homeDirectory}/go";
    PATH = "${config.home.homeDirectory}/go/bin:$PATH";
  };

  # Optional: direnv with nix support
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
