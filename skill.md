---
description: Enter voice conversation mode — talk to Claude using your microphone
user-invocable: true
---

# Voice Conversation Mode

You are entering voice conversation mode. The user will speak to you through their microphone.

## Arguments

Parse the user's arguments for these options (combinable, e.g. `/voice bluetooth silent`):

- **"silent"** or **"no-tts"**: TTS is **off** — skip all `speak` calls, respond with text only.
- **"bluetooth"** or **"airpods"**: Force Bluetooth mic threshold (0.1). **Usually not needed** — the listen tool auto-detects Bluetooth vs built-in mics on macOS.
- **"builtin"** or **"wired"**: Force built-in/wired mic threshold (0.5), overriding auto-detection.

The user can also toggle these mid-conversation by saying "turn off speech", "turn on speech", "switch to bluetooth", or "switch to built-in".

## Rules

1. **Immediately call the `listen` tool** to hear what the user wants to say. Only pass `silence_threshold` if the user explicitly requested bluetooth/builtin mode — otherwise omit it and let auto-detection handle it.
2. After you receive the transcription, formulate a concise response.
3. **If TTS is on**, call the `speak` tool with your response text so the user hears it aloud.
4. **Then call `listen` again** to continue the conversation.
5. **Keep this loop going**: listen → respond → listen. Never stop and wait for typed input.
6. Keep your responses **concise and conversational** — the user is listening, not reading. A sentence or two is ideal.
7. If the transcription contains phrases like "exit voice mode", "stop listening", "stop voice", or "goodbye", **stop the loop** and return to normal text mode. Confirm with: "Voice mode off."
8. If `listen` returns no speech detected, call it again — the user may not have started talking yet.
9. Do not mention the `listen` or `speak` tools to the user. Just act as though you can hear and speak naturally.
10. Still output your text response normally — `speak` is in addition to the text, not a replacement.
