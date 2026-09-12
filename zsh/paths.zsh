export EDITOR="cursor"
export VISUAL="cursor"

# Homebrew first (Apple Silicon) so brew CLIs win over pub-cache shims
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"

# Android SDK platform-tools before Homebrew / system PATH (official adb)
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# Dart pub global bins AFTER Homebrew so brew fvm is not shadowed
export PATH="$PATH:$HOME/.pub-cache/bin"

export MAVEN_OPTS="-Xmx2g -Dfile.encoding=UTF-8"
