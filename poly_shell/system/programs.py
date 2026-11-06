"""Capability-oriented runtime inventory; optional tools do not block the shell."""
import importlib.util
import shutil

# Name, Arch package, binaries, purpose, required for the shell foundation.
PROGRAMS = (
    ('Quickshell','quickshell',('quickshell',),'Panel, settings, widgets',True),
    ('Hyprland','hyprland',('hyprctl',),'Windows, workspaces, keyboard shortcuts',True),
    ('Python','python',('python3',),'Settings and system adapters',True),
    ('systemd','systemd',('systemctl','systemd-run'),'Launch shell and settings',True),
    ('D-Bus tools','glib2',('gdbus',),'Notification and sleep events',True),
    ('Foot','foot',('foot',),'Default terminal if installed',False),
    ('Kitty','kitty',('kitty',),'Additional terminal; full session uses Foot',False),
    ('Nautilus','nautilus',('nautilus',),'File manager, current Super+E',False),
    ('XDG utilities','xdg-utils',('xdg-open','xdg-mime'),'System folder handler',False),
    ('XDG user directories','xdg-user-dirs',('xdg-user-dir',),'Screenshots directory detector',False),
    ('Fuzzel','fuzzel',('fuzzel',),'External fallback launcher; primary built into shell',False),
    ('UPower','upower',('upower',),'Battery and charging status',False),
    ('WirePlumber','wireplumber',('wpctl',),'Volume, microphone and multimedia keys',False),
    ('NetworkManager','networkmanager',('nmcli','nmtui'),'Wi-Fi and advanced networking',False),
    ('Network editor','nm-connection-editor',('nm-connection-editor',),'Current Super+N',False),
    ('BlueZ tools','bluez-utils',('bluetoothctl',),'Bluetooth and pairing',False),
    ('rfkill','util-linux',('rfkill',),'Airplane mode and radio device blocking',False),
    ('Brightnessctl','brightnessctl',('brightnessctl',),'Screen brightness',False),
    ('Hyprsunset','hyprsunset',('hyprsunset',),'Night light',False),
    ('Mako','mako',('mako','makoctl'),'Notifications, history, do not disturb',False),
    ('Pavucontrol','pavucontrol',('pavucontrol',),'Advanced audio controls',False),
    ('Power profiles','power-profiles-daemon',('powerprofilesctl',),'Power profiles daemon',False),
    ('Swaybg','swaybg',('swaybg',),'Static wallpapers',False),
    ('Hyprlock','hyprlock',('hyprlock',),'Lock screen',False),
    ('Hypridle','hypridle',('hypridle',),'Idle, screen blanking and locking',False),
    ('Hyprshutdown','hyprshutdown',('hyprshutdown',),'Current Super+Shift+E',False),
    ('wl-clipboard','wl-clipboard',('wl-copy','wl-paste'),'Clipboard and clipboard history',False),
    ('Playerctl','playerctl',('playerctl',),'Multimedia keys; widgets use MPRIS directly',False),
    ('Grim','grim',('grim',),'Screen capture',False),
    ('Slurp','slurp',('slurp',),'Screen capture region selection',False),
    ('Libnotify','libnotify',('notify-send',),'Notification for saved screenshot',False),
    ('GSettings','glib2',('gsettings',),'GTK and icon theme coordination',False),
    ('Wine','wine',('wine',),'Windows .exe runner for apps like Zalo, UltraViewer',False),
)


def inventory():
    result=[]
    for name,package,commands,purpose,required in PROGRAMS:
        tools={command:shutil.which(command) for command in commands}
        result.append(dict(name=name,package=package,tools=tools,purpose=purpose,required=required,
                           available=all(tools.values())))
    pillow=importlib.util.find_spec('PIL') is not None
    result.append(dict(name='Pillow',package='python-pillow',tools={'PIL':pillow},
                       purpose='Wallpaper import, palette extraction and Timeline preparation',required=False,available=pillow))
    return result
