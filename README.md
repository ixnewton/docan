# Docan

<p align="center">
  <img src="assets/icon_1024.png" alt="Docan Logo" width="128" height="128">
</p>

A multi-provider AI chat client with a Liquid Glass UI. Runs on iOS, Android, macOS, Windows, Linux, and web.

## Features

- **Liquid Glass UI** — Glassmorphic design with blur and transparency effects
- **Multi-provider support** — Gemini, ChatGPT, Claude, and Ollama in one app
- **Conversation history** — Save and organize your chats
- **Responsive layout** — Works on phones and desktops
- **Dark mode** — Glass effects that actually look good
- **Auto-retry** — Falls back to alternate models on rate limits
- **Local storage** — API keys stay on your device
- **Markdown rendering** — Code blocks with syntax highlighting

## Supported Providers

| Provider | Models | Type |
|----------|--------|------|
| Google Gemini | Gemini 3 Pro, 2.5 Pro/Flash/Lite, 2.0 Flash, 1.5 Pro/Flash | Cloud |
| OpenAI | GPT-4o, GPT-4o Mini, GPT-4 Turbo, GPT-3.5 Turbo | Cloud |
| Anthropic | Claude Sonnet 4, Claude 3.5 Sonnet/Haiku, Claude 3 Opus | Cloud |
| Ollama | Llama, Mistral, CodeLlama, etc. | Local |

## Screenshots

<p align="center">
  <img src="assests/desktop.png" alt="Desktop" width="800"><br>
  <em>Desktop</em>
</p>

<p align="center">
  <img src="assests/mobile.png" alt="Mobile" width="300"><br>
  <em>Mobile</em>
</p>

## Installation

### Linux

Download from releases:

- **AppImage** — Portable, just run it
- **DEB** — `sudo dpkg -i docan-*.deb`

### From Source

**Requirements:**
- Flutter SDK 3.10.3+
- Linux: `sudo apt install libsecret-1-dev libjsoncpp-dev`
- macOS: Xcode 15+
- Windows: Visual Studio 2022 with C++ workload

```bash
git clone https://gitlab.com/openlyst/docan.git
cd docan
flutter pub get
flutter run
```

## Building

```bash
# Debug
flutter run

# Release build
flutter build <platform>
# platform: apk, ios, macos, windows, linux, web
```

### Linux Packages

```bash
dart pub global activate flutter_distributor

# AppImage
flutter_distributor package --platform linux --targets appimage

# DEB
flutter_distributor package --platform linux --targets deb
```

## Setup

### API Keys

Go to Settings and add your keys:

- **Gemini** — [Google AI Studio](https://aistudio.google.com/apikey)
- **OpenAI** — [OpenAI Platform](https://platform.openai.com/api-keys)
- **Claude** — [Anthropic Console](https://console.anthropic.com/)
- **Ollama** — Runs locally at `http://localhost:11434`

### Ollama

```bash
curl -fsSL https://ollama.ai/install.sh | sh
ollama pull llama3.2
```

## Project Structure

```
lib/
├── main.dart
├── models/
│   ├── ai_provider.dart
│   ├── chat_message.dart
│   └── conversation.dart
├── services/
│   ├── ai_service.dart
│   ├── chat_service.dart
│   ├── gemini_service.dart
│   ├── openai_service.dart
│   ├── claude_service.dart
│   ├── ollama_service.dart
│   └── storage_service.dart
├── screens/
│   ├── mobile_chat_screen.dart
│   └── desktop_chat_screen.dart
├── components/
│   ├── liquid_glass_container.dart
│   ├── chat_bubble.dart
│   ├── chat_input.dart
│   ├── conversation_list.dart
│   ├── model_selector.dart
│   └── settings_form.dart
└── theme/
    └── liquid_glass_theme.dart
```

## Contributing

1. Fork the repo
2. Create a branch (`git checkout -b feature/your-feature`)
3. Commit changes
4. Push and open a PR

## License

GPL-3.0 — see [LICENSE](LICENSE)