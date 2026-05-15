# Windows local whisper.cpp equivalent

xhisper is currently a Linux app. The local transcription backend is portable, but the cursor integration is not.

The Linux implementation depends on:

- PipeWire `pw-record` for recording
- `/dev/uinput` for typing and paste key chords
- `wl-copy` / `wl-paste` on Wayland
- Linux desktop keybinds

Windows needs equivalent pieces:

- `whisper.cpp` for transcription
- `ffmpeg` for recording
- PowerShell clipboard APIs or `clip.exe`
- AutoHotkey, PowerToys Keyboard Manager, or another hotkey runner

## Can this work without admin?

Usually yes for the local transcription part.

You can keep everything under your user profile, for example:

```powershell
$env:USERPROFILE\.local\opt\whisper.cpp
$env:USERPROFILE\.local\share\xhisper\models
```

The harder dependency is the C++ build toolchain. If a compiler and CMake are already installed, no admin is needed. If they are not installed, you need one of:

- a portable/prebuilt `whisper-cli.exe`
- a user-local compiler/toolchain
- admin rights once to install Visual Studio Build Tools, CMake, Git, and FFmpeg

Global hotkeys and clipboard paste generally do not need admin. One caveat: a non-admin hotkey tool usually cannot paste into elevated/admin windows.

## whisper.cpp build outline

The official `whisper.cpp` project uses CMake and builds `whisper-cli`.

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

Run a transcription:

```powershell
& "$env:USERPROFILE\.local\opt\whisper.cpp\build\bin\Release\whisper-cli.exe" `
  -m "$env:USERPROFILE\.local\share\xhisper\models\ggml-base.en.bin" `
  -f "C:\path\to\audio.wav" `
  -nt -np -l en
```

The exact `whisper-cli.exe` path can differ depending on the CMake generator.

## Minimal Windows dictation approach

A Windows equivalent of xhisper would:

1. Start `ffmpeg` recording from the selected microphone.
2. On the next hotkey press, stop `ffmpeg`.
3. Run `whisper-cli.exe` on the recorded WAV file.
4. Copy the transcription to the clipboard.
5. Send `Ctrl+V`.

This is the same shape as xhisper, but implemented with Windows APIs/tools instead of PipeWire and uinput.

## AutoHotkey sketch

This is only a starting point. Device names and paths need to be adjusted.

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

Then replace `YOUR MICROPHONE NAME` in the script.

## Status

This is an equivalent workflow, not the Linux xhisper binary running on Windows. A proper Windows port would add a native recorder and input/paste backend while reusing the same local `whisper.cpp` transcription idea.
