#!/bin/bash

# xhisper v1.0
# Dictate anywhere in Linux. Transcription at your cursor.
# - Transcription via local whisper.cpp or Groq Whisper

# Configuration (see default_xhisperrc or ~/.config/xhisper/xhisperrc):
# - long-recording-threshold : threshold for using large vs turbo model (seconds)
# - transcription-backend : "local" for whisper.cpp or "groq" for Groq API
# - transcription-prompt : context words for better Whisper accuracy
# - whisper-cpp-binary : path to whisper.cpp whisper-cli
# - whisper-cpp-model : path to whisper.cpp ggml model
# - whisper-cpp-language : spoken language, or "auto"
# - whisper-cpp-threads : number of CPU threads for whisper.cpp
# - output-mode : "paste" for fast clipboard paste or "type" for character typing
# - paste-chord : "auto", "ctrl-v", or "ctrl-shift-v"
# - silence-threshold : max volume in dB to consider silent (e.g., -50)
# - silence-percentage : percentage of recording that must be silent (e.g., 95)
# - non-ascii-initial-delay : sleep after first non-ASCII paste (seconds)
# - non-ascii-default-delay : sleep after subsequent non-ASCII pastes (seconds)

# Requirements:
# - pipewire, pipewire-utils (audio)
# - wl-clipboard (Wayland) or xclip (X11) for clipboard
# - jq, curl, ffmpeg (processing)
# - make to build, sudo make install to install

[ -f "$HOME/.env" ] && source "$HOME/.env"

# Parse command-line arguments
LOCAL_MODE=0
WRAP_KEY=""
for arg in "$@"; do
  case "$arg" in
    --local)
      LOCAL_MODE=1
      ;;
    --log)
      if [ -f "/tmp/xhisper.log" ]; then
        cat /tmp/xhisper.log
      else
        echo "No log file found at /tmp/xhisper.log" >&2
      fi
      exit 0
      ;;
    --leftalt|--rightalt|--leftctrl|--rightctrl|--leftshift|--rightshift|--super)
      if [ -n "$WRAP_KEY" ]; then
        echo "Error: Multiple wrap keys not yet supported" >&2
        exit 1
      fi
      WRAP_KEY="${arg#--}"
      ;;
    *)
      echo "Error: Unknown option '$arg'" >&2
      echo "Usage: xhisper [--local] [--log] [--leftalt|--rightalt|--leftctrl|--rightctrl|--leftshift|--rightshift|--super]" >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set binary paths based on local mode
if [ "$LOCAL_MODE" -eq 1 ]; then
  XHISPERTOOL="$SCRIPT_DIR/xhispertool"
  XHISPERTOOLD="$SCRIPT_DIR/xhispertoold"
elif [ -x "$SCRIPT_DIR/xhispertool" ] && [ -x "$SCRIPT_DIR/xhispertoold" ]; then
  XHISPERTOOL="$SCRIPT_DIR/xhispertool"
  XHISPERTOOLD="$SCRIPT_DIR/xhispertoold"
else
  XHISPERTOOL="xhispertool"
  XHISPERTOOLD="xhispertoold"
fi

RECORDING="/tmp/xhisper.wav"
LOGFILE="/tmp/xhisper.log"
PROCESS_PATTERN="pw-record.*$RECORDING"

# Default configuration
long_recording_threshold=1000
transcription_backend="local"
transcription_prompt=""
whisper_cpp_binary="$HOME/.local/opt/whisper.cpp/build/bin/whisper-cli"
whisper_cpp_model="$HOME/.local/share/xhisper/models/ggml-base.en.bin"
whisper_cpp_language="en"
whisper_cpp_threads=""
output_mode="paste"
paste_chord="auto"
silence_threshold=-50
silence_percentage=95
non_ascii_initial_delay=0.1
non_ascii_default_delay=0.025

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/xhisper/xhisperrc"

if [ -f "$CONFIG_FILE" ]; then
  while IFS=: read -r key value || [ -n "$key" ]; do
    # Skip comments and empty lines
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue

    # Trim whitespace and quotes
    key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//')

    case "$key" in
      long-recording-threshold) long_recording_threshold="$value" ;;
      transcription-backend) transcription_backend="$value" ;;
      transcription-prompt) transcription_prompt="$value" ;;
      whisper-cpp-binary) whisper_cpp_binary="$value" ;;
      whisper-cpp-model) whisper_cpp_model="$value" ;;
      whisper-cpp-language) whisper_cpp_language="$value" ;;
      whisper-cpp-threads) whisper_cpp_threads="$value" ;;
      output-mode) output_mode="$value" ;;
      paste-chord) paste_chord="$value" ;;
      silence-threshold) silence_threshold="$value" ;;
      silence-percentage) silence_percentage="$value" ;;
      non-ascii-initial-delay) non_ascii_initial_delay="$value" ;;
      non-ascii-default-delay) non_ascii_default_delay="$value" ;;
    esac
  done < "$CONFIG_FILE"
fi

expand_path() {
  local path="$1"
  path="${path/#\~/$HOME}"
  path="${path//\$HOME/$HOME}"
  echo "$path"
}

whisper_cpp_binary="$(expand_path "$whisper_cpp_binary")"
whisper_cpp_model="$(expand_path "$whisper_cpp_model")"

# Auto-start daemon if not running
if ! pgrep -x xhispertoold > /dev/null; then
    "$XHISPERTOOLD" 2>> /tmp/xhispertoold.log &
    sleep 1  # Give daemon time to start

    # Verify daemon started successfully
    if ! pgrep -x xhispertoold > /dev/null; then
        echo "Error: Failed to start xhispertoold daemon" >&2
        echo "Check /tmp/xhispertoold.log for details" >&2
        exit 1
    fi
fi

# Check if xhispertool is available
if ! command -v "$XHISPERTOOL" &> /dev/null; then
    echo "Error: xhispertool not found" >&2
    echo "Please either:" >&2
    echo "  - Run 'sudo make install' to install system-wide" >&2
    echo "  - Run 'xhisper --local' from the build directory" >&2
    exit 1
fi

# Detect clipboard tool
if command -v wl-copy &> /dev/null; then
    CLIP_COPY="wl-copy"
    CLIP_PASTE="wl-paste"
elif command -v xclip &> /dev/null; then
    CLIP_COPY() { xclip -selection clipboard; }
    CLIP_PASTE() { xclip -o -selection clipboard; }
else
    echo "Error: No clipboard tool found. Install wl-clipboard or xclip." >&2
    exit 1
fi

press_wrap_key() {
  if [ -n "$WRAP_KEY" ]; then
    "$XHISPERTOOL" "$WRAP_KEY"
  fi
}

paste() {
  local text="$1"
  press_wrap_key
  # Type character by character
  # Use xhispertool type for ASCII (32-126), clipboard+paste for Unicode
  for ((i=0; i<${#text}; i++)); do
    local char="${text:$i:1}"
    local ascii=$(printf '%d' "'$char")

    if [[ $ascii -ge 32 && $ascii -le 126 ]]; then
      # ASCII printable character - use direct key typing (faster)
      "$XHISPERTOOL" type "$char"
    else
      # Unicode or special character - use clipboard
      echo -n "$char" | $CLIP_COPY
      "$XHISPERTOOL" paste
      # On first character (more error-prone), sleep longer
      [ "$i" -eq 0 ] && sleep "$non_ascii_initial_delay" || sleep "$non_ascii_default_delay"
    fi
  done
  press_wrap_key
}

active_window_class() {
  if ! command -v hyprctl &> /dev/null; then
    return 1
  fi

  hyprctl activewindow -j 2>/dev/null | sed -n 's/.*"class"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
}

is_terminal_class() {
  case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
    alacritty|foot|footclient|kitty|konsole|org.wezfurlong.wezterm|rio|st|tabby|terminator|termite|tilix|wezterm|xterm)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

paste_clipboard() {
  case "$1" in
    ctrl-shift-v)
      "$XHISPERTOOL" terminal-paste
      ;;
    ctrl-v)
      "$XHISPERTOOL" paste
      ;;
    auto)
      if is_terminal_class "$(active_window_class)"; then
        "$XHISPERTOOL" terminal-paste
      else
        "$XHISPERTOOL" paste
      fi
      ;;
    *)
      echo "Error: Unknown paste-chord '$1'" >&2
      return 1
      ;;
  esac
}

output_text() {
  local text="$1"

  case "$output_mode" in
    paste)
      press_wrap_key
      printf '%s' "$text" | $CLIP_COPY
      paste_clipboard "$paste_chord"
      press_wrap_key
      ;;
    type)
      paste "$text"
      ;;
    *)
      echo "Error: Unknown output-mode '$output_mode'" >&2
      return 1
      ;;
  esac
}

delete_n_chars() {
  local n="$1"
  for ((i=0; i<n; i++)); do
    "$XHISPERTOOL" backspace
  done
}

get_duration() {
  local recording="$1"
  ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$recording" 2>/dev/null || echo "0"
}

is_silent() {
  local recording="$1"

  # Use ffmpeg volumedetect to get mean and max volume
  local vol_stats=$(ffmpeg -i "$recording" -af "volumedetect" -f null /dev/null 2>&1 | grep -E "mean_volume|max_volume")
  local max_vol=$(echo "$vol_stats" | grep "max_volume" | awk '{print $5}')

  # If max volume is below threshold, consider it silent
  # Note: ffmpeg reports in dB, negative values (e.g., -50 dB is quiet)
  if [ -n "$max_vol" ]; then
    local is_quiet=$(echo "$max_vol < $silence_threshold" | bc -l)
    [ "$is_quiet" -eq 1 ] && return 0
  fi

  return 1
}

logging_end_and_write_to_logfile() {
  local title="$1"
  local result="$2"
  local logging_start="$3"

  local logging_end=$(date +%s%N)
  local time=$(echo "scale=3; ($logging_end - $logging_start) / 1000000000" | bc)

  echo "=== $title ===" >> "$LOGFILE"
  echo "Result: [$result]" >> "$LOGFILE"
  echo "Time: ${time}s" >> "$LOGFILE"
}

transcribe() {
  local recording="$1"
  local logging_start=$(date +%s%N)
  local transcription=""

  case "$transcription_backend" in
    local|whisper.cpp|whisper-cpp)
      if [ ! -x "$whisper_cpp_binary" ]; then
        echo "Error: whisper.cpp binary not found or not executable: $whisper_cpp_binary" >&2
        return 1
      fi
      if [ ! -f "$whisper_cpp_model" ]; then
        echo "Error: whisper.cpp model not found: $whisper_cpp_model" >&2
        return 1
      fi

      local whisper_args=(
        -m "$whisper_cpp_model"
        -f "$recording"
        -nt
        -np
        -l "$whisper_cpp_language"
      )

      if [ -n "$whisper_cpp_threads" ]; then
        whisper_args+=(-t "$whisper_cpp_threads")
      fi

      if [ -n "$transcription_prompt" ]; then
        whisper_args+=(--prompt "$transcription_prompt")
      fi

      transcription=$("$whisper_cpp_binary" "${whisper_args[@]}" 2>> "$LOGFILE" | sed 's/^ //;s/[[:space:]]*$//')
      ;;
    groq)
      # Use large model for longer recordings, turbo for short ones
      local is_long_recording=$(echo "$(get_duration "$recording") > $long_recording_threshold" | bc -l)
      local model=$([[ $is_long_recording -eq 1 ]] && echo "whisper-large-v3" || echo "whisper-large-v3-turbo")

      transcription=$(curl -s -X POST "https://api.groq.com/openai/v1/audio/transcriptions" \
        -H "Authorization: Bearer $GROQ_API_KEY" \
        -H "Content-Type: multipart/form-data" \
        -F "file=@$recording" \
        -F "model=$model" \
        -F "prompt=$transcription_prompt" \
        | jq -r '.text' | sed 's/^ //') # Transcription always returns a leading space, so remove it via sed
      ;;
    *)
      echo "Error: Unknown transcription-backend '$transcription_backend'" >&2
      return 1
      ;;
  esac

  logging_end_and_write_to_logfile "Transcription" "$transcription" "$logging_start"

  echo "$transcription"
}

# Main

# When launched by a modifier keybind, give the compositor time to observe the
# modifier release before xhisper injects status text.
sleep 0.35

# Find recording process, if so then kill
if pgrep -f "$PROCESS_PATTERN" > /dev/null; then
  pkill -f "$PROCESS_PATTERN"; sleep 0.2 # Buffer for flush
  delete_n_chars 14 # "(recording...)"

  # Check if recording is silent
  if is_silent "$RECORDING"; then
    paste "(no sound detected)"
    sleep 0.6
    delete_n_chars 19 # "(no sound detected)"
    rm -f "$RECORDING"
    exit 0
  fi

  paste "(transcribing...)"
  TRANSCRIPTION=$(transcribe "$RECORDING")
  delete_n_chars 17 # "(transcribing...)"

  output_text "$TRANSCRIPTION"

  rm -f "$RECORDING"
else
  # No recording running, so start
  sleep 0.2
  paste "(recording...)"
  pw-record --channels=1 --rate=16000 "$RECORDING" >/tmp/xhisper-pw-record.log 2>&1 &
fi
