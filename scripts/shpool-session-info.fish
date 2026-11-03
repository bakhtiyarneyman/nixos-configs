# Keep stable session IDs while showing useful context in the attach picker.
function __shpool_context_preexec --on-event fish_preexec
    if set -q SHPOOL_SESSION_NAME
        /etc/nixos/scripts/shpool-session-info update running "$argv[1]"
    end
end

function __shpool_context_postexec --on-event fish_postexec
    if set -q SHPOOL_SESSION_NAME
        /etc/nixos/scripts/shpool-session-info update finished "$argv[1]"
    end
end

if set -q SHPOOL_SESSION_NAME
    /etc/nixos/scripts/shpool-session-info update init
end
