-- ALPORA managed session v1
-- Defaults for a complete session; individual settings remain in ~/.config/poly-shell.
local config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local root = config .. "/hypr/"
local launcher = os.getenv("HOME") .. "/.local/bin/poly-shell"
local state = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/poly-shell/"
local function quoted(value) return "'" .. value:gsub("'", "'\\''") .. "'" end
local function run(key, command, flags)
    hl.bind(key, hl.dsp.exec_cmd(command), flags or {})
end
hl.monitor({output="", mode="preferred", position="auto", scale=1})
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("QT_STYLE_OVERRIDE", "Fusion")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("GTK_IM_MODULE", "fcitx")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")

-- Fluid motion curves (macOS / iOS snappy spring physics)
hl.curve("fluent", { type = "bezier", points = { {0.16, 1}, {0.3, 1} } })
hl.curve("snappy", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.curve("polyPanel", { type = "bezier", points = { {0.2, 0}, {0.2, 1} } })

hl.animation({ leaf = "windows", enabled = true, speed = 4.0, bezier = "fluent", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3.0, bezier = "fluent", style = "popin 85%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4.0, bezier = "fluent" })
hl.animation({ leaf = "border", enabled = true, speed = 4.0, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.0, bezier = "fluent" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4.5, bezier = "fluent", style = "slide" })

hl.config({
    general={layout="dwindle",gaps_in=5,gaps_out=12,border_size=2,resize_on_border=true},
    decoration={
        rounding=16,
        blur={enabled=true,size=6,passes=2,noise=0.012,vibrancy=0.2},
        shadow={enabled=true,range=14,render_power=3,color=0x55121819}
    },
    animations={enabled=true},
    input={
        kb_layout="us",follow_mouse=1,
        touchpad={natural_scroll=true,tap_to_click=true}
    },
    dwindle={preserve_split=true},
    misc={disable_hyprland_logo=true,force_default_wallpaper=0,vfr=true},
    cursor={enable_hyprcursor=false},
})
hl.layer_rule({name="alpora-glass",match={namespace="^poly-shell(-.*)?$"},blur=true,ignore_alpha=0.15,no_anim=true})
hl.layer_rule({name="alpora-notifications",match={namespace="^notifications$"},blur=true,ignore_alpha=0.15})
hl.layer_rule({name="alpora-overview",match={namespace="^poly-workspace-overview$"},blur=true,ignore_alpha=0.15})
hl.layer_rule({name="alpora-video-pip",match={namespace="^poly-video-pip$"},blur=true,ignore_alpha=0.15})

-- Starts only in this Hyprland session. No machine-wide desktop replacement.
hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XCURSOR_THEME XCURSOR_SIZE GTK_IM_MODULE QT_IM_MODULE XMODIFIERS")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XCURSOR_THEME XCURSOR_SIZE GTK_IM_MODULE QT_IM_MODULE XMODIFIERS")
    hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
    hl.exec_cmd("mako -c " .. quoted(state .. "mako-theme.conf"))
    hl.exec_cmd("hypridle -c " .. quoted(root .. "alpora-hypridle.conf"))
    hl.exec_cmd("fcitx5 -d")
    hl.exec_cmd(quoted(launcher) .. " start")
    hl.exec_cmd(quoted(launcher) .. " wallpaper")
end)

-- Core applications
run("SUPER + Return", "foot")
run("SUPER + E", "nautilus --new-window")
run("SUPER + B", "firefox")
run("SUPER + L", "hyprlock -c " .. quoted(root .. "hyprlock.conf"))
run("SUPER + N", "nm-connection-editor")
run("SUPER + A", "pavucontrol")
run("SUPER + SHIFT + E", "hyprshutdown")

-- Global shell actions (Super+Space, Super+I, Super+W, Super+V, Super+Tab, PrintScreen)
hl.bind("Print", hl.dsp.global("poly-shell:screenshot"))
hl.bind("SUPER + SHIFT + S", hl.dsp.global("poly-shell:screenshot"))
hl.bind("SUPER + Escape", hl.dsp.global("poly-shell:power-menu"))
hl.bind("XF86PowerOff", hl.dsp.global("poly-shell:power-menu"))
hl.bind("SUPER + Space", hl.dsp.global("poly-shell:launcher"))
hl.bind("SUPER + R", hl.dsp.global("poly-shell:launcher"))
hl.bind("SUPER + I", hl.dsp.global("poly-shell:quick-settings"))
hl.bind("SUPER + M", hl.dsp.global("poly-shell:notifications"))
hl.bind("SUPER + V", hl.dsp.global("poly-shell:clipboard"))
hl.bind("SUPER + Tab", hl.dsp.global("poly-shell:overview"))
hl.bind("SUPER + W", hl.dsp.global("poly-shell:toggle-mode"))
hl.bind("SUPER + P", hl.dsp.global("poly-shell:display-project"))
hl.bind(", XF86Display", hl.dsp.global("poly-shell:display-project"))
hl.bind("CTRL + SHIFT + Escape", hl.dsp.global("poly-shell:task-manager"))
hl.bind("SUPER + Y", hl.dsp.global("poly-shell:video-pip"))

-- Window operations
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + C", hl.dsp.window.close())
hl.bind("SUPER + F", hl.dsp.window.fullscreen({action="toggle"}))
hl.bind("SUPER + SHIFT + V", hl.dsp.window.float({action="toggle"}))
hl.bind("SUPER + J", hl.dsp.layout("togglesplit"))
hl.bind("ALT + Tab", hl.dsp.window.focus_next())

-- Directional focus and window moving
for _,direction in ipairs({"left","right","up","down"}) do
    hl.bind("SUPER + "..direction, hl.dsp.focus({direction=direction}))
    hl.bind("SUPER + SHIFT + "..direction, hl.dsp.window.move({direction=direction}))
end

-- Keyboard window resizing
hl.bind("SUPER + CTRL + left", hl.dsp.window.resize({x=-40, y=0}))
hl.bind("SUPER + CTRL + right", hl.dsp.window.resize({x=40, y=0}))
hl.bind("SUPER + CTRL + up", hl.dsp.window.resize({x=0, y=-40}))
hl.bind("SUPER + CTRL + down", hl.dsp.window.resize({x=0, y=40}))

-- Workspaces
for i=1,10 do
    hl.bind("SUPER + "..(i%10), hl.dsp.focus({workspace=i}))
    hl.bind("SUPER + SHIFT + "..(i%10), hl.dsp.window.move({workspace=i}))
end
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), {mouse=true})
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), {mouse=true})
hl.gesture({fingers=3, direction="horizontal", action="workspace"})
local overviewGesture = dofile(root .. "alpora-overview.lua")
hl.gesture({fingers=3, direction="up", action=overviewGesture("up")})
hl.gesture({fingers=3, direction="down", action=overviewGesture("down")})
local palette = io.open(root .. "poly-shell-theme.lua", "r")
if palette then palette:close(); dofile(root .. "poly-shell-theme.lua") end
run("XF86AudioRaiseVolume", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", {locked=true, repeating=true})
run("XF86AudioLowerVolume", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", {locked=true, repeating=true})
run("XF86AudioMute", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", {locked=true})
run("XF86AudioMicMute", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle", {locked=true})
run("XF86MonBrightnessUp", "brightnessctl set +5%", {locked=true, repeating=true})
run("XF86MonBrightnessDown", "brightnessctl set 5%-", {locked=true, repeating=true})
run("XF86AudioPlay", "playerctl play-pause", {locked=true})
run("XF86AudioNext", "playerctl next", {locked=true})
run("XF86AudioPrev", "playerctl previous", {locked=true})
