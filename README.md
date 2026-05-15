<div align="center">
  <h1>xhisper <i>/ˈzɪspər/</i></h1>
  <img src="demo.gif" alt="xhisper demo" width="300">
  <br><br>
</div>

Dictation at cursor for Linux, with optional local transcription through [`whisper.cpp`](https://github.com/ggml-org/whisper.cpp).

This fork defaults to local `whisper.cpp` transcription, so a Groq API key is not required. Groq is still available by setting `transcription-backend : groq`.

## Linux

### Dependencies

Arch Linux / Manjaro:

```sh
sudo pacman -S --needed pipewire wireplumber jq curl ffmpeg gcc make cmake git bc wl-clipboard
```

Debian / Ubuntu / Linux Mint:

```sh
sudo apt update
sudo apt install pipewire pipewire-audio-client-libraries wireplumber jq curl ffmpeg gcc make cmake git bc wl-clipboard
```

### Install whisper.cpp

```sh
mkdir -p ~/.local/opt ~/.local/share/xhisper/models
git clone https://github.com/ggml-org/whisper.cpp ~/.local/opt/whisper.cpp
cmake -S ~/.local/opt/whisper.cpp -B ~/.local/opt/whisper.cpp/build -DCMAKE_BUILD_TYPE=Release
cmake --build ~/.local/opt/whisper.cpp/build -j"$(nproc)" --config Release
~/.local/opt/whisper.cpp/models/download-ggml-model.sh base.en
ln -sf ~/.local/opt/whisper.cpp/models/ggml-base.en.bin ~/.local/share/xhisper/models/ggml-base.en.bin
```

### Install xhisper

```sh
git clone --depth 1 https://github.com/FRAZ5094/xhisper.git
cd xhisper
make
make install PREFIX="$HOME/.local"
mkdir -p ~/.config/xhisper
cp default_xhisperrc ~/.config/xhisper/xhisperrc
```

Make sure `~/.local/bin` is on your `PATH`.

### uinput access

xhisper uses `/dev/uinput` to type and paste at the cursor.

```sh
sudo usermod -aG input "$USER"
```

Log out and back in, or reboot. Then check:

```sh
groups
```

You should see `input`.

If `/dev/uinput` exists but xhisper still cannot open it, make sure the running kernel and installed modules match:

```sh
uname -r
ls /lib/modules
```

On rolling distributions, this often means rebooting after a kernel update.

### Hyprland keybind

Use `bindr` so the command runs after the Super key is released:

```ini
bindr = $mainMod, d, exec, /home/YOUR_USER/.local/bin/xhisper
```

Reload Hyprland:

```sh
hyprctl reload
```

Other Linux bind examples:

```ini
# i3 / sway
bindsym $mod+d exec xhisper
```

```text
# sxhkd
super + d
    xhisper
```

## macOS

The Linux binary does not run directly on macOS because it uses PipeWire and `/dev/uinput`. The same local dictation workflow can be set up with `whisper.cpp`, `ffmpeg`, `pbcopy`, and a hotkey tool.

### Dependencies

```sh
brew install cmake ffmpeg git hammerspoon
```

Hammerspoon is the recommended hotkey runner for this setup. It is a developer-friendly macOS automation tool with global hotkeys and shell command support.

### Install whisper.cpp

```sh
mkdir -p ~/.local/opt ~/.local/share/xhisper/models
git clone https://github.com/ggml-org/whisper.cpp ~/.local/opt/whisper.cpp
cmake -S ~/.local/opt/whisper.cpp -B ~/.local/opt/whisper.cpp/build -DCMAKE_BUILD_TYPE=Release
cmake --build ~/.local/opt/whisper.cpp/build -j"$(sysctl -n hw.ncpu)" --config Release
~/.local/opt/whisper.cpp/models/download-ggml-model.sh base.en
ln -sf ~/.local/opt/whisper.cpp/models/ggml-base.en.bin ~/.local/share/xhisper/models/ggml-base.en.bin
```

### Minimal macOS command

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

List macOS audio devices if `:0` is not your microphone:

```sh
ffmpeg -f avfoundation -list_devices true -i ""
```

Then update `-i ":0"` in the script.

### Hammerspoon global hotkey

Start Hammerspoon once, then grant Accessibility permissions when macOS asks. If it does not ask automatically, open System Settings and enable Hammerspoon under Privacy & Security > Accessibility.

Create or edit `~/.hammerspoon/init.lua`:

```lua
local xhisper = os.getenv("HOME") .. "/bin/xhisper-macos"

hs.hotkey.bind({"cmd", "alt"}, "D", function()
  hs.execute(xhisper .. " >/tmp/xhisper-macos-hotkey.log 2>&1 &")
end)
```

Reload Hammerspoon from its menu bar icon, or run:

```sh
open -a Hammerspoon
```

Now press `Command+Option+D` anywhere in macOS:

- first press starts recording
- second press stops recording, transcribes, copies, and pastes

If `Command+Option+D` conflicts with another app, change the modifiers or key in `hs.hotkey.bind`.

## Windows

The Linux binary does not run directly on Windows because it uses PipeWire and `/dev/uinput`. The same workflow can be built with `whisper.cpp`, `ffmpeg`, the Windows clipboard, and AutoHotkey.

### Dependencies

Required:

- Git
- CMake
- C++ compiler, usually Visual Studio Build Tools
- FFmpeg
- AutoHotkey v2

Without admin rights, use portable/prebuilt versions where possible. `whisper.cpp` itself can run from a user directory, but building it requires a C++ toolchain. If a compiler and CMake are already installed, admin rights are not required.

### Install whisper.cpp

```powershell
git clone https://github.com/ggml-org/whisper.cpp "$env:USERPROFILE\.local\opt\whisper.cpp"
cmake -S "$env:USERPROFILE\.local\opt\whisper.cpp" -B "$env:USERPROFILE\.local\opt\whisper.cpp\build" -DCMAKE_BUILD_TYPE=Release
cmake --build "$env:USERPROFILE\.local\opt\whisper.cpp\build" --config Release
```

Download a model:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.local\share\xhisper\models"
Invoke-WebRequest `
  -Uri "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin" `
  -OutFile "$env:USERPROFILE\.local\share\xhisper\models\ggml-base.en.bin"
```

### AutoHotkey sketch

Create an AutoHotkey v2 script and adjust the microphone name and `whisper-cli.exe` path if needed:

```autohotkey
#Requires AutoHotkey v2.0

recording := A_Temp "\xhisper-windows.wav"
pidFile := A_Temp "\xhisper-windows.pid"
whisper := A_UserProfile "\.local\opt\whisper.cpp\build\bin\Release\whisper-cli.exe"
model := A_UserProfile "\.local\share\xhisper\models\ggml-base.en.bin"

#d:: {
    global recording, pidFile, whisper, model

    if FileExist(pidFile) {
        pid := Trim(FileRead(pidFile))
        ProcessClose(pid)
        FileDelete(pidFile)
        Sleep(300)

        cmd := Format('"{1}" -m "{2}" -f "{3}" -nt -np -l en', whisper, model, recording)
        shell := ComObject("WScript.Shell")
        exec := shell.Exec(cmd)
        text := Trim(exec.StdOut.ReadAll())
        A_Clipboard := text
        Send("^v")
    } else {
        cmd := Format('ffmpeg -y -f dshow -i audio="YOUR MICROPHONE NAME" -ar 16000 -ac 1 -c:a pcm_s16le "{1}"', recording)
        pid := Run(cmd, , "Hide")
        FileAppend(pid, pidFile)
    }
}
```

List DirectShow audio devices:

```powershell
ffmpeg -list_devices true -f dshow -i dummy
```

Replace `YOUR MICROPHONE NAME` with the exact microphone name.

## Usage

Run the command twice or use your keybind:

- First run: starts recording
- Second run: stops, transcribes, and pastes at the cursor

Linux:

```sh
xhisper
xhisper
```

View logs:

```sh
xhisper --log
```

## Configuration

Linux configuration is read from `~/.config/xhisper/xhisperrc`:

```sh
mkdir -p ~/.config/xhisper
cp default_xhisperrc ~/.config/xhisper/xhisperrc
```

Useful local transcription settings:

```ini
transcription-backend : local
whisper-cpp-binary    : ~/.local/opt/whisper.cpp/build/bin/whisper-cli
whisper-cpp-model     : ~/.local/share/xhisper/models/ggml-base.en.bin
whisper-cpp-language  : en
output-mode           : paste
paste-chord           : auto
```

Use `output-mode : paste` for fast long-form dictation. Use `output-mode : type` to restore character-by-character typing.

Optional Groq mode:

```ini
transcription-backend : groq
```

Then add your Groq key to `~/.env`:

```sh
GROQ_API_KEY=<your_API_key>
```

## Troubleshooting

Terminal applications: with `paste-chord : auto`, common terminal emulators use Ctrl+Shift+V and other apps use Ctrl+V. If detection is wrong, set `paste-chord : ctrl-v` or `paste-chord : ctrl-shift-v`.

Non-QWERTY layouts: set up an input switch key to QWERTY, then bind to:

```sh
xhisper --rightalt
```

Available input switch keys: `--leftalt`, `--rightalt`, `--leftctrl`, `--rightctrl`, `--leftshift`, `--rightshift`, `--super`.

---

<p align="center">
  <em>Low complexity dictation</em>
</p>
