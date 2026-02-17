# Voice for Claude Code

Talk to Claude Code with your voice and hear it talk back. macOS only.

**Voice input** — press **Cmd+Shift+L** to record, press again to transcribe and submit. Uses a global hotkey via [Hammerspoon](https://www.hammerspoon.org/) so it works from any app, with local transcription via [whisper.cpp](https://github.com/ggerganov/whisper.cpp) (nothing leaves your machine).

**Voice output** — type `/speak` in Claude Code to have it read responses aloud using macOS TTS. Type `/speak off` to stop.

## Requirements

- macOS (Apple Silicon or Intel)
- [Homebrew](https://brew.sh/)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI (`claude`)
- Xcode Command Line Tools (`xcode-select --install`)

## Install

```bash
git clone <this-repo>
cd voice
./setup.sh
```

The setup script will:

1. Install **sox** via Homebrew (for audio recording)
2. Clone, build, and install **whisper.cpp** with the `base.en` model to `~/.local/share/whisper.cpp/`
3. Install **Hammerspoon** via Homebrew (for the global hotkey)
4. Configure Hammerspoon with the voice hotkey (`~/.hammerspoon/init.lua`)
5. Generate notification sounds
6. Install the MCP server and `/speak` skill into Claude Code

After setup, you must grant Hammerspoon **Accessibility** access:

> System Settings → Privacy & Security → Accessibility → toggle Hammerspoon ON

## Usage

| Action | How |
|---|---|
| Start recording | **Cmd+Shift+L** (rising tone) |
| Stop & transcribe | **Cmd+Shift+L** again (falling tone, text is pasted and submitted) |
| Enable spoken responses | Type `/speak` in Claude Code |
| Disable spoken responses | Type `/speak off` or say "stop talking" |

Voice input and voice output are independent — use either or both.

## How it works

### Voice input (Hammerspoon)

A Hammerspoon hotkey toggles recording via `rec` (sox). When you stop, the audio is transcribed locally with whisper.cpp, pasted into the active window, and submitted. The entire flow is local — no audio leaves your machine.

### Voice output (MCP server)

A lightweight MCP server exposes a `speak` tool that calls macOS `say` for text-to-speech. The `/speak` skill tells Claude to call this tool with a short summary of each response. If Spotify is playing, it auto-pauses during speech and resumes after.

## Files

| File | Purpose |
|---|---|
| `setup.sh` | One-command installer |
| `hammerspoon.lua` | Hammerspoon config for voice input hotkey |
| `index.js` | MCP server for TTS output |
| `skill.md` | `/speak` skill definition |
| `package.json` | Node.js dependencies |
| `make-zip.sh` | Bundles project into a zip for distribution |

## Uninstall

```bash
# Remove MCP server
claude mcp remove speak

# Remove skill
rm -rf ~/.claude/skills/speak

# Remove whisper.cpp
rm -rf ~/.local/share/whisper.cpp

# Remove sounds
rm -rf ~/.local/share/speak-mcp

# Remove Hammerspoon config (or edit ~/.hammerspoon/init.lua)
brew uninstall --cask hammerspoon
rm -rf ~/.hammerspoon
```
