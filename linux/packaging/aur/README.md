# Docan AUR Package

This is the official Arch Linux AUR package for Docan - Universal AI chat application with file attachment support.

## Features

- **File Attachment Support**: All AI providers (OpenAI, Claude, Gemini, DeepSeek, Ollama, LM Studio)
- **Memory Leak Fixes**: Stable Claude responses without freezing
- **Multi-Size Icons**: Crisp display on all screen densities
- **Wayland Compatibility**: Proper support for Wayland desktop environments
- **Desktop Integration**: Application menu entries and task manager icons

## Supported File Types

- **Text**: TXT, MD, JSON, CSV, HTML, XML, RTF
- **Documents**: PDF, DOCX
- **Images**: JPG, PNG, GIF, WebP, BMP

## Installation

### Prerequisites

Make sure you have the latest Docan build:
```bash
cd /path/to/docan
flutter build linux --release
```

### Quick Install

1. **Navigate to AUR directory:**
   ```bash
   cd linux/packaging/aur
   ```

2. **Run build script:**
   ```bash
   ./build.sh
   ```

3. **Install with makepkg:**
   ```bash
   makepkg -si
   ```

### Alternative Installation Methods

**With yay:**
```bash
./build.sh
yay -S .
```

**With trizen:**
```bash
./build.sh
trizen -S .
```

## Package Contents

- **Binary**: `/opt/docan/docan` (maintains bundle structure)
- **Wrapper**: `/usr/bin/docan-wrapper` (Wayland-compatible)
- **Symlink**: `/usr/bin/docan` → `/opt/docan/docan`
- **Desktop File**: `/usr/share/applications/docan.desktop`
- **Icons**: `/usr/share/icons/hicolor/*/apps/docan.png`
- **Dependencies**: gtk3, glib2, hicolor-icon-theme, libsecret, json-glib

## Wayland Support

The package includes Wayland compatibility features:
- Automatic Wayland backend detection
- Proper cursor theme handling
- Window decorations and task manager icons
- Environment variable configuration

## Usage

**From command line:**
```bash
docan
```

**From application menu:**
- Look for "Docan" in Office/Utility category

**With Wayland wrapper:**
```bash
docan-wrapper
```

## File Attachments

1. Click the attachment button (📎) in the chat interface
2. Select files from your system
3. Files are processed and content sent to AI
4. AI analyzes and provides responses

## Troubleshooting

**App doesn't start:**
```bash
# Check if binary exists
ls -la /opt/docan/docan

# Run directly for debugging
/opt/docan/docan
```

**Wayland issues:**
```bash
# Use Wayland wrapper explicitly
/usr/bin/docan-wrapper

# Check session type
echo $XDG_SESSION_TYPE
```

**Icons not showing:**
```bash
# Update icon cache
sudo gtk-update-icon-cache -f -t /usr/share/icons/hicolor

# Update desktop database
sudo update-desktop-database /usr/share/applications
```

## Dependencies

- **gtk3**: GTK3 framework for UI
- **glib2**: GLib library for utilities
- **hicolor-icon-theme**: Standard icon theme
- **libsecret**: Secure storage integration
- **json-glib**: JSON parsing support

## Development

To update the package:
1. Build the latest version: `flutter build linux --release`
2. Run `./build.sh` to prepare package files
3. Build with `makepkg -si` or your preferred AUR helper

## License

MIT License - see LICENSE file in the main project repository.
