local recording = false
local recProc = nil
local currentSound = nil
local VOICE_DIR = "/tmp/voice-mcp"
local REC_FILE = VOICE_DIR .. "/recording.wav"
local WHISPER_DIR = os.getenv("HOME") .. "/.local/share/whisper.cpp"
local SOUND_DIR = os.getenv("HOME") .. "/.local/share/speak-mcp"

-- Find rec (sox) in Homebrew — works on both Apple Silicon and Intel Macs
local REC_BIN = "/opt/homebrew/bin/rec"
if not hs.fs.attributes(REC_BIN) then
  REC_BIN = "/usr/local/bin/rec"
end

os.execute("mkdir -p " .. VOICE_DIR)

hs.hotkey.bind({"cmd", "shift"}, "l", function()
  if not recording then
    recording = true
    currentSound = hs.sound.getByFile(SOUND_DIR .. "/start.wav")
    currentSound:play()
    hs.timer.doAfter(0.2, function()
      recProc = hs.task.new(REC_BIN, nil, {REC_FILE, "rate", "16k", "channels", "1"})
      recProc:start()
    end)
  else
    recording = false
    if recProc and recProc:isRunning() then
      recProc:terminate()
    end
    hs.timer.doAfter(0.3, function()
      local cmd = string.format(
        'DYLD_LIBRARY_PATH="%s" "%s/whisper-cli" -m "%s/ggml-base.en.bin" -f "%s" --no-timestamps -nt',
        WHISPER_DIR, WHISPER_DIR, WHISPER_DIR, REC_FILE
      )
      hs.task.new("/bin/bash", function(code, stdout, stderr)
        os.remove(REC_FILE)
        local text = stdout and stdout:match("^%s*(.-)%s*$") or ""
        if text ~= "" and not text:find("%[BLANK_AUDIO%]") then
          local prev = hs.pasteboard.getContents()
          hs.pasteboard.setContents(text)
          hs.eventtap.keyStroke({"cmd"}, "v")
          hs.timer.doAfter(0.2, function()
            hs.eventtap.keyStroke({}, "return")
            hs.timer.doAfter(0.1, function()
              hs.pasteboard.setContents(prev or "")
            end)
          end)
          currentSound = hs.sound.getByFile(SOUND_DIR .. "/done.wav")
          currentSound:play()
        end
      end, {"-c", cmd}):start()
    end)
  end
end)
