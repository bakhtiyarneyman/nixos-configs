function find_ancestor_window
    # Walks the process tree from $fish_pid upward.
    # Outputs the PID of the first sway window ancestor, or nothing for SSH.
    set -l sway_tree (swaymsg -t get_tree 2>/dev/null)
    set -l window_pids (echo $sway_tree | jq -r '[.. | select(.pid? > 0) | .pid] | unique | .[]')

    set -l pid $fish_pid
    while test "$pid" -gt 1
        if contains -- "$pid" $window_pids
            echo $pid
            return
        end
        set pid (awk '/PPid/{print $2}' /proc/$pid/status 2>/dev/null)
        or return
    end
end

function is_focused_window -a window_pid
    # Returns 0 if the given window PID is the currently focused sway window.
    set -l focused (swaymsg -t get_tree 2>/dev/null | jq '.. | select(.focused? == true) | .pid')
    test "$window_pid" = "$focused"
end

function send_notification
    # Sends a desktop notification with auto-dismiss when the given window gets focus.
    # Usage: send_notification --window-pid PID [--focus-on ACTION]... [-A action=Label]... [--] BODY
    # Outputs the selected action key, or nothing if dismissed.
    argparse 'window-pid=' 'focus-on=+' 'A=+' -- $argv
    or return 1

    set -l body "$argv"
    set -l window_pid "$_flag_window_pid"
    set -l focus_actions $_flag_focus_on
    set -l sock "$CLAUDE_NOTIFY_SOCKET"

    if test -z "$body"
        return
    end

    set -l action_args
    for a in $_flag_A
        set -a action_args -A "$a"
    end

    set -l action

    # Send via forwarded socket (SSH) or notify-send (local).
    if test -S "$sock" -a -z "$window_pid"
        # Build actions JSON object from -A key=Label arguments.
        set -l actions_json '{}'
        for a in $_flag_A
            set -l key (string split -m 1 = -- "$a")[1]
            set -l label (string split -m 1 = -- "$a")[2]
            set actions_json (echo $actions_json | jq --arg k "$key" --arg v "$label" '. + {($k): $v}')
        end

        # Build focus_on JSON array.
        set -l focus_json '[]'
        for f in $focus_actions
            set focus_json (echo $focus_json | jq --arg v "$f" '. + [$v]')
        end

        set -l response (jq -n \
            --arg body "$body" \
            --arg window_pid "$CLAUDE_NOTIFY_WINDOW_PID" \
            --argjson actions "$actions_json" \
            --argjson focus_on "$focus_json" \
            '{body:$body, window_pid:$window_pid, actions:$actions, focus_on:$focus_on}' \
            | socat -t -1 - UNIX-CONNECT:$sock)
        set action (echo $response | jq -r '.action')
    else if test -n "$body"
        set -l out (mktemp)
        stdbuf -oL notify-send --print-id $action_args 'Claude Code' -- "$body" > $out &
        set -l notify_pid $last_pid

        while not test -s $out
            sleep 0.01
        end
        set -l notify_id (head -1 $out)

        # Auto-dismiss notification when its window gets focus.
        if test -n "$window_pid"
            fish -c "
                swaymsg -m -t subscribe '[\"window\"]' | while read -l line
                    if test (echo \$line | jq -r '.change') = focus \
                        -a (echo \$line | jq -r '.container.pid') = $window_pid
                        swaync-client --close $notify_id 2>/dev/null
                        break
                    end
                end
            " </dev/null >/dev/null 2>/dev/null &
            set -l watcher_pid $last_pid

            # Handle race: window may have been focused after the caller checked
            # but before the watcher subscribed to sway events.
            set -l current_focus (swaymsg -t get_tree 2>/dev/null | jq '.. | select(.focused? == true) | .pid')
            if test "$current_focus" = "$window_pid"
                swaync-client --close $notify_id 2>/dev/null
            end
        end

        wait $notify_pid
        set action (sed -n 2p $out)

        if set -q watcher_pid
            kill $watcher_pid 2>/dev/null
        end
        rm -f $out
    end

    if test -n "$action"
        echo $action
    end

    # Focus terminal when the user selects a focus-triggering action.
    if test -n "$window_pid"; and contains -- "$action" $focus_actions
        swaymsg "[pid=$window_pid] focus" >/dev/null
    end
end
