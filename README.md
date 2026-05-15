<div align="center">
  <h1>xhisper <i>/ˈzɪspər/</i></h1>
  <img src="demo.gif" alt="xhisper demo" width="300">
  <br><br>
</div>

Dictation at cursor for Linux.

This fork can transcribe locally with [`whisper.cpp`](https://github.com/ggml-org/whisper.cpp), so a Groq API key is optional.

## Installation

### Dependencies

<details>
<summary>Arch Linux / Manjaro</summary>
<pre><code>sudo pacman -S pipewire jq curl ffmpeg gcc make cmake git bc</code></pre>
</details>

<details>
<summary>Debian / Ubuntu / Linux Mint</summary>
<pre><code>sudo apt update
sudo apt install pipewire jq curl ffmpeg gcc make cmake git bc</code></pre>
</details>

<details>
<summary>Fedora / RHEL / AlmaLinux / Rocky</summary>
<pre><code>sudo dnf install -y pipewire pipewire-utils jq curl ffmpeg gcc make cmake git bc</code></pre>
</details>

<details>
<summary>OpenSUSE (Leap / Tumbleweed)</summary>
<pre><code>sudo zypper refresh
sudo zypper install pipewire jq curl ffmpeg gcc make cmake git bc</code></pre>
</details>

<details>
<summary>Void Linux</summary>
<pre><code>sudo xbps-install -S
sudo xbps-install pipewire jq curl ffmpeg gcc make cmake git bc</code></pre>
</details>

**Note:** `wl-clipboard` (Wayland) or `xclip` (X11) is required for clipboard paste output.

### Setup

1. **Add user to input group** to access `/dev/uinput`:
```sh
sudo usermod -aG input $USER
```
Then **log out and log back in** (restart is safer) for the group change to take effect.

Check by running:

```sh
groups
```

You should see `input` in the output.

2. **Local transcription with whisper.cpp**:
```sh
mkdir -p ~/.local/opt ~/.local/share/xhisper/models
git clone https://github.com/ggml-org/whisper.cpp ~/.local/opt/whisper.cpp
cmake -S ~/.local/opt/whisper.cpp -B ~/.local/opt/whisper.cpp/build -DCMAKE_BUILD_TYPE=Release
cmake --build ~/.local/opt/whisper.cpp/build -j"$(nproc)" --config Release
~/.local/opt/whisper.cpp/models/download-ggml-model.sh base.en
ln -sf ~/.local/opt/whisper.cpp/models/ggml-base.en.bin ~/.local/share/xhisper/models/ggml-base.en.bin
```

For detailed Linux setup notes, see [`docs/linux-local-whisper.md`](docs/linux-local-whisper.md).

3. **Optional Groq API key** from [console.groq.com](https://console.groq.com) if you set `transcription-backend : groq`:
```sh
GROQ_API_KEY=<your_API_key>
```

4. Clone the repository and install:
```sh
git clone --depth 1 https://github.com/imaginalnika/xhisper.git
cd xhisper && make
sudo make install
```

5. Bind `xhisper` binary to your favorite key:

<details>
<summary>keyd</summary>

```ini
[main]
capslock = layer(dictate)

[dictate:C]
d = macro(xhisper)
```
</details>

<details>
<summary>sxhkd</summary>

```
super + d
    xhisper
```
</details>

<details>
<summary>i3 / sway</summary>

```
bindsym $mod+d exec xhisper
```
</details>

<details>
<summary>Hyprland</summary>

```
bindr = $mainMod, d, exec, /home/YOUR_USER/.local/bin/xhisper
```
</details>

<details>
<summary>Gnome</summary>

```sh
# In your terminal:

name="xhisper"
binding="<CTRL><SHIFT>X"
action="/usr/local/bin/xhisper"

media_keys=org.gnome.settings-daemon.plugins.media-keys
custom_kbd=org.gnome.settings-daemon.plugins.media-keys.custom-keybinding
kbd_path=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/$name/
new_bindings=`gsettings get $media_keys custom-keybindings | sed -e"s>'\]>','$kbd_path']>"| sed -e"s>@as \[\]>['$kbd_path']>"`
gsettings set $media_keys custom-keybindings "$new_bindings"
gsettings set $custom_kbd:$kbd_path name "$name"
gsettings set $custom_kbd:$kbd_path binding "$binding"
gsettings set $custom_kbd:$kbd_path command "$action"
```
</details>

---

## Usage

Simply run `xhisper` twice (via your favorite keybinding):
- **First run**: Starts recording
- **Second run**: Stops and transcribes

The transcription will be pasted or typed at your cursor position.

**View logs:**
```sh
xhisper --log
```

**Non-QWERTY layouts:**

For non-QWERTY layouts (e.g. Dvorak, International), set up an input switch key to QWERTY (e.g. rightalt). Then instead of binding to `xhisper`, bind to:
```sh
xhisper --<your-input-switch-key>
```

**Available input switch keys:** `--leftalt`, `--rightalt`, `--leftctrl`, `--rightctrl`, `--leftshift`, `--rightshift`, `--super`

Key chords (like ctrl-space) not available yet.

---

## Configuration

Configuration is read from `~/.config/xhisper/xhisperrc`:

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

## macOS

The Linux xhisper app does not run directly on macOS because it depends on PipeWire, `/dev/uinput`, and Linux desktop keybinds. The local `whisper.cpp` transcription approach is portable, though. See [`docs/macos-local-whisper.md`](docs/macos-local-whisper.md) for an equivalent macOS workflow using `ffmpeg`, `pbcopy`, and a hotkey tool.

## Troubleshooting

**Terminal Applications**: With `paste-chord : auto`, common terminal emulators use Ctrl+Shift+V and other apps use Ctrl+V. If detection is wrong, set `paste-chord : ctrl-v` or `paste-chord : ctrl-shift-v`.

**Non-ASCII Transcription**: Increase non-ascii-*-delay to give the transcription longer timing buffer.

---

<p align="center">
  <em>Low complexity dictation for Linux</em>
</p>
