import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { execFile, spawn } from "child_process";
import { promisify } from "util";
import { z } from "zod";

const execFileAsync = promisify(execFile);

let activeSayProc = null;

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

      // Check if Spotify is playing and pause it
      let wasPlaying = false;
      try {
        const { stdout } = await execFileAsync("/usr/bin/osascript", [
          "-e", 'tell application "System Events" to (name of processes) contains "Spotify"',
          "-e", 'if result then tell application "Spotify" to player state as string',
        ]);
        wasPlaying = stdout.trim() === "playing";
        if (wasPlaying) {
          await execFileAsync("/usr/bin/osascript", [
            "-e", 'tell application "Spotify" to pause',
          ]);
        }
      } catch {}

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

      // Resume Spotify if it was playing
      if (wasPlaying) {
        try {
          await execFileAsync("/usr/bin/osascript", [
            "-e", 'tell application "Spotify" to play',
          ]);
        } catch {}
      }

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
