# Linux local whisper.cpp setup

This setup runs transcription fully locally with `whisper.cpp`. No Groq API key is required.

## Arch / Hyprland quick setup

Install dependencies:

```sh
sudo pacman -S --needed pipewire wireplumber jq curl ffmpeg gcc make cmake git wl-clipboard bc
```

Build and install `whisper.cpp`:

```sh
mkdir -p ~/.local/opt ~/.local/share/xhisper/models
git clone https://github.com/ggml-org/whisper.cpp ~/.local/opt/whisper.cpp
cmake -S ~/.local/opt/whisper.cpp -B ~/.local/opt/whisper.cpp/build -DCMAKE_BUILD_TYPE=Release
cmake --build ~/.local/opt/whisper.cpp/build -j"$(nproc)" --config Release
~/.local/opt/whisper.cpp/models/download-ggml-model.sh base.en
ln -sf ~/.local/opt/whisper.cpp/models/ggml-base.en.bin ~/.local/share/xhisper/models/ggml-base.en.bin
```

Build and install xhisper:

```sh
git clone https://github.com/YOUR_USER/xhisper.git
cd xhisper
make
make install PREFIX="$HOME/.local"
mkdir -p ~/.config/xhisper
cp default_xhisperrc ~/.config/xhisper/xhisperrc
```

Make sure `~/.local/bin` is on your `PATH`.

## uinput access

xhisper types and pastes through `/dev/uinput`.

On many systems:

```sh
sudo usermod -aG input "$USER"
```

Then log out and back in, or reboot.

If `/dev/uinput` exists but cannot be opened, make sure the running kernel and installed modules match:

```sh
uname -r
ls /lib/modules
```

On Arch, this commonly means rebooting after a kernel upgrade.

## Hyprland keybind

Use a release bind and an absolute path. This prevents injected status text from being interpreted as more `SUPER+key` shortcuts.

```ini
bindr = $mainMod, d, exec, /home/YOUR_USER/.local/bin/xhisper
```

Then reload Hyprland:

```sh
hyprctl reload
```

## Usage

Press the keybind once to start recording. Press it again to stop, transcribe, and paste at the cursor.

From a terminal:

```sh
xhisper
xhisper
```

View logs:

```sh
xhisper --log
```

## Local model choices

`base.en` is a good default for English dictation. It is small and fast enough for laptops.

For faster but less accurate dictation, use `tiny.en`. For better accuracy, try `small.en`.

Download another model:

```sh
~/.local/opt/whisper.cpp/models/download-ggml-model.sh small.en
ln -sf ~/.local/opt/whisper.cpp/models/ggml-small.en.bin ~/.local/share/xhisper/models/ggml-base.en.bin
```

Or update `~/.config/xhisper/xhisperrc`:

```ini
whisper-cpp-model : ~/.local/opt/whisper.cpp/models/ggml-small.en.bin
```

## Fast paste mode

Long transcriptions are pasted as a single clipboard operation by default:

```ini
output-mode : paste
paste-chord : auto
```

`paste-chord : auto` uses `Ctrl+Shift+V` for common terminal emulators and `Ctrl+V` elsewhere.

If detection is wrong for an app, set:

```ini
paste-chord : ctrl-v
```

or:

```ini
paste-chord : ctrl-shift-v
```

The original character-by-character behavior is still available:

```ini
output-mode : type
```
