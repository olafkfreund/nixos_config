#!/bin/bash

# Manual encryption commands for API keys
# Run these commands one by one in the NixOS directory

set -e

OPENAI_FILE="$HOME/.openai.sh"

echo "🔐 Manual API Key Encryption Commands"
echo "====================================="
echo ""

if [[ ! -f "$OPENAI_FILE" ]]; then
    echo "❌ Error: ~/.openai.sh not found"
    exit 1
fi

# Extract keys
OPENAI_KEY=$(grep "^export OPENAI_API_KEY=" "$OPENAI_FILE" | sed "s/^export OPENAI_API_KEY=//" | sed 's/^"//' | sed 's/"$//')
GEMINI_KEY=$(grep "^export GEMINI_API_KEY=" "$OPENAI_FILE" | sed "s/^export GEMINI_API_KEY=//" | sed 's/^"//' | sed 's/"$//')
ANTHROPIC_KEY=$(grep "^export ANTHROPIC_API_KEY=" "$OPENAI_FILE" | sed "s/^export ANTHROPIC_API_KEY=//" | sed 's/^"//' | sed 's/"$//')
LANGCHAIN_KEY=$(grep "^export LANGCHAIN_API_KEY=" "$OPENAI_FILE" | sed "s/^export LANGCHAIN_API_KEY=//" | sed 's/^"//' | sed 's/"$//')
GITHUB_KEY=$(grep "^export GITHUB_TOKEN=" "$OPENAI_FILE" | sed "s/^export GITHUB_TOKEN=//" | sed 's/^"//' | sed 's/"$//')

echo "📋 Keys found:"
echo "   OpenAI: ${OPENAI_KEY:0:20}..."
echo "   Gemini: ${GEMINI_KEY:0:20}..."
echo "   Anthropic: ${ANTHROPIC_KEY:0:20}..."
echo "   LangChain: ${LANGCHAIN_KEY:0:20}..."
echo "   GitHub: ${GITHUB_KEY:0:20}..."
echo ""

echo "🚀 Run these commands in the NixOS directory:"
echo "=============================================="
echo ""

echo "# 1. Encrypt OpenAI key:"
echo "echo -n '$OPENAI_KEY' | agenix -e secrets/api-openai.age"
echo ""

echo "# 2. Encrypt Gemini key:"
echo "echo -n '$GEMINI_KEY' | agenix -e secrets/api-gemini.age"
echo ""

echo "# 3. Encrypt Anthropic key:"
echo "echo -n '$ANTHROPIC_KEY' | agenix -e secrets/api-anthropic.age"
echo ""

echo "# 4. Encrypt LangChain key:"
echo "echo -n '$LANGCHAIN_KEY' | agenix -e secrets/api-langchain.age"
echo ""

echo "# 5. Encrypt GitHub token:"
echo "echo -n '$GITHUB_KEY' | agenix -e secrets/api-github-token.age"
echo ""

echo "⚠️  Note: Run each command separately and wait for completion"
echo "📁 Make sure you're in: $(pwd)"