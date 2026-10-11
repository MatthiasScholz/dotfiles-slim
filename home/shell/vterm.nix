# Emacs vterm shell integration (`programs.zsh.initContent`).
{
  lib,
  ...
}:

{
  # TODO Move to emacs.nix
  # Emacs vterm helper
  # https://github.com/akermu/emacs-libvterm?tab=readme-ov-file#shell-side-configuration
  # TODO check if vterm configuration is still needed with enabling VteIntegration = true above
  programs.zsh.initContent = lib.mkMerge [
    (lib.mkOrder 500 ''
      # Emacs vterm shell integration
      if [[ "$INSIDE_EMACS" = 'vterm' ]] \
          && [[ -n ''${EMACS_VTERM_PATH} ]] \
          && [[ -f ''${EMACS_VTERM_PATH}/etc/emacs-vterm-zsh.sh ]]; then
          source "''${EMACS_VTERM_PATH}/etc/emacs-vterm-zsh.sh"

          # HACK: reload real add-zsh-hook after vterm clobbers it
          unfunction add-zsh-hook 2>/dev/null
          autoload -Uz add-zsh-hook

          vterm_set_directory() {
              vterm_cmd update-pwd "$(pwd)/"
          }
          precmd_functions+=( vterm_set_directory )
          vterm_set_directory
      fi
    '')

    ''
      vterm_printf() {
        if [ -n "$TMUX" ] && ([ "''${TERM%%-*}" = "tmux" ] || [ "''${TERM%%-*}" = "screen" ]); then
           # Tell tmux to pass the escape sequences through
           printf "\ePtmux;\e\e]%s\007\e\\" "$1"
        elif [ "''${TERM%%-*}" = "screen" ]; then
           # GNU screen (screen, screen-256color, screen-256color-bce)
           printf "\eP\e]%s\007\e\\" "$1"
        else
          printf "\e]%s\e\\" "$1"
        fi
      }

      vterm_prompt_end() {
        vterm_printf "51;A$(whoami)@$(hostname):$(pwd)"
      }
      setopt PROMPT_SUBST
      PROMPT=$PROMPT'%{$(vterm_prompt_end)%}'

      vterm_cmd() {
        local vterm_elisp
        vterm_elisp=""
        while [ $# -gt 0 ]; do
           vterm_elisp="$vterm_elisp""$(printf '"%s" ' "$(printf "%s" "$1" | sed -e 's|\\|\\\\|g' -e 's|"|\\"|g')")"
           shift
        done
        vterm_printf "51;E$vterm_elisp"
      }

      find_file() {
         vterm_cmd find-file "$(realpath "''${@:-.}")"
      }

      say() {
         vterm_cmd message "%s" "$*"
      }
    ''
  ];
}
