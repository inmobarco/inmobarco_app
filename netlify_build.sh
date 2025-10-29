#!/usr/bin/env bash
set -e
# create config directory and .env from Netlify environment variables
mkdir -p assets/config
cat > assets/config/.env <<'EOF'
# API Key de Arrendasoft
ARRENDASOFT_API_KEY=${ARRENDASOFT_API_KEY}
WASI_API_TOKEN=${WASI_API_TOKEN}
WASI_API_ID=${WASI_API_ID}
# URLs base
ARRENDASOFT_API_BASE_URL=${ARRENDASOFT_API_BASE_URL}
ARRENDASOFT_API_KEY=${ARRENDASOFT_API_KEY}
INMOBARCO_WEB_BASE_URL=${INMOBARCO_WEB_BASE_URL}
WASI_API_URL=${WASI_API_URL}
# Configuración de la app
APP_NAME=${APP_NAME}
APP_VERSION=${APP_VERSION}

# Encryption Configuration for Property IDs - CHANGE THESE FOR PRODUCTION
VITE_ENCRYPTION_KEY=${VITE_ENCRYPTION_KEY}
VITE_ENCRYPTION_SALT=${VITE_ENCRYPTION_SALT}
EOF

# continue with existing build steps
# e.g. flutter build web --release
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