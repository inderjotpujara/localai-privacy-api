#!/bin/bash
set -e

# Create models directory if it doesn't exist
mkdir -p ./models

# Download Phi-2 model (smaller for testing)
echo "Downloading Phi-2 model..."
cd models

# Check if file already exists
if [ ! -f "phi-2.Q4_K_M.gguf" ]; then
    echo "Downloading Phi-2 Q4_K_M model (~1.6GB)..."
    # Remove the failed download first
    rm -f phi-2.Q4_K_M.gguf
    # Use a working Phi-2 model URL
    curl -L -o phi-2.Q4_K_M.gguf "https://huggingface.co/TheBloke/phi-2-GGUF/resolve/main/phi-2.Q4_K_M.gguf"
    echo "Phi-2 model downloaded successfully!"
else
    echo "Phi-2 model already exists."
fi

cd ..
echo "Model download complete!"
