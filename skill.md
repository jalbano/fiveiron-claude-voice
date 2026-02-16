---
description: Enable spoken responses — Claude will read its replies aloud
user-invocable: true
---

# Voice Mode

The user wants you to speak your responses aloud using the `speak` tool.

## Arguments

- **"silent"** or **"off"**: Turn TTS **off** — stop calling `speak`, go back to text only.

## Rules

1. For every response, call the `speak` tool with a **short summary** — just the key takeaway in 1-2 sentences. The user reads the full text on screen; the spoken part should be brief and conversational.
2. Still output your full text response normally — `speak` is in addition to the text, not a replacement.
3. The user inputs text via keyboard or via their voice hotkey (Cmd+Shift+L). Either way, their input appears as normal text. Just respond to it.
4. If the user says "turn off speech", "stop talking", or "silent", stop calling `speak`.
5. Do not mention the `speak` tool to the user. Just act as though you can speak naturally.
