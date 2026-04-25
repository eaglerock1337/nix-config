# PS1 prompt module with hostname color, git branch, and exit-code indicator.
# Uses a single PROMPT_COMMAND function to avoid conflict between git branch
# display and the exit-code color — two separate PROMPT_COMMAND assignments
# would silently drop whichever was set first.
{ config, lib, pkgs, ... }:

let
  cfg = config.shell.prompt;
  reset  = ''"\[\033[0m\]"'';
  red    = ''"\[\033[31m\]"'';
  bold   = ''"\[\033[1m\]"'';
in {
  options.shell.prompt = {
    hostColor = lib.mkOption {
      type = lib.types.str;
      default = ''"\[\033[32m\]"'';  # green — suits server/control-plane nodes
      description = "ANSI escape code for hostname color in the PS1 prompt.";
    };
  };

  config = {
    # git provides __git_ps1 via /etc/profile.d/git-sh-prompt.sh on NixOS
    environment.systemPackages = [ pkgs.git ];

    programs.bash.promptInit = ''
      # Load __git_ps1 if available
      if [ -f /run/current-system/sw/share/git/contrib/completion/git-prompt.sh ]; then
        source /run/current-system/sw/share/git/contrib/completion/git-prompt.sh
      fi
      GIT_PS1_SHOWDIRTYSTATE=1
      GIT_PS1_SHOWUNTRACKEDFILES=1

      # Single PROMPT_COMMAND captures exit code first, then builds PS1.
      # Two separate PROMPT_COMMAND assignments would silently overwrite each other.
      __set_ps1() {
        local exit_code=$?
        local git_branch
        git_branch=$(command -v __git_ps1 &>/dev/null && __git_ps1 " (%s)" || true)

        local host_color=${cfg.hostColor}
        local prompt_color
        if [ $exit_code -ne 0 ]; then
          prompt_color=${red}
        else
          prompt_color=${reset}
        fi

        local suffix='$'
        [ "$EUID" -eq 0 ] && suffix='#'

        PS1="${bold}[${reset}\u@''${host_color}\h${reset}:${bold}\w${reset}''${git_branch}${bold}]${reset}''${prompt_color}''${suffix}${reset} "
      }
      PROMPT_COMMAND=__set_ps1
    '';
  };
}
