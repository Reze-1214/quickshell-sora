-- Sora (空) Hyprland design: Matte Obsidian + Ivory Architectural Frame
-- Loaded at the end of ~/.config/hypr/hyprland.lua, overriding previous settings.

local home = os.getenv("HOME")

local function soraMode()
    local f = io.open(home .. "/.config/quickshell/sora/config/mode.txt")
    if not f then return "dark" end
    local m = f:read("*a"):gsub("%s+", ""):lower()
    f:close()
    return m == "light" and "light" or "dark"
end

local activeMode = soraMode()
local isLight = activeMode == "light"

local function soraColor(key, fallback)
    local f = io.open(home .. "/.config/quickshell/sora/config/colors.json")
    if not f then return fallback end
    local content = f:read("*a")
    f:close()
    local block = content:match('"' .. key .. '"%s*:%s*(%b{})')
    if block then
        local modeBlock = block:match('"' .. activeMode .. '"%s*:%s*(%b{})') or block
        local hex = modeBlock:match('"color"%s*:%s*"#(%x%x%x%x%x%x)"') or block:match('"color"%s*:%s*"#(%x%x%x%x%x%x)"') or block:match('"#(%x%x%x%x%x%x)"')
        if hex then return hex end
    end
    return content:match('"' .. key .. '"%s*:%s*"#(%x%x%x%x%x%x)"') or fallback
end

local primary   = soraColor("primary", isLight and "252c2f" or "e8ebeb")
local secondary = soraColor("secondary", isLight and "4a565b" or "aab5ba")
local subtext   = soraColor("subtext", "8e95a5")

hl.config({
    general = {
        layout                  = "dwindle",
        gaps_in                 = 6,
        gaps_out                = 12,
        border_size             = 2,
        resize_on_border        = true,
        extend_border_grab_area = 0,
        hover_icon_on_border    = true,
        col = {
            active_border   = { colors = { "rgba(" .. primary .. "dd)", "rgba(" .. secondary .. "66)" }, angle = 45 },
            inactive_border = isLight and "rgba(171a1c22)" or "rgba(ffffff18)",
        },
    },

    dwindle = {
        preserve_split = true,
        smart_split    = false,
        smart_resizing = true,
    },

    master = {
        mfact      = 0.55,
        new_status = "slave",
    },

    input = {
        accel_profile = "flat",
        sensitivity   = 0.0,
    },

    decoration = {
        rounding         = 14,
        active_opacity   = 0.96,
        inactive_opacity = 0.88,

        blur = {
            enabled           = true,
            size              = 7,
            passes            = 3,
            new_optimizations = true,
            xray              = true,
            ignore_opacity    = true,
            noise             = 0.018,
            brightness        = 1.0,
            contrast          = 0.95,
            popups            = true,
        },

        shadow = {
            enabled      = true,
            range        = 8,
            render_power = 2,
            offset       = "0 2",
            color        = "rgba(00000044)",
        },
    },

    animations = { enabled = true },
})

hl.window_rule({ match = { fullscreen = false }, opacity = "0.96 override 0.88 override" })

-- Silky-smooth curves (critically damped, zero jitter)
hl.curve("silkOut",    { type = "bezier", points = { {0.16, 1.0}, {0.3, 1.0} } })
hl.curve("linearFade", { type = "bezier", points = { {0.0, 0.0},  {1.0, 1.0} } })
-- Critically damped spring: m=1, k=320, ζ=0.88 -> c = 2*0.88*sqrt(320) ≈ 31.5
hl.curve("smoothSpring", { type = "spring", mass = 1, stiffness = 320, dampening = 31.5 })

hl.animation({ leaf = "windowsIn",   enabled = true,  speed = 3.8, spring = "smoothSpring", style = "popin 88%" })
hl.animation({ leaf = "windowsOut",  enabled = true,  speed = 2.4, bezier = "silkOut",      style = "popin 92%" })
hl.animation({ leaf = "windowsMove", enabled = true,  speed = 3.5, bezier = "silkOut" })
hl.animation({ leaf = "workspaces",  enabled = true,  speed = 3.6, bezier = "silkOut",      style = "slidefade 18%" })
hl.animation({ leaf = "fade",        enabled = true,  speed = 2.5, bezier = "linearFade" })
hl.animation({ leaf = "fadeDim",     enabled = true,  speed = 2.5, bezier = "linearFade" })
hl.animation({ leaf = "border",      enabled = true,  speed = 3.5, bezier = "silkOut" })
hl.animation({ leaf = "borderangle", enabled = false, speed = 1,   bezier = "linearFade" })

-- Sora overlays use internal 120fps QtQuick animations (open & close), so disable conflicting compositor layer anims
hl.layer_rule({ match = { namespace = "sora-launcher" }, blur = false, no_anim = true })
hl.layer_rule({ match = { namespace = "sora-wallpaper-picker" }, blur = false, no_anim = true })
hl.layer_rule({ match = { namespace = "sora-(bar|dashboard|osd|brightness-osd|powermenu|notifications|center-popover|battery-popover|tray-popover|dock|contextmenu|widget-manager)" }, blur = true, ignore_alpha = 0.2, no_anim = true })
hl.layer_rule({ match = { namespace = "sora-background" }, no_anim = true })

-- Super key and Super+Space shortcuts for Sora Start Menu (Windows style)
hl.unbind("SUPER + SUPER_L")
hl.unbind("SUPER_L")
hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd("quickshell ipc -c sora call sora toggleLauncher"), { release = true })
hl.bind("SUPER_L", hl.dsp.exec_cmd("quickshell ipc -c sora call sora toggleLauncher"), { release = true })
hl.unbind("SUPER + Space")
hl.bind("SUPER + Space", hl.dsp.exec_cmd("quickshell ipc -c sora call sora toggleLauncher"))

-- Dashboard (Pengganti Caelestia Sidebar)
hl.unbind("SUPER + N")
hl.bind("SUPER + N", hl.dsp.exec_cmd("quickshell ipc -c sora call sora toggleDashboard"))
hl.unbind("SUPER + D")
hl.bind("SUPER + D", hl.dsp.exec_cmd("quickshell ipc -c sora call sora toggleDashboard"))

-- Power Menu (Pengganti Caelestia Session)
hl.unbind("CTRL + ALT + Delete")
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("quickshell ipc -c sora call sora togglePowerMenu"))
hl.unbind("SUPER + SHIFT + E")
hl.bind("SUPER + SHIFT + E",   hl.dsp.exec_cmd("quickshell ipc -c sora call sora togglePowerMenu"))

-- Lock Screen (Native Hyprlock - Anti-Slop Architectural Lockscreen)
hl.unbind("SUPER + L")
hl.bind("SUPER + L", hl.dsp.exec_cmd("hyprlock"))

-- Kanji Workspace Toggle
hl.unbind("SUPER + SHIFT + K")
hl.bind("SUPER + SHIFT + K", hl.dsp.exec_cmd("quickshell ipc -c sora call sora toggleKanji"))

-- Wallpaper Picker Card Carousel
hl.unbind("SUPER + SHIFT + W")
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("quickshell ipc -c sora call sora toggleWallpaperPicker"))

-- Brightness (Memicu Brightness OSD Sora via IPC dengan fallback brightnessctl)
hl.unbind("XF86MonBrightnessUp")
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("sh -c 'quickshell ipc -c sora call sora brightnessUp >/dev/null 2>&1 || brightnessctl -n set 5%+'"), { locked = true, repeating = true })
hl.unbind("XF86MonBrightnessDown")
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("sh -c 'quickshell ipc -c sora call sora brightnessDown >/dev/null 2>&1 || brightnessctl -n set 5%-'"), { locked = true, repeating = true })

-- Media Control (Tersinkron dengan modul Media Sora)
hl.unbind("XF86AudioPlay")
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.unbind("XF86AudioPause")
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.unbind("XF86AudioNext")
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.unbind("XF86AudioPrev")
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Bottom Dock Toggle (Default ada, auto-hide saat fullscreen, manual toggle SUPER+B)
hl.unbind("SUPER + B")
hl.bind("SUPER + B", hl.dsp.exec_cmd("quickshell ipc -c sora call sora toggleDock"))

-- Window Minimize / Hide & Restore Toggle (Windows style toggle & dock sync)
hl.unbind("SUPER + H")
hl.bind("SUPER + H", hl.dsp.exec_cmd(home .. "/.config/quickshell/sora/scripts/toggle_minimize.sh"))

-- Emergency Process Killer (Anti-Lag shortcut seketika)
hl.bind("SUPER + Escape", hl.dsp.exec_cmd("hyprctl kill"))
hl.bind("SUPER + SHIFT + Escape", hl.dsp.exec_cmd("sh -c 'pid=$(hyprctl activewindow -j | jq -r .pid); if [ -n \"$pid\" ] && [ \"$pid\" != \"null\" ]; then kill -9 $pid && notify-send -u critical \"Sora Emergency Kill\" \"Proses aktif PID $pid dipaksa mati\"; fi'"))

-- Restart Sora Shell
hl.unbind("CTRL + SUPER + ALT + R")
hl.bind("CTRL + SUPER + ALT + R", hl.dsp.exec_cmd("pkill -x quickshell; sleep 0.2; quickshell -c sora -n"))

-- ============================================================================
-- SORA CORE UTILITIES (Screenshot, Screen Record, Voice/Mic, Settings)
-- ============================================================================
local screenshotScript = home .. "/.config/quickshell/sora/scripts/screenshot.sh"
local recordScript     = home .. "/.config/quickshell/sora/scripts/record.sh"

-- Screenshot Suite (Ultra HD 2x Supersampling + Auto-save + Clipboard)
hl.unbind("Print")
hl.bind("Print",             hl.dsp.exec_cmd(screenshotScript))
hl.unbind("SUPER + SHIFT + S")
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd(screenshotScript))
hl.unbind("SUPER + Print")
hl.bind("SUPER + Print",     hl.dsp.exec_cmd(screenshotScript .. " --fullscreen"))
hl.unbind("SUPER + ALT + S")
hl.bind("SUPER + ALT + S",   hl.dsp.exec_cmd(screenshotScript .. " --window"))

-- Screen Recording Suite (wf-recorder toggle: region vs fullscreen, with/without audio)
hl.unbind("CTRL + ALT + R")
hl.bind("CTRL + ALT + R",             hl.dsp.exec_cmd(recordScript))
hl.unbind("SUPER + ALT + R")
hl.bind("SUPER + ALT + R",            hl.dsp.exec_cmd(recordScript .. " --sound"))
hl.unbind("CTRL + SHIFT + ALT + R")
hl.bind("CTRL + SHIFT + ALT + R",     hl.dsp.exec_cmd(recordScript .. " --fullscreen --sound"))

-- Voice & Microphone Control (PipeWire toggle mute)
hl.unbind("SUPER + SHIFT + M")
hl.bind("SUPER + SHIFT + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.unbind("XF86AudioMicMute")
hl.bind("XF86AudioMicMute",  hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })

-- Audio Mixer / Advanced Sound Settings
hl.unbind("CTRL + ALT + V")
hl.bind("CTRL + ALT + V", hl.dsp.exec_cmd("pwvucontrol"))

-- Window Floating & Workspace Ergonomics (Zero-Friction Windows-Style & Tiling Standard)
hl.unbind("SUPER + SHIFT + Space")
hl.bind("SUPER + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }))

for i = 1, 9 do
    hl.unbind("SUPER + SHIFT + " .. i)
    hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i) }))
end



