#!/bin/bash
set -e

WHISPER_DIR="$HOME/.local/share/whisper.cpp"
SOUND_DIR="$HOME/.local/share/speak-mcp"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Voice for Claude Code ==="
echo ""
echo "This script will:"
echo ""

# Check what needs installing
if ! command -v rec &>/dev/null; then
  echo "  1. Install sox via Homebrew (for audio recording)"
else
  echo "  1. sox — already installed"
fi

if [ -f "$WHISPER_DIR/whisper-cli" ] && [ -f "$WHISPER_DIR/ggml-base.en.bin" ]; then
  echo "  2. whisper.cpp — already installed"
else
  echo "  2. Clone, build, and install whisper.cpp + base.en model"
fi

if brew list --cask hammerspoon &>/dev/null 2>&1; then
  echo "  3. Hammerspoon — already installed"
else
  echo "  3. Install Hammerspoon (for global voice hotkey)"
fi

echo "  4. Configure Hammerspoon hotkey (Cmd+Shift+L)"
echo "  5. Generate custom sound effects"
echo "  6. Install MCP server (TTS) + /speak skill for Claude Code"
echo ""
read -rp "Continue? [Y/n] " answer
if [[ "$answer" =~ ^[Nn] ]]; then
  echo "Aborted."
  exit 0
fi
echo ""

# 1. Install sox
if ! command -v rec &>/dev/null; then
  echo "Installing sox..."
  brew install sox
else
  echo "sox already installed"
fi

# 2. Build whisper.cpp
if [ -f "$WHISPER_DIR/whisper-cli" ] && [ -f "$WHISPER_DIR/ggml-base.en.bin" ]; then
  echo "whisper.cpp already installed at $WHISPER_DIR"
else
  echo "Building whisper.cpp..."
  TMPBUILD="$(mktemp -d)"
  git clone https://github.com/ggerganov/whisper.cpp.git "$TMPBUILD/whisper.cpp"
  cd "$TMPBUILD/whisper.cpp"
  cmake -B build
  cmake --build build --config Release -j$(sysctl -n hw.ncpu)

  echo "Downloading base.en model..."
  bash models/download-ggml-model.sh base.en

  echo "Installing to $WHISPER_DIR..."
  mkdir -p "$WHISPER_DIR"
  cp build/bin/whisper-cli "$WHISPER_DIR/"
  cp build/src/libwhisper*.dylib "$WHISPER_DIR/"
  cp build/ggml/src/libggml*.dylib "$WHISPER_DIR/"
  cp build/ggml/src/ggml-metal/libggml-metal*.dylib "$WHISPER_DIR/" 2>/dev/null || true
  cp build/ggml/src/ggml-blas/libggml-blas*.dylib "$WHISPER_DIR/" 2>/dev/null || true
  cp models/ggml-base.en.bin "$WHISPER_DIR/"

  DYLD_LIBRARY_PATH="$WHISPER_DIR" "$WHISPER_DIR/whisper-cli" --help &>/dev/null
  echo "whisper.cpp installed successfully"

  rm -rf "$TMPBUILD"
fi

# 3. Install Hammerspoon
if brew list --cask hammerspoon &>/dev/null 2>&1; then
  echo "Hammerspoon already installed"
else
  echo "Installing Hammerspoon..."
  brew install --cask hammerspoon
fi

# 4. Configure Hammerspoon hotkey
echo "Configuring Hammerspoon..."
mkdir -p "$HOME/.hammerspoon"
if [ -f "$HOME/.hammerspoon/init.lua" ]; then
  if ! diff -q "$SCRIPT_DIR/hammerspoon.lua" "$HOME/.hammerspoon/init.lua" &>/dev/null; then
    echo "  WARNING: ~/.hammerspoon/init.lua already exists and differs."
    read -rp "  Overwrite it? [y/N] " hs_answer
    if [[ ! "$hs_answer" =~ ^[Yy] ]]; then
      echo "  Skipped — you can manually merge $SCRIPT_DIR/hammerspoon.lua"
    else
      cp "$SCRIPT_DIR/hammerspoon.lua" "$HOME/.hammerspoon/init.lua"
      echo "  Hammerspoon config replaced"
    fi
  else
    echo "  Hammerspoon config already up to date"
  fi
else
  cp "$SCRIPT_DIR/hammerspoon.lua" "$HOME/.hammerspoon/init.lua"
  echo "Hammerspoon config installed"
fi

# 5. Generate sound effects
echo "Generating sound effects..."
mkdir -p "$SOUND_DIR"
sox -n "$SOUND_DIR/start.wav" synth 0.15 sine 600:900 gain -10
sox -n "$SOUND_DIR/done.wav" synth 0.15 sine 900:600 gain -10
echo "Sound effects created"

# 6. Install MCP server + skill
echo "Installing MCP server dependencies..."
cd "$SCRIPT_DIR"
npm install --registry https://registry.npmjs.org/

echo "Installing /speak skill..."
mkdir -p "$HOME/.claude/skills/speak"
cp "$SCRIPT_DIR/skill.md" "$HOME/.claude/skills/speak/SKILL.md"

if command -v claude &>/dev/null; then
  echo "Registering voice MCP server with Claude Code..."
  claude mcp add --scope user --transport stdio speak -- node "$SCRIPT_DIR/index.js" 2>/dev/null || echo "  (may already exist)"
fi

# Start Hammerspoon
open -a Hammerspoon 2>/dev/null || true

echo ""
echo "=== Setup complete ==="
echo ""
echo "IMPORTANT: Grant Hammerspoon Accessibility access:"
echo "  System Settings → Privacy & Security → Accessibility → toggle Hammerspoon ON"
echo ""
echo "Usage:"
echo "  Cmd+Shift+L  — start recording (rising tone)"
echo "  Cmd+Shift+L  — stop & transcribe (falling tone, text is pasted + submitted)"
echo "  /speak       — enable Claude's spoken responses (TTS)"
echo "  /speak off   — disable TTS"
