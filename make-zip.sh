#!/bin/bash
set -e
cd "$(dirname "$0")"
zip -r voice-mcp.zip index.js setup.sh skill.md package.json package-lock.json
echo "Created voice-mcp.zip"
