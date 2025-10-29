#!/usr/bin/env bash
set -e

# Install Flutter in $HOME/flutter if not already present
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter"
fi

# Add Flutter to PATH
export PATH="$HOME/flutter/bin:$PATH"

# Optional: verify the installation (this will download required artifacts)
flutter --version

# Get packages and build the web app
flutter pub get
flutter build web --release