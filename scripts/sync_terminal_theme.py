#!/usr/bin/env python3
"""
Sora (空) Terminal Theme Synchronizer
Dynamically syncs Material You palette from Sora (colors.json) to:
1. ~/.local/state/sora/sequences.txt (OSC escape sequences for active/new shell sessions)
2. ~/.config/foot/sora-colors.ini (Foot terminal color configuration)
3. Live broadcast to active /dev/pts/* terminals
"""

import os
import sys
import json
import glob

HOME = os.path.expanduser("~")
SORA_DIR = os.path.join(HOME, ".config", "quickshell", "sora")
COLORS_PATH = os.path.join(SORA_DIR, "config", "colors.json")
MODE_PATH = os.path.join(SORA_DIR, "config", "mode.txt")
STATE_DIR = os.path.join(HOME, ".local", "state", "sora")
SEQUENCES_FILE = os.path.join(STATE_DIR, "sequences.txt")
FOOT_CONFIG_DIR = os.path.join(HOME, ".config", "foot")
FOOT_THEME_FILE = os.path.join(FOOT_CONFIG_DIR, "sora-colors.ini")

def clamp(val, low=0, high=255):
    return max(low, min(high, int(val)))

def hex_to_rgb(h):
    h = h.strip().lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def rgb_to_hex(r, g, b):
    return f"{clamp(r):02x}{clamp(g):02x}{clamp(b):02x}"

def adjust_lightness(hex_str, factor):
    r, g, b = hex_to_rgb(hex_str)
    return rgb_to_hex(r * factor, g * factor, b * factor)

def to_osc_rgb(hex_str):
    r, g, b = hex_to_rgb(hex_str)
    return f"rgb:{r:02x}/{g:02x}/{b:02x}"

def generate_palette_for_mode(data, mode):
    is_dark = (mode == "dark")
    colors_dict = data.get("colors", {})

    def get_color(token, fallback):
        val = colors_dict.get(token, {})
        return val.get(mode, val.get("default", {})).get("color", fallback).lstrip("#")

    bg_hex = get_color("background", "0b141a" if is_dark else "f3f5f5")
    fg_hex = get_color("on_background", "dae4ec" if is_dark else "171a1c")
    primary_hex = get_color("primary", "82cfff" if is_dark else "00658d")
    secondary_hex = get_color("secondary", "b2c8e8" if is_dark else "4a565b")
    tertiary_hex = get_color("tertiary", "b6c5f9" if is_dark else "4a565b")
    error_hex = get_color("error", "ffb4ab" if is_dark else "ba1a1a")
    surface_hex = get_color("surface_container", "182127" if is_dark else "e5eaeb")
    outline_hex = get_color("outline", "88929a" if is_dark else "70787d")

    b16 = data.get("base16", {})
    def get_b16(code, fallback):
        val = b16.get(code, {})
        c = val.get(mode, val.get("default", {})).get("color")
        return c.lstrip("#") if c else fallback

    has_rich_b16 = get_b16("base08", "000000") not in ("000000", "ffffff")

    if has_rich_b16:
        color0 = get_b16("base00", surface_hex)
        color1 = get_b16("base08", error_hex)
        color2 = get_b16("base0b", primary_hex)
        color3 = get_b16("base0a", tertiary_hex)
        color4 = get_b16("base0d", primary_hex)
        color5 = get_b16("base0e", secondary_hex)
        color6 = get_b16("base0c", tertiary_hex)
        color7 = get_b16("base05", fg_hex)
        color8 = get_b16("base03", outline_hex)
        color9 = get_b16("base08", error_hex)
        color10 = get_b16("base0b", primary_hex)
        color11 = get_b16("base0a", tertiary_hex)
        color12 = get_b16("base0d", primary_hex)
        color13 = get_b16("base0e", secondary_hex)
        color14 = get_b16("base0c", tertiary_hex)
        color15 = get_b16("base07", "ffffff" if is_dark else "111111")
    else:
        color0 = surface_hex
        color1 = error_hex
        color2 = primary_hex
        color3 = tertiary_hex
        color4 = primary_hex
        color5 = secondary_hex
        color6 = tertiary_hex
        color7 = fg_hex

        bright_factor = 1.25 if is_dark else 0.85
        color8 = outline_hex
        color9 = adjust_lightness(error_hex, bright_factor)
        color10 = adjust_lightness(primary_hex, bright_factor)
        color11 = adjust_lightness(tertiary_hex, bright_factor)
        color12 = adjust_lightness(primary_hex, bright_factor)
        color13 = adjust_lightness(secondary_hex, bright_factor)
        color14 = adjust_lightness(tertiary_hex, bright_factor)
        color15 = "ffffff" if is_dark else "111111"

    palette_list = [
        color0, color1, color2, color3, color4, color5, color6, color7,
        color8, color9, color10, color11, color12, color13, color14, color15
    ]

    return {
        "bg": bg_hex,
        "fg": fg_hex,
        "primary": primary_hex,
        "palette": palette_list
    }

def main():
    if not os.path.exists(COLORS_PATH):
        return

    try:
        with open(COLORS_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        return

    is_dark = True
    if os.path.exists(MODE_PATH):
        try:
            with open(MODE_PATH, "r", encoding="utf-8") as f:
                is_dark = (f.read().strip().lower() != "light")
        except Exception:
            is_dark = data.get("is_dark_mode", True)
    else:
        is_dark = data.get("is_dark_mode", True)

    dark_theme = generate_palette_for_mode(data, "dark")
    light_theme = generate_palette_for_mode(data, "light")
    active_theme = dark_theme if is_dark else light_theme

    # 1. Build OSC Escape Sequences for Active Theme
    seq = []
    seq.append(f"\x1b]10;{to_osc_rgb(active_theme['fg'])}\x1b\\")
    seq.append(f"\x1b]11;{to_osc_rgb(active_theme['bg'])}\x1b\\")
    seq.append(f"\x1b]12;{to_osc_rgb(active_theme['primary'])}\x1b\\")
    seq.append(f"\x1b]17;{to_osc_rgb(active_theme['primary'])}\x1b\\")

    for idx, col in enumerate(active_theme["palette"]):
        seq.append(f"\x1b]4;{idx};{to_osc_rgb(col)}\x1b\\")

    full_sequences = "".join(seq)

    # Save sequences to ~/.local/state/sora/sequences.txt
    os.makedirs(STATE_DIR, exist_ok=True)
    with open(SEQUENCES_FILE, "w", encoding="utf-8") as f:
        f.write(full_sequences)

    # 2. Generate Foot Theme File with valid foot sections: [colors-dark] and [colors-light]
    os.makedirs(FOOT_CONFIG_DIR, exist_ok=True)
    dp = dark_theme["palette"]
    lp = light_theme["palette"]

    foot_content = f"""# Automatically generated by Sora (空) Theme Engine
# Foot terminal requires [colors-dark] and [colors-light] sections

[colors-dark]
foreground={dark_theme['fg']}
background={dark_theme['bg']}
regular0={dp[0]}
regular1={dp[1]}
regular2={dp[2]}
regular3={dp[3]}
regular4={dp[4]}
regular5={dp[5]}
regular6={dp[6]}
regular7={dp[7]}
bright0={dp[8]}
bright1={dp[9]}
bright2={dp[10]}
bright3={dp[11]}
bright4={dp[12]}
bright5={dp[13]}
bright6={dp[14]}
bright7={dp[15]}
selection-foreground={dark_theme['bg']}
selection-background={dark_theme['primary']}
urls={dark_theme['primary']}

[colors-light]
foreground={light_theme['fg']}
background={light_theme['bg']}
regular0={lp[0]}
regular1={lp[1]}
regular2={lp[2]}
regular3={lp[3]}
regular4={lp[4]}
regular5={lp[5]}
regular6={lp[6]}
regular7={lp[7]}
bright0={lp[8]}
bright1={lp[9]}
bright2={lp[10]}
bright3={lp[11]}
bright4={lp[12]}
bright5={lp[13]}
bright6={lp[14]}
bright7={lp[15]}
selection-foreground={light_theme['bg']}
selection-background={light_theme['primary']}
urls={light_theme['primary']}
"""
    with open(FOOT_THEME_FILE, "w", encoding="utf-8") as f:
        f.write(foot_content)

    # 3. Live Broadcast to active terminal PTS
    pts_devices = glob.glob("/dev/pts/[0-9]*")
    for pts in pts_devices:
        try:
            if os.access(pts, os.W_OK):
                with open(pts, "w", encoding="utf-8", errors="ignore") as f:
                    f.write(full_sequences)
        except Exception:
            pass

if __name__ == "__main__":
    main()
