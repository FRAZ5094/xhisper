# macOS local whisper.cpp equivalent

xhisper is currently a Linux app. The local transcription backend is portable, but the cursor integration is not.

The Linux implementation depends on:

- PipeWire `pw-record` for recording
- `/dev/uinput` for typing and paste key chords
- `wl-copy` / `wl-paste` on Wayland
- Linux window manager keybinds such as Hyprland `bindr`

macOS needs equivalent pieces:

- `whisper.cpp` for transcription
- `ffmpeg` or `sox` for recording
- `pbcopy` for clipboard
- Hammerspoon, Raycast, Shortcuts, Automator, or Karabiner for the hotkey and paste action

## Install whisper.cpp

With Homebrew:

```sh
brew install cmake ffmpeg git
mkdir -p ~/.local/opt ~/.local/share/xhisper/models
git clone https://github.com/ggml-org/whisper.cpp ~/.local/opt/whisper.cpp
cmake -S ~/.local/opt/whisper.cpp -B ~/.local/opt/whisper.cpp/build -DCMAKE_BUILD_TYPE=Release
cmake --build ~/.local/opt/whisper.cpp/build -j"$(sysctl -n hw.ncpu)" --config Release
~/.local/opt/whisper.cpp/models/download-ggml-model.sh base.en
ln -sf ~/.local/opt/whisper.cpp/models/ggml-base.en.bin ~/.local/share/xhisper/models/ggml-base.en.bin
```

On Apple Silicon, `whisper.cpp` can use Metal and is usually fast with `base.en` or `small.en`.

## Minimal macOS dictation script

This is not the Linux xhisper app, but it is the same local workflow: record, transcribe, copy, paste.

Create `~/bin/xhisper-macos`:

```sh
#!/bin/zsh
set -e

recording="/tmp/xhisper-macos.wav"
state="/tmp/xhisper-macos.pid"
whisper="$HOME/.local/opt/whisper.cpp/build/bin/whisper-cli"
model="$HOME/.local/share/xhisper/models/ggml-base.en.bin"

if [ -f "$state" ] && kill -0 "$(cat "$state")" 2>/dev/null; then
  kill "$(cat "$state")"
  rm -f "$state"
  sleep 0.3
  text="$("$whisper" -m "$model" -f "$recording" -nt -np -l en | sed 's/^ //;s/[[:space:]]*$//')"
  printf '%s' "$text" | pbcopy
  osascript -e 'tell application "System Events" to keystroke "v" using command down'
else
  ffmpeg -y -f avfoundation -i ":0" -ar 16000 -ac 1 -c:a pcm_s16le "$recording" >/tmp/xhisper-macos-record.log 2>&1 &
  echo $! > "$state"
fi
```

Make it executable:

```sh
chmod +x ~/bin/xhisper-macos
```

You may need to change the `avfoundation` input device. List devices:

```sh
ffmpeg -f avfoundation -list_devices true -i ""
```

Then update this part of the script:

```sh
-i ":0"
```

## Hotkey options

Use one of these to bind `~/bin/xhisper-macos`:

- Hammerspoon: `hs.hotkey.bind(...)`
- Raycast: script command
- macOS Shortcuts: run shell script
- Automator Quick Action
- Karabiner: advanced trigger, usually with a wrapper script

## Notes

This macOS setup pastes the full transcription through the clipboard. That is much faster than typing each character.

It does not yet mirror every Linux xhisper feature, such as per-window terminal paste detection or uinput-style text injection.
