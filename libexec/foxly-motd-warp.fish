# Sourced by /etc/fish/config.fish; keep normal SSH and noninteractive jobs quiet.
if status is-interactive
    and isatty stdout
    and test "$TERM_PROGRAM" = WarpTerminal
    and test -n "$SSH_CONNECTION"
    and test -n "$SSH_TTY"
    and test "$FOXLY_MOTD_WARP_TTY" != "$SSH_TTY"
    and not test -e "$HOME/.hushlogin"
    and test -x "$FOXLY_MOTD_ROOT/usr/local/sbin/foxly-motd"
    set -gx FOXLY_MOTD_WARP_TTY "$SSH_TTY"
    "$FOXLY_MOTD_ROOT/usr/local/sbin/foxly-motd" preview
end
