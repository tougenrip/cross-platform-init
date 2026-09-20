#!/usr/bin/env bash
# Preflight for the cross-platform stack. Reports what each requested target
# needs and what is missing. Never installs anything: several fixes need sudo,
# and that is the user's decision to make.
#
# Usage: preflight.sh [web] [backend] [desktop] [android] [ios]   (default: all)
set -u
TARGETS=("$@"); [ $# -eq 0 ] && TARGETS=(web backend desktop android ios)
OS=$(uname -s)
MISSING=0

# A non-interactive shell inherits none of the user's shell config, so tools
# installed by Homebrew, nvm or rustup look absent when they are plainly there.
# Probe the usual locations before believing anything is missing.
PATH="/opt/homebrew/bin:/usr/local/bin:/opt/local/bin:$HOME/.cargo/bin:$HOME/.local/bin:$HOME/bin:$PATH"
for d in "$HOME/.nvm/versions/node"/*/bin \
         "$HOME/.volta/bin" \
         "$HOME/.local/share/fnm"/*/bin \
         "$HOME/.asdf/shims" \
         "$HOME/.bun/bin"; do
  # Deliberately NOT /usr/lib/jvm/*/bin: injecting a JDK into PATH would make
  # this report a java the build will never use. The jdk check below inspects
  # the selected one and looks at the install directory separately.
  [ -d "$d" ] && PATH="$d:$PATH"
done
export PATH

# Last resort before declaring a command absent: look for it on disk. Reporting
# "install X" to someone who already has X costs them time and credibility.
locate_cmd() {
  command -v "$1" 2>/dev/null && return 0
  for d in /opt/homebrew/bin /usr/local/bin /usr/bin /bin /opt/local/bin \
           "$HOME/.local/bin" "$HOME/bin"; do
    [ -x "$d/$1" ] && { echo "$d/$1"; return 0; }
  done
  return 1
}

want() { for t in "${TARGETS[@]}"; do [ "$t" = "$1" ] && return 0; done; return 1; }
ok()   { printf '  \033[32mok\033[0m       %s\n' "$1"; }
bad()  { printf '  \033[31mMISSING\033[0m  %-34s %s\n' "$1" "$2"; MISSING=$((MISSING+1)); }
have() { command -v "$1" >/dev/null 2>&1 || locate_cmd "$1" >/dev/null 2>&1; }

echo "Preflight: ${TARGETS[*]}  (os: $OS)"
[ -z "${PS1:-}" ] && echo "(non-interactive shell: ~/.bashrc is not sourced, so exported" \
  && echo " vars may look unset here even when the user has them set)"
echo

if want web || want backend || want android || want desktop; then
  echo "core"
  have node && ok "node $(node -v)" || bad "node" "install Node 20+ from nodejs.org or nvm"
  have npm  && ok "npm $(npm -v)"   || bad "npm" "ships with node"
  echo
fi

if want backend; then
  echo "backend (docker)"
  if have docker; then
    ok "docker $(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    docker info >/dev/null 2>&1 && ok "docker daemon running" \
      || bad "docker daemon" "start Docker, then re-run"
    docker compose version >/dev/null 2>&1 && ok "compose plugin" \
      || bad "docker compose" "install the compose v2 plugin"
  else
    bad "docker" "https://docs.docker.com/engine/install/"
  fi
  echo
fi

if want desktop; then
  echo "desktop (tauri)"
  have cargo && ok "rust $(cargo --version | awk '{print $2}')" \
    || bad "rust/cargo" "https://rustup.rs"
  case "$OS" in
    Linux)
      have pkg-config || bad "pkg-config" "sudo apt install pkg-config"
      for p in dbus-1 webkit2gtk-4.1 gtk+-3.0 javascriptcoregtk-4.1; do
        pkg-config --exists "$p" 2>/dev/null && ok "lib $p" || bad "lib $p" "see apt line below"
      done
      ;;
    Darwin) xcode-select -p >/dev/null 2>&1 && ok "xcode command line tools" \
              || bad "xcode CLT" "xcode-select --install" ;;

    *)      echo "  note     Windows needs MSVC build tools + WebView2" ;;
  esac
  echo
fi

if want android; then
  echo "android (capacitor)"
  if have java; then
    JV=$(java -version 2>&1 | head -1 | grep -oE '"[^"]+"' | tr -d '"')
    # "1.8.0_x" is Java 8; modern releases report "17.x"/"21.x".
    JMAJ=$(printf '%s' "$JV" | awk -F. '{ if ($1=="1") print $2; else print $1 }')
    if [ "${JMAJ:-0}" -ge 17 ] 2>/dev/null; then
      ok "jdk $JV"
    else
      # A usable JDK is often already installed and simply not selected,
      # so check before telling anyone to install anything.
      # Prefer 21, then 17: the Android Gradle Plugin trails the newest JDK,
      # so the highest installed version is often the wrong recommendation.
      ALT=""
      for v in 21 17; do
        for d in /usr/lib/jvm/java-$v-openjdk-*; do
          [ -d "$d" ] && { ALT="$d"; break 2; }
        done
      done
      if [ -n "$ALT" ]; then
        bad "jdk $JV selected (need 17+)" "already installed: export JAVA_HOME=$ALT"
      else
        bad "jdk $JV (need 17+)" "sudo apt install openjdk-21-jdk"
      fi
    fi
  else
    bad "jdk" "sudo apt install openjdk-21-jdk"
  fi
  # An agent's shell is usually non-interactive, so ~/.bashrc is never sourced
  # and an exported var looks unset. Check the usual SDK location before
  # reporting a variable the user has almost certainly already set.
  SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  if [ -n "$SDK" ]; then
    ok "ANDROID_HOME=$SDK"
  elif [ -d "$HOME/Android/Sdk" ]; then
    ok "SDK found at \$HOME/Android/Sdk (ANDROID_HOME unset in THIS shell only)"
    echo "           if a build disagrees, export ANDROID_HOME=\$HOME/Android/Sdk"
  else
    bad "ANDROID_HOME" "install Android Studio, then export ANDROID_HOME=\$HOME/Android/Sdk"
  fi
  have adb && ok "adb" || bad "adb" "part of Android SDK platform-tools"
  echo
fi

if want ios; then
  echo "ios (capacitor)"
  if [ "$OS" = "Darwin" ]; then
    # `xcode-select -p` succeeds for the Command Line Tools alone, which cannot
    # build for a simulator. What matters is whether the ACTIVE developer
    # directory is Xcode.app, not merely whether Xcode is installed somewhere.
    DEV=$(xcode-select -p 2>/dev/null)
    XAPP=$(ls -d /Applications/Xcode*.app 2>/dev/null | head -1)
    case "$DEV" in
      *Xcode*) ok "xcode active ($DEV)" ;;
      *) if [ -n "$XAPP" ]; then
           bad "xcode installed but NOT active" "sudo xcode-select -s $XAPP/Contents/Developer"
         else
           bad "xcode" "install Xcode from the App Store (Command Line Tools are not enough)"
         fi ;;
    esac
    # Current Capacitor generates a Swift Package Manager project and no
    # Podfile, so CocoaPods is not a prerequisite. It is only needed for older
    # plugins that ship no Package.swift. Report it, never block on it.
    # Xcode 26 installs with NO iOS platform. `xcodebuild -showsdks` still
    # lists iOS SDKs, so that is not a reliable signal; the absence of any
    # simulator runtime is. Without the platform NO iOS build works, device or
    # simulator, and the error says "Found no destinations for the scheme"
    # rather than naming the missing download.
    RT=$(xcrun simctl list runtimes 2>/dev/null | grep -c "iOS")
    if [ "${RT:-0}" -gt 0 ]; then
      ok "ios platform installed ($RT simulator runtime/s)"
    else
      bad "ios platform NOT installed" "xcodebuild -downloadPlatform iOS   (several GB; blocks all iOS builds)"
    fi

    if have pod; then
      ok "cocoapods $(pod --version 2>/dev/null) (present; usually unnecessary)"
    else
      echo "  note     cocoapods absent - fine: Capacitor uses Swift Package Manager."
      echo "           Only needed if a plugin ships no Package.swift; then: brew install cocoapods"
    fi
  else
    echo "  n/a      iOS builds require macOS; skip cap add ios on this machine"
  fi
  echo
fi

if [ "$MISSING" -gt 0 ] && want desktop && [ "$OS" = "Linux" ]; then
  echo "Tauri on Debian/Ubuntu:"
  echo "  sudo apt install libwebkit2gtk-4.1-dev build-essential curl wget file \\"
  echo "    libxdo-dev libssl-dev libayatana-appindicator3-dev librsvg2-dev \\"
  echo "    libdbus-1-dev pkg-config"
  echo
fi

if [ "$MISSING" -eq 0 ]; then
  echo "All prerequisites present for: ${TARGETS[*]}"
else
  echo "$MISSING missing. Targets whose prerequisites are met still work;"
  echo "report the blocked ones to the user rather than building around them."
  echo
  echo "Before passing any of these on: confirm the thing is genuinely absent"
  echo "rather than merely unselected, unset, not running, or off this PATH."
fi
echo
echo "This checks what has bitten us before, not every way a machine can differ."
echo "If it passes and a build still fails, the gap is in this script: find the"
echo "real cause, fix it here, and say what changed."
exit 0
