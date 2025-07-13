{ config, pkgs, ... }:

let
  # Optional: Pin the Node version for consistency
  nodejs = pkgs.nodejs_20;
  myNodePackages = pkgs.nodePackages.override { inherit nodejs; };
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
    myNodePackages.npm
    myNodePackages.typescript
    myNodePackages.typescript-language-server
    myNodePackages.eslint
    myNodePackages.prettier

    # --- Ruby ---
    ruby_3_4
    bundler
    rubyPackages_3_4.irb
    rubyPackages_3_4.rake
    rubyPackages_3_4.solargraph  # Ruby LSP
    rubyPackages_3_4.rubocop

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
