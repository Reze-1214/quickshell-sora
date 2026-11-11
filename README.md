# Sora (空) `v0.1.0-alpha`

> **Status: Work in Progress (Alpha)**  
> Sora is currently in active development. Features, layout refinements, and documentation are continuously evolving.

A sleek, minimalist, Material You desktop shell for Hyprland built with [Quickshell](https://quickshell.outfoxxed.me/).

![Desktop Preview](assets/screenshots/preview-desktop.png)

---

## Visual Tour & Key Modules

### 1. Ultra-Slim Floating Top Bar
A compact 38px bar with 30px pill modules designed to maximize usable screen estate without visual clutter:

![Top Bar](assets/screenshots/preview-bar.png)

- **Left Section (Workspaces)**: Dynamic workspace indicator showing active workspace index, with a toggleable Kanji numeral mode (一, 二, 三...) and current active window title pill.
- **Center Section (Unified Island)**: A 3-page interactive sliding capsule:
  - *Page 1*: Quick profile card and date summary.
  - *Page 2*: Live MPRIS media controls (play/pause, track title, artist).
  - *Page 3*: System hardware telemetry (CPU, RAM, and temperature meters).
  - *Interaction*: Simply scroll up/down over the capsule to switch pages instantly.
- **Right Section (Status Cluster)**:
  - Live Bluetooth indicator showing connected device name (click to open panel, right-click to toggle adapter power).
  - Network status indicator with Wi-Fi signal strength.
  - Privacy Microphone Mute badge (lights up when microphone is muted).
  - Clock pill with Do Not Disturb (DND) status badge (right-click to toggle DND).

---

### 2. Dynamic Island Toast Notifications
A notification toast floating directly beneath the center island:

![Notification Toast](assets/screenshots/preview-notification.png)

- **Adaptive Width**: Intelligently hugs content from 168px up to 304px, preventing oversized empty bubbles.
- **Clean Hierarchy**: 2-line layout prioritizing the application title and message preview.
- **Wallpaper-Derived Styling**: Subtle 1px outline using dynamic Material You accents extracted from your current wallpaper.
- **Non-Intrusive Controls**: Dismiss button appears gracefully on mouse hover to keep the interface pristine during normal viewing.

---

### 3. Modular Desktop Widgets
A collection of lightweight, non-intrusive widgets that sit directly on your wallpaper:

![Desktop Widgets](assets/screenshots/preview-widgets.png)

- **Pulse Health Widget**: Compact radial or bar meters for live CPU, memory, and thermal telemetry.
- **Network Telemetry**: Real-time download/upload speed monitoring with link quality indicators.
- **Media Wave**: Animated audio visualizer bars synced to active media playback.
- **Photo Frame**: Customizable on-desktop polaroid/photo frame that defaults to matching your active wallpaper or personal photo.
- **Sun Phase & Weather**: Day/night solar cycle display combined with local weather conditions and temperature.

---

## Dependencies

Make sure the following packages are installed on your system (Arch / CachyOS / Fedora / NixOS):

### Core
- `quickshell` (>= 0.1.0)
- `hyprland` (Wayland compositor)
- `matugen` (Material You color generation)

### System Services & Utilities
- `wireplumber` or `pipewire` (`wpctl` for audio & mic volume/mute)
- `bluez` / `bluez-utils` (`bluetoothctl` for bluetooth connectivity)
- `playerctl` (MPRIS media playback control)
- `networkmanager` (`nmcli` for network management)
- `grim` & `slurp` (screenshot utilities)
- `zenity` (file and directory picker dialogs)

### Recommended Fonts
- `Adwaita Sans` / `Inter` (UI typography)
- `Material Symbols Outlined` (Iconography)
- `JetBrainsMono Nerd Font` (Monospace & telemetry)

---

## Installation

1. **Clone the repository** to your Quickshell configuration path:
   ```bash
   git clone https://github.com/Reze-1214/quickshell-sora.git ~/.config/quickshell/sora
   ```

2. **Launch with Quickshell**:
   ```bash
   quickshell -c sora
   ```

3. **Auto-start on Hyprland**:
   Add this line to your `~/.config/hypr/hyprland.conf`:
   ```ini
   exec-once = quickshell -c sora -n
   ```

---

## Key Shortcuts & Interactions

| Action | Interaction |
| :--- | :--- |
| **Open Control Center / Dashboard** | Left-click the Clock pill (or top-right cluster) |
| **Toggle Do Not Disturb (DND)** | Right-click the Clock pill |
| **Toggle Bluetooth Power** | Right-click the Bluetooth icon in the top bar |
| **Cycle Center Island Pages** | Scroll wheel up / down over the Center Island |
| **Toggle Light / Dark Mode** | Right-click desktop -> Select Mode Terang / Mode Gelap |
| **Change Wallpaper & Accent** | Open Dashboard -> Wallpaper Studio or Accent Picker |
| **Toggle Desktop Widgets** | Right-click desktop -> Widget Manager |

---

## Roadmap (`v0.1.x` - `v0.2.0`)

- [x] Floating ultra-slim bar with hardware status cluster
- [x] Dynamic island toast notifications with adaptive width
- [x] Material You wallpaper extraction & consistent accent lock
- [x] Modular desktop widgets (Pulse Health, Network, Media Wave, Sun Phase)
- [ ] Multi-monitor independent bar configuration
- [ ] Customizable widget positioning persistence via UI drag
- [ ] Additional quick toggle integrations (Night Light, VPN)

---

## License

This project is licensed under the [MIT License](LICENSE) - Copyright (c) 2026 Reze-1214.
