
function openrgb_hook --description 'Send a command to OpenRGB HttpHook server'
    # Validate there is exactly 1 argument.
    if test (count $argv) -ne 1
        echo "Usage: openrgb_hook <command>"
        return 1
    end
    curl --silent http://localhost:6743/$argv
end

function assistant_effect
    # Use argparse to parse the command.
    # There are 5 assistant effect commands: listen, parse, think, speak, and nap.
    argparse --name='assistant_effect' h/help w/nap-after-secs -- $argv
    or return

    if test $_flag_help
        echo "Usage:"
        echo "  assistant_effect [--help] <command>"
        echo "    -h / --help             Show this help"
        echo " command The command to execute:"
        echo " - listen"
        echo " - parse"
        echo " - think"
        echo " - speak"
        echo " - nap"
        return 0
    end

    # Validate there is exactly 1 argument.
    if test (count $argv) -ne 1
        echo "Usage: assistant_effect <command >"
        return 1
    end

    # Validate the command.
    switch $argv[1]
        case listen
            set nap_after_secs 15
        case parse
            set nap_after_secs 5
        case think
            set nap_after_secs 10
        case speak
            set nap_after_secs 30
        case nap
            set nap_after_secs 0
        case '*'
            echo "Invalid command: $argv[1]. Must be one of: listen, parse, think, speak, nap."
            return 1
    end

    set effect_command $argv[1]

    # Kill the previous cleanup job.
    if test -e /tmp/assistant_effect.pid
        kill (cat /tmp/assistant_effect.pid) 2>/dev/null
    end
    # Execute the effect.
    openrgb_hook $effect_command; or return 1

    if test $nap_after_secs -gt 0
        fish -c "sleep $nap_after_secs; curl http://localhost:6743/nap" &
        echo $last_pid >/tmp/assistant_effect.pid
    end
end
