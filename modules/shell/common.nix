# Shared bash shell configuration for all managed systems.
# History settings and aliases go in interactiveShellInit (not shellInit) so
# they only apply to interactive sessions — scripts must not be affected.
{ ... }:

{
  programs.bash.enable = true;

  programs.bash.interactiveShellInit = ''
    # History: large buffer, no duplicates, no commands starting with space
    HISTSIZE=10000
    HISTFILESIZE=20000
    HISTCONTROL=ignoreboth
    shopt -s histappend

    # Common aliases
    alias ll='ls -lhF --color=auto'
    alias la='ls -lhAF --color=auto'
    alias grep='grep --color=auto'
    alias df='df -h'
    alias du='du -h'
  '';

  # Arrow-key history search — up/down through commands matching current prefix
  environment.etc."inputrc".text = ''
    "\e[A": history-search-backward
    "\e[B": history-search-forward
    set completion-ignore-case on
  '';
}
