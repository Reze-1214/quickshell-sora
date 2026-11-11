#!/usr/bin/env bash
# ==============================================================================
# SORA: Windows-Style Window Minimize / Restore Toggle
# ==============================================================================
# Behavior:
# 1. If an address argument is passed -> minimize that specific window
# 2. Else if active window exists on current workspace -> minimize it
# 3. Else -> restore the last minimized window from stack
# ==============================================================================

state_file="/tmp/sora_minimized_stack"
current_ws=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // 1')

target_arg="$1"
if [ -n "$target_arg" ]; then
    target_arg="0x${target_arg#0x}"
    active_addr="$target_arg"
    active_info=$(hyprctl clients -j 2>/dev/null | jq -r --arg addr "$active_addr" '.[] | select(.address == $addr)')
    active_ws=$(echo "$active_info" | jq -r '.workspace.name // empty')
    active_class=$(echo "$active_info" | jq -r '.class // empty')
else
    active_win=$(hyprctl activewindow -j 2>/dev/null || echo "{}")
    active_addr=$(echo "$active_win" | jq -r '.address // empty')
    active_ws=$(echo "$active_win" | jq -r '.workspace.name // empty')
    active_class=$(echo "$active_win" | jq -r '.class // empty')
fi

if [ -n "$active_addr" ] && [ "$active_addr" != "null" ] && [ "$active_ws" != "special:minimized" ]; then
    # Push address to stack and minimize to scratchpad
    echo "$active_addr" >> "$state_file"
    hyprctl repl "
    hl.dispatch(hl.dsp.window.tag({ window = 'address:${active_addr}', tag = 'from_ws_${current_ws}' }))
    hl.dispatch(hl.dsp.window.move({ window = 'address:${active_addr}', workspace = 'special:minimized', follow = false }))
    " > /dev/null 2>&1
    
    # Ensure special:minimized is not kept open on the monitor
    sleep 0.05
    active_special=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].specialWorkspace.name // empty')
    if [ "$active_special" = "special:minimized" ]; then
        hyprctl repl 'return hl.dispatch(hl.dsp.workspace.toggle_special("minimized"))' > /dev/null 2>&1
    fi

    # Cycle focus to remaining window on current workspace, or clear focus if workspace is now empty
    other_win=$(hyprctl clients -j 2>/dev/null | jq -r --arg ws "$current_ws" --arg addr "$active_addr" '.[] | select((.workspace.id == ($ws | tonumber) or .workspace.name == $ws) and .address != $addr and .mapped == true) | .address' | head -n 1)
    if [ -n "$other_win" ]; then
        hyprctl repl "hl.dispatch(hl.dsp.focus({ window = 'address:${other_win}' }))" > /dev/null 2>&1
    else
        # Clear compositor focus so closing any layer-shell does not resurrect minimized windows
        temp_ws=$(( current_ws == 99 ? 98 : 99 ))
        hyprctl repl "
        hl.dispatch(hl.dsp.focus({ workspace = '${temp_ws}' }))
        hl.dispatch(hl.dsp.focus({ workspace = '${current_ws}' }))
        " > /dev/null 2>&1
    fi

    # User feedback
    app_label="${active_class:-Aplikasi}"
    notify-send -t 1800 -a "Sora" "$app_label Diminimalkan" "Tekan SUPER+H atau klik di Dock untuk menampilkan kembali"
else
    # Restore last minimized window back to active workspace
    target_addr="$target_arg"
    restore_ws="$2"
    if [ -z "$target_addr" ]; then
        if [ -s "$state_file" ]; then
            target_addr=$(tail -n 1 "$state_file")
            sed -i '$d' "$state_file"
        fi
    else
        [ -f "$state_file" ] && sed -i "/${target_addr}/d" "$state_file"
    fi

    # Fallback: find any window currently on special:minimized
    if [ -z "$target_addr" ]; then
        target_addr=$(hyprctl clients -j 2>/dev/null | jq -r '.[] | select(.workspace.name == "special:minimized") | .address' | head -n 1)
    fi

    if [ -n "$target_addr" ] && [ "$target_addr" != "null" ]; then
        if [ -z "$restore_ws" ]; then
            tagged_ws=$(hyprctl clients -j 2>/dev/null | jq -r --arg addr "$target_addr" '.[] | select(.address == $addr) | .tags[]?' 2>/dev/null | grep -E '^from_ws_[0-9]+$' | head -n 1 | sed 's/from_ws_//')
            restore_ws="${tagged_ws:-$current_ws}"
        fi

        # Remove origin workspace tag & restore window
        hyprctl repl "
        for _, i in ipairs({1,2,3,4,5,6,7,8,9,10}) do
            hl.dispatch(hl.dsp.window.tag({ window = 'address:${target_addr}', tag = '-from_ws_' .. i }))
        end
        hl.dispatch(hl.dsp.focus({ workspace = ${restore_ws} }))
        hl.dispatch(hl.dsp.window.move({ window = 'address:${target_addr}', workspace = '${restore_ws}' }))
        hl.dispatch(hl.dsp.focus({ window = 'address:${target_addr}' }))
        " > /dev/null 2>&1

        # If special:minimized was left open on monitor, close it
        active_special=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].specialWorkspace.name // empty')
        if [ "$active_special" = "special:minimized" ]; then
            hyprctl repl 'return hl.dispatch(hl.dsp.workspace.toggle_special("minimized"))' > /dev/null 2>&1
        fi
    fi
fi
