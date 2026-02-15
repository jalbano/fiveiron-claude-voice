import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { execFile, spawn } from "child_process";
import { promisify } from "util";
import { existsSync, mkdirSync } from "fs";
import { tmpdir } from "os";
import { join } from "path";
import { z } from "zod";
import { homedir } from "os";

const execFileAsync = promisify(execFile);

const WHISPER_DIR = join(homedir(), ".local", "share", "whisper.cpp");
const WHISPER_BIN =
  process.env.WHISPER_BIN || join(WHISPER_DIR, "whisper-cli");
const WHISPER_MODEL =
  process.env.WHISPER_MODEL || join(WHISPER_DIR, "ggml-base.en.bin");
const REC_BIN = process.env.REC_BIN || "/opt/homebrew/bin/rec";
const TMP_DIR = join(tmpdir(), "voice-mcp");
let activeSayProc = null;

if (!existsSync(TMP_DIR)) mkdirSync(TMP_DIR, { recursive: true });

function killActiveSay() {
  if (activeSayProc) {
    try { activeSayProc.kill("SIGTERM"); } catch {}
    activeSayProc = null;
  }
}

const server = new McpServer({
  name: "voice",
  version: "1.0.0",
});

function recordAudio(outPath, maxSeconds = 30) {
  return new Promise((resolve, reject) => {
    // sox's rec command with silence detection:
    //   silence 1 0.1 3%  → skip leading silence (start on voice)
    //   1 2.0 3%          → stop after 2s of silence
    const args = [
      outPath,
      "rate", "16k",       // whisper wants 16kHz
      "channels", "1",     // mono
      "silence",
        "1", "0.01", "1%",  // wait for speech (10ms detection, very low threshold)
        "1", "2.0", "3%",   // stop after 2s of silence
    ];

    const proc = spawn(REC_BIN, args, {
      stdio: ["ignore", "pipe", "pipe"],
    });

    const timeout = setTimeout(() => {
      proc.kill("SIGTERM");
    }, maxSeconds * 1000);

    proc.on("close", (code) => {
      clearTimeout(timeout);
      if (existsSync(outPath)) {
        resolve(outPath);
      } else {
        reject(new Error(`Recording failed (exit ${code})`));
      }
    });

    proc.on("error", (err) => {
      clearTimeout(timeout);
      reject(err);
    });
  });
}

async function transcribe(audioPath) {
  const { stdout } = await execFileAsync(WHISPER_BIN, [
    "-m", WHISPER_MODEL,
    "-f", audioPath,
    "--no-timestamps",
    "-nt",
  ], {
    timeout: 30_000,
    env: { ...process.env, DYLD_LIBRARY_PATH: WHISPER_DIR },
  });

  return stdout.trim();
}

server.tool(
  "listen",
  "Record audio from the microphone and transcribe it. Use this to hear what the user is saying via voice. Waits for the user to speak, then stops automatically after 2 seconds of silence.",
  {
    max_seconds: z
      .number()
      .optional()
      .default(30)
      .describe("Maximum recording time in seconds (default 30)"),
  },
  async ({ max_seconds }) => {
    killActiveSay();
    const audioPath = join(TMP_DIR, `recording-${Date.now()}.wav`);

    try {
      await recordAudio(audioPath, max_seconds);
      const text = await transcribe(audioPath);

      // Clean up the temp file
      try {
        const { unlink } = await import("fs/promises");
        await unlink(audioPath);
      } catch {}

      if (!text) {
        return {
          content: [
            {
              type: "text",
              text: "[No speech detected. The user may not have spoken, or the audio was too quiet.]",
            },
          ],
        };
      }

      return {
        content: [{ type: "text", text }],
      };
    } catch (err) {
      return {
        content: [
          {
            type: "text",
            text: `[Recording/transcription error: ${err.message}]`,
          },
        ],
        isError: true,
      };
    }
  }
);

server.tool(
  "speak",
  "Speak text aloud using text-to-speech. Use this to read your response to the user in voice mode.",
  {
    text: z.string().describe("The text to speak aloud"),
    voice: z
      .string()
      .optional()
      .default("Karen (Premium)")
      .describe("macOS voice name (e.g. Samantha, Alex, Daniel, Karen)"),
    rate: z
      .number()
      .optional()
      .default(200)
      .describe("Speech rate in words per minute (default 200)"),
  },
  async ({ text, voice, rate }) => {
    try {
      killActiveSay();
      const proc = spawn("/usr/bin/say", [
        "-v", voice,
        "-r", String(rate),
        text,
      ], { stdio: "ignore" });

      activeSayProc = proc;

      await new Promise((resolve, reject) => {
        proc.on("close", () => { activeSayProc = null; resolve(); });
        proc.on("error", (err) => { activeSayProc = null; reject(err); });
      });

      return {
        content: [{ type: "text", text: "[Spoken successfully]" }],
      };
    } catch (err) {
      return {
        content: [
          { type: "text", text: `[TTS error: ${err.message}]` },
        ],
        isError: true,
      };
    }
  }
);

server.tool(
  "stop_speaking",
  "Stop any currently playing text-to-speech audio immediately.",
  {},
  async () => {
    killActiveSay();
    return {
      content: [{ type: "text", text: "[Speech stopped]" }],
    };
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
