# Docan

<p align="center">
  <img src="assets/icon_1024.png" alt="Docan Logo" width="128" height="128">
</p>

<p align="center">
  <strong>Universal AI Chat Application</strong><br>
  iOS 26 / macOS Tahoe Native with Liquid Glass Design
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#supported-providers">Providers</a> •
  <a href="#installation">Installation</a> •
  <a href="#building">Building</a> •
  <a href="#license">License</a>
</p>

---

## Overview

Docan is a beautiful, cross-platform AI chat application that brings together multiple AI providers into one unified interface. Featuring a stunning Liquid Glass design inspired by iOS 26 and macOS Tahoe, Docan provides a premium chat experience across all your devices.

## Features

- 🎨 **Liquid Glass UI** - Stunning glassmorphic design with blur effects and transparency
- 🤖 **Multiple AI Providers** - Chat with Gemini, ChatGPT, Claude, and Ollama
- 💬 **Conversation Management** - Create, save, and organize multiple conversations
- 📱 **Responsive Design** - Adaptive layouts for mobile and desktop
- 🌙 **Dark Mode** - Beautiful dark theme with glass effects
- ⚡ **Smart Retry** - Automatic model fallback on rate limits (429 errors)
- 🔒 **Secure Storage** - API keys stored securely on device
- 📝 **Markdown Support** - Rich text rendering with syntax highlighting
- 🌐 **Cross-Platform** - iOS, Android, macOS, Windows, Linux, and Web

## Supported Providers

| Provider | Models | Local/Cloud |
|----------|--------|-------------|
| **Google Gemini** | Gemini 3 Pro, 2.5 Pro/Flash/Lite, 2.0 Flash, 1.5 Pro/Flash | Cloud |
| **OpenAI** | GPT-4o, GPT-4o Mini, GPT-4 Turbo, GPT-3.5 Turbo | Cloud |
| **Anthropic Claude** | Claude Sonnet 4, Claude 3.5 Sonnet/Haiku, Claude 3 Opus | Cloud |
| **Ollama** | Llama, Mistral, CodeLlama, and more | Local |

## Screenshots

<p align="center">
  <img src="assests/desktop.png" alt="Docan Desktop" width="800"><br>
  <em>Desktop Layout</em>
</p>

<p align="center">
  <img src="assests/mobile.png" alt="Docan Mobile" width="300"><br>
  <em>Mobile Layout</em>
</p>

## Installation

### Pre-built Packages (Linux)

Download the latest release:

- **AppImage**: `docan-x.x.x-linux.AppImage` - Portable, run anywhere
- **Debian/Ubuntu**: `docan-x.x.x-linux.deb` - Install with `sudo dpkg -i docan-*.deb`

### From Source

1. **Prerequisites**
   - [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.10.3 or later)
   - For Linux: `sudo apt install libsecret-1-dev libjsoncpp-dev`
   - For macOS: Xcode 15+
   - For Windows: Visual Studio 2022 with C++ workload

2. **Clone & Install**
   ```bash
   git clone https://gitlab.com/httpanimations/docan.git
   cd docan
   flutter pub get
   ```

3. **Run**
   ```bash
   flutter run
   ```

## Building

### All Platforms

```bash
# Debug
flutter run

# Release
flutter build <platform>
# Where <platform> is: apk, ios, macos, windows, linux, web
```

### Linux Packages

```bash
# Install flutter_distributor
dart pub global activate flutter_distributor

# Build AppImage
flutter_distributor package --platform linux --targets appimage

# Build .deb
flutter_distributor package --platform linux --targets deb
```

## Configuration

### API Keys

1. Open Docan and go to **Settings** (gear icon)
2. Enter your API keys:
   - **Gemini**: Get from [Google AI Studio](https://aistudio.google.com/apikey)
   - **OpenAI**: Get from [OpenAI Platform](https://platform.openai.com/api-keys)
   - **Claude**: Get from [Anthropic Console](https://console.anthropic.com/)
   - **Ollama**: Install [Ollama](https://ollama.ai) locally (default: `http://localhost:11434`)

### Ollama Setup

```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Pull a model
ollama pull llama3.2

# Ollama runs automatically on http://localhost:11434
```

## Project Structure

```
lib/
├── main.dart              # App entry point
├── models/                # Data models
│   ├── ai_provider.dart   # AI provider definitions
│   ├── chat_message.dart  # Message model
│   └── conversation.dart  # Conversation model
├── services/              # Business logic
│   ├── ai_service.dart    # Abstract AI interface
│   ├── chat_service.dart  # Chat coordinator
│   ├── gemini_service.dart
│   ├── openai_service.dart
│   ├── claude_service.dart
│   ├── ollama_service.dart
│   └── storage_service.dart
├── screens/               # App screens
│   ├── mobile_chat_screen.dart
│   └── desktop_chat_screen.dart
├── components/            # Reusable widgets
│   ├── liquid_glass_container.dart
│   ├── chat_bubble.dart
│   ├── chat_input.dart
│   ├── conversation_list.dart
│   ├── model_selector.dart
│   └── settings_form.dart
└── theme/                 # Styling
    └── liquid_glass_theme.dart
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the **GNU General Public License v3.0** - see the [LICENSE](LICENSE) file for details.

## Links

- 🌐 [Website](https://httpanimations.com)
- 📦 [GitLab Repository](https://gitlab.com/httpanimations/docan)
- 📜 [Terms of Service](https://httpanimations.com/tos)
- 🔐 [Privacy Policy](https://httpanimations.com/privacy)

---

<p align="center">
  Made with ❤️ by <a href="https://httpanimations.com">httpanimations</a>
</p>