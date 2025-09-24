#!/bin/bash
# Direct installation in Codespaces (no Docker)

set -e

echo "📦 Installing system dependencies..."
sudo apt-get update
sudo apt-get install -y build-essential ninja-build git wget

echo "🐍 Installing Miniforge..."
if [ ! -d "$HOME/miniforge3" ]; then
    wget -q https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -O /tmp/miniforge.sh
    bash /tmp/miniforge.sh -b -p $HOME/miniforge3
    rm /tmp/miniforge.sh
fi

# Initialize conda
eval "$($HOME/miniforge3/bin/conda shell.bash hook)"

echo "🌍 Creating wallx environment..."
if ! conda env list | grep -q wallx; then
    conda create -n wallx python=3.10 -y
fi

conda activate wallx

echo "📚 Installing Python dependencies..."
pip install --no-cache-dir -r requirements.txt

echo "⚡ Installing Flash-Attention (this takes 5-10 minutes)..."
MAX_JOBS=2 pip install flash-attn==2.7.4.post1 --no-build-isolation
rm -rf ~/.cache/pip/*

echo "🤖 Installing LeRobot..."
if [ ! -d "/tmp/lerobot" ]; then
    git clone --depth 1 https://github.com/huggingface/lerobot.git /tmp/lerobot
fi
cd /tmp/lerobot && pip install --no-cache-dir -e . && cd -
rm -rf ~/.cache/pip/*

echo "🔧 Installing Wall-X..."
git submodule update --init --recursive
MAX_JOBS=2 pip install --no-build-isolation --no-cache-dir .
rm -rf ~/.cache/pip/* build/

echo "✅ Installation complete!"
echo "🚀 Activate environment: conda activate wallx"
echo "🧪 Test inference: python scripts/fake_inference.py"