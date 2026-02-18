# ✨ Pixie SDDM

A clean, modern, and minimal SDDM theme inspired by Google Pixel UI and Material Design 3. 

<div align="center">
  <img src="screenshots/lock_screen.png" width="45%" alt="Lock Screen" />
  <img src="screenshots/login_screen.png" width="45%" alt="Login Screen" />
</div>

<div align="center">
  <img src="screenshots/lock_screen_2.png" width="22%" />
  <img src="screenshots/login_screen_2.png" width="22%" />
  <img src="screenshots/lock_screen_3.png" width="22%" />
  <img src="screenshots/login_screen_3.png" width="22%" />
</div>

<div align="center">
  <img src="screenshots/lock_screen_4.png" width="22%" />
  <img src="screenshots/login_screen_4.png" width="22%" />
  <img src="screenshots/lock_screen_5.png" width="22%" />
  <img src="screenshots/login_screen_5.png" width="22%" />
</div>

## 🌟 Features

- **Pixel Aesthetic:** Clean typography and a unique two-tone stacked clock.
- **Material You Dynamic Colors (v2.0):** Intelligent color extraction logic that automatically samples your wallpaper to create a perfectly matched dual-tone clock and UI accents.
- **Smooth Transitions:** High-performance fade-in animations for the clock and UI elements once color extraction is complete.
- **Material Design 3:** Dark card UI with "Material You" inspired accents and smooth interactions.
- **Interactive Dropdowns:** Sophisticated user and session selection menus with perfect vertical alignment.
- **Keyboard Navigation:** Full support for navigating menus with `Up`/`Down` arrows and confirming with `Enter`.
- **Intelligent Fallbacks:** 
  - Shows a beautiful "Initial" circle (e.g., "C" for Captain) if no user avatar is found.
  - Automatically handles session names and icons for a polished look.
- **Blur Effects:** Adaptive background blur that transitions smoothly when the login card is active.

## 📦 Prerequisites

To ensure the theme works correctly (and to avoid a black screen), you must install the following Qt5 modules:

### Arch Linux / CachyOS / Manjaro / EndeavourOS
```bash
sudo pacman -S --needed qt5-graphicaleffects qt5-quickcontrols2 qt5-svg
```

### Ubuntu / Debian / Linux Mint / Kali
```bash
sudo apt update
sudo apt install qml-module-qtgraphicaleffects qml-module-qtquick-controls2 qml-module-qtquick-layouts libqt5svg5
```

### Fedora / RHEL / CentOS
```bash
sudo dnf install qt5-qtgraphicaleffects qt5-qtquickcontrols2 qt5-qtsvg
```

### openSUSE
```bash
sudo zypper install libqt5-qtgraphicaleffects libqt5-qtquickcontrols2 libqt5-qtsvg
```

## 🚀 Installation

The easiest way to install **Pixie** is by using an AUR helper or the provided interactive installation script:

### 1. Arch Linux (AUR)
If you are on Arch Linux, you can install the theme from the AUR:
```bash
yay -S pixie-sddm-git
```
**Important:** After installation, you must manually apply the theme (see the [Configuration](#-configuration) section below).

### 2. Automatic Script (Recommended)
```bash
git clone https://github.com/xCaptaiN09/pixie-sddm.git && cd pixie-sddm && sudo ./install.sh
```
The script will copy the files and offer to automatically set Pixie as your active theme.

### 3. NixOS (Declarative)
NixOS users should add the following snippet to their `configuration.nix` (or a separate module):

```nix
{ pkgs, ... }:

{
  services.displayManager.sddm = {
    enable = true;
    theme = "pixie";
  };

  environment.systemPackages = [
    (pkgs.stdenv.mkDerivation {
      name = "pixie-sddm";
      src = pkgs.fetchFromGitHub {
        owner = "xCaptaiN09";
        repo = "pixie-sddm";
        rev = "main";
        sha256 = "sha256-0000000000000000000000000000000000000000000="; # Update after first build attempt
      };
      installPhase = ''
        mkdir -p $out/share/sddm/themes/pixie
        cp -r * $out/share/sddm/themes/pixie/
      '';
    })
    pkgs.libsForQt5.qtgraphicaleffects
    pkgs.libsForQt5.qtquickcontrols2
    pkgs.libsForQt5.qtsvg
  ];
}
```

### 4. Manual Installation
1. **Clone and enter the repository:**
   ```bash
   git clone https://github.com/xCaptaiN09/pixie-sddm.git && cd pixie-sddm
   ```

2. **Copy the theme to SDDM directory:**
   ```bash
   sudo mkdir -p /usr/share/sddm/themes/pixie
   sudo cp -r assets components Main.qml metadata.desktop theme.conf LICENSE /usr/share/sddm/themes/pixie/
   ```

### 4. Test the theme (Optional)
You can test the theme without logging out using the `sddm-greeter`:
```bash
sddm-greeter --test-mode --theme /usr/share/sddm/themes/pixie
```

## 🛠 Configuration

To set **Pixie** as your active theme, create or edit the SDDM configuration file (usually `/etc/sddm.conf.d/theme.conf`):

```bash
sudo mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=pixie" | sudo tee /etc/sddm.conf.d/theme.conf
```

Alternatively, edit `/etc/sddm.conf` directly:
```ini
[Theme]
Current=pixie
```

## 🎨 Customization

You can easily customize the theme by editing the `theme.conf` file inside the theme directory:

- **Background:** Replace `assets/background.jpg` with your own wallpaper. The theme will automatically adapt its colors!
- **Accent Fallback:** The `accentColor` setting now acts as a smart fallback if the automatic extraction needs a manual hint.
- **Fonts:** The theme uses `Google Sans Flex` (included).

## 🤝 Credits

- **Author:** [xCaptaiN09](https://github.com/xCaptaiN09)
- **Design Inspiration:** Google Pixel & Material You.
- **Font:** Google Sans Flex.

---
*Made with ❤️ for the Linux community.*
