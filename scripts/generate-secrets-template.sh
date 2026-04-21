#!/bin/bash

# Crooked Sentry Secrets Generator
# 
# This script generates a secure secrets.env file by prompting for sensitive values
# and saving them with proper permissions (600 - owner read/write only).
#
# Usage:
#   ./scripts/generate-secrets-template.sh
#
# Output:
#   Creates or updates secrets.env with secure credentials

set -euo pipefail

SECRETS_FILE="secrets.env"

# Colors
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

echo "=========================================="
echo "Crooked Sentry Secrets Generator"
echo "=========================================="
echo ""

# Warning
echo -e "${YELLOW}IMPORTANT:${NC}"
echo "This script will create a secrets.env file with sensitive credentials."
echo "This file will be marked as 600 permissions (owner-only access)."
echo "NEVER commit this file to git or share it."
echo ""

# Check if file exists
if [ -f "$SECRETS_FILE" ]; then
  read -p "secrets.env already exists. Overwrite? (y/N): " -n 1 -r confirm
  echo ""
  if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
  fi
fi

# Prompt for secrets
read -rp "Enter MQTT password (for homeassistant user): " -s mqtt_password
echo ""

read -rp "Enter Frigate MQTT password (for frigate user): " -s frigate_mqtt_password
echo ""

read -rp "Enter Frigate RTSP password: " -s frigate_rtsp_password
echo ""

read -rp "Enter Home Assistant admin password: " -s ha_admin_password
echo ""

# Optional extras
read -rp "Enter latitude for HA (default 35.0): " latitude
latitude=${latitude:-35.0}

read -rp "Enter longitude for HA (default -85.0): " longitude
longitude=${longitude:-85.0}

read -rp "Enter elevation in meters (default 400): " elevation
elevation=${elevation:-400}

# Generate secrets file
cat > "$SECRETS_FILE" << EOF
# Crooked Sentry Secrets
# Generated: $(date)
# DO NOT COMMIT THIS FILE TO GIT
#
# Add to .gitignore: $SECRETS_FILE

# MQTT Credentials
MQTT_PASSWORD=$mqtt_password
MQTT_FRIGATE_PASSWORD=$frigate_mqtt_password

# Frigate Credentials
FRIGATE_RTSP_PASSWORD=$frigate_rtsp_password

# Home Assistant Admin
HA_ADMIN_PASSWORD=$ha_admin_password

# Location (for HA automations, sunrise/sunset)
HA_LATITUDE=$latitude
HA_LONGITUDE=$longitude
HA_ELEVATION=$elevation

# Add additional secrets below as needed
# API_KEY_SERVICE_1=your_api_key_here
# API_KEY_SERVICE_2=your_api_key_here

EOF

# Set secure permissions
chmod 600 "$SECRETS_FILE"

echo ""
echo -e "${GREEN}✓ Secrets file created: $SECRETS_FILE${NC}"
echo -e "  Permissions: 600 (owner read/write only)"
echo ""
echo "Next steps:"
echo "  1. Review the file: cat $SECRETS_FILE"
echo "  2. Source it before deployment: source $SECRETS_FILE"
echo "  3. Verify .gitignore includes: $SECRETS_FILE"
echo ""
echo "To use these secrets in scripts:"
echo "  source $SECRETS_FILE"
echo "  export MQTT_PASSWORD  # or use \$MQTT_PASSWORD in commands"
echo ""

# Verify .gitignore
if [ ! -f ".gitignore" ]; then
  echo "Creating .gitignore..."
  cat > .gitignore << 'EOF'
# Secrets and credentials (never commit)
secrets.env
.env
.env.local

# Development
.vscode
.DS_Store
*.swp
*.swo

# Temporary
/tmp
*.tmp

# Backups
*.bak
*.backup

# IDE
.idea

# OS
Thumbs.db
EOF
  echo "  Created .gitignore"
elif ! grep -q "secrets.env" .gitignore; then
  echo "secrets.env" >> .gitignore
  echo "  Added secrets.env to .gitignore"
fi

echo ""
echo -e "${GREEN}Setup complete!${NC}"
