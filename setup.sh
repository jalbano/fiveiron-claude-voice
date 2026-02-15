#!/bin/bash
set -e

WHISPER_DIR="$HOME/.local/share/whisper.cpp"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Voice MCP Setup ==="
echo ""
echo "This script will:"
echo ""
if ! command -v rec &>/dev/null; then
  echo "  1. Install sox via Homebrew (for audio recording)"
else
  echo "  1. sox — already installed, skipping"
fi
if [ -f "$WHISPER_DIR/whisper-cli" ] && [ -f "$WHISPER_DIR/ggml-base.en.bin" ]; then
  echo "  2. whisper.cpp — already installed, skipping"
else
  echo "  2. Clone, build, and install whisper.cpp + base.en model to $WHISPER_DIR"
fi
echo "  3. Run npm install for the MCP server"
echo "  4. Install the /voice skill to ~/.claude/skills/voice/"
echo "  5. Register the voice MCP server with Claude Code"
echo ""
read -rp "Continue? [Y/n] " answer
if [[ "$answer" =~ ^[Nn] ]]; then
  echo "Aborted."
  exit 0
fi
echo ""

# 1. Install sox (for audio recording)
if ! command -v rec &>/dev/null; then
  echo "Installing sox..."
  brew install sox
else
  echo "sox already installed"
fi

# 2. Build whisper.cpp and install binary + model
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

  # Verify it works
  DYLD_LIBRARY_PATH="$WHISPER_DIR" "$WHISPER_DIR/whisper-cli" --help &>/dev/null
  echo "whisper.cpp installed successfully"

  rm -rf "$TMPBUILD"
fi

# 3. Install MCP server dependencies
echo "Installing MCP server dependencies..."
cd "$SCRIPT_DIR"
npm install --registry https://registry.npmjs.org/

# 4. Install /voice skill
echo "Installing /voice skill..."
mkdir -p "$HOME/.claude/skills/voice"
cp "$SCRIPT_DIR/skill.md" "$HOME/.claude/skills/voice/SKILL.md"
echo "Skill installed"

# 5. Register with Claude Code
if command -v claude &>/dev/null; then
  echo "Registering voice MCP server with Claude Code..."
  claude mcp add --scope user --transport stdio voice -- node "$SCRIPT_DIR/index.js" 2>/dev/null || echo "Could not auto-register (may already exist or running inside Claude Code). Add manually:"
  echo "  claude mcp add --scope user --transport stdio voice -- node $SCRIPT_DIR/index.js"
fi

echo ""
echo "=== Setup complete ==="
echo "Restart Claude Code and type /voice to start talking."
