#!/bin/sh
# Restore only preferences owned by this session after unexpected app termination.
owner_pid="$1"
backup="$2"
shift 2
while kill -0 "$owner_pid" 2>/dev/null; do sleep 2; done
[ -f "$backup" ] || exit 0
restore() {
    key="$1"; value="$2"; type="$3"
    if [ "$value" = '__absent__' ]; then
        /usr/bin/defaults delete com.apple.dock "$key" 2>/dev/null || {
            if /usr/bin/defaults read com.apple.dock "$key" >/dev/null 2>&1; then exit 1; fi
        }
    else
        if [ "$key" = autohide ]; then
            case "$value" in
                1|true|TRUE|yes|YES) value=true ;;
                0|false|FALSE|no|NO) value=false ;;
                *) exit 1 ;;
            esac
        fi
        /usr/bin/defaults write com.apple.dock "$key" "$type" "$value" || exit 1
    fi
}
restore autohide "$1" -bool
restore autohide-delay "$2" -float
restore autohide-time-modifier "$3" -float
/usr/bin/killall Dock 2>/dev/null || true
rm -f "$backup"
