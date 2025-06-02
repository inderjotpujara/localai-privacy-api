#!/bin/bash

# setup-models.sh - Download and setup models for LocalAI

set -e

echo "🤖 Setting up Local LLM models..."

# Create models directory if it doesn't exist
mkdir -p models

# Download Llama 3 model (example - adjust URL and model as needed)
# Note: This is just an example - replace with actual model URLs
echo "📥 Downloading Llama-3 model..."

# Option 1: Download a GGUF model (recommended for LocalAI)
if [ ! -f "models/llama-3-8b-instruct.gguf" ]; then
    echo "Downloading Llama-3 8B Instruct GGUF..."
    # wget -O models/llama-3-8b-instruct.gguf https://huggingface.co/Microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf
    echo "⚠️  Please manually download your preferred model to the models/ directory"
    echo "   Recommended: Llama-3, Phi-3, or similar instruction-tuned models"
fi

# Download embedding model
if [ ! -f "models/all-MiniLM-L6-v2.bin" ]; then
    echo "📥 Downloading embedding model..."
    # This is a placeholder - LocalAI will download it automatically
    echo "ℹ️  Embedding model will be downloaded automatically by LocalAI"
fi

# Create LocalAI model configuration
echo "⚙️  Creating model configurations..."

cat > models/llama3.yaml << EOF
name: llama3
backend: llama
parameters:
  model: llama-3-8b-instruct.gguf
  context_size: 4096
  threads: 4
  f16: true
  use_mlock: true
  use_mmap: true
template:
  chat: |
    <|begin_of_text|><|start_header_id|>system<|end_header_id|>
    You are a helpful AI assistant.<|eot_id|>
    {{range .Messages}}<|start_header_id|>{{.Role}}<|end_header_id|>
    {{.Content}}<|eot_id|>
    {{end}}<|start_header_id|>assistant<|end_header_id|>
  completion: |
    {{.Input}}
EOF

cat > models/embeddings.yaml << EOF
name: all-MiniLM-L6-v2
backend: bert-embeddings
parameters:
  model: all-MiniLM-L6-v2
embeddings: true
EOF

echo "✅ Model setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Download your preferred model file to the models/ directory"
echo "2. Update the model filename in models/llama3.yaml"
echo "3. Run: docker-compose up -d"
echo ""
echo "🔗 Model sources:"
echo "- Hugging Face: https://huggingface.co/models"
echo "- GGUF models: https://huggingface.co/models?library=gguf"
echo "- LocalAI gallery: https://localai.io/models/"
