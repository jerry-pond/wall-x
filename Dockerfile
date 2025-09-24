# WALL-X NVIDIA Docker Environment
# Base: NVIDIA CUDA 12.4 + cuDNN 9 + Ubuntu 22.04
FROM nvcr.io/nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

# Environment setup
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    CUDA_HOME=/usr/local/cuda \
    PATH=/opt/conda/bin:$CUDA_HOME/bin:$PATH \
    LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH \
    TORCH_CUDA_ARCH_LIST="7.5;8.0;8.6;8.9;9.0" \
    MAX_JOBS=4

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    wget \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libxml2-dev \
    libxmlsec1-dev \
    libffi-dev \
    liblzma-dev \
    ninja-build \
    && rm -rf /var/lib/apt/lists/*

# Install Miniforge (no TOS issues)
RUN wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -O /tmp/miniforge.sh && \
    bash /tmp/miniforge.sh -b -p /opt/conda && \
    rm /tmp/miniforge.sh && \
    /opt/conda/bin/conda init bash

# Create conda environment
RUN /opt/conda/bin/conda create -n wallx python=3.10 -y && \
    echo "source activate wallx" >> ~/.bashrc

# Set working directory
WORKDIR /workspace/wall-x

# Copy project files
COPY requirements.txt .
COPY setup.py .
COPY pyproject.toml .
COPY csrc ./csrc
COPY 3rdparty ./3rdparty
COPY wall_x ./wall_x
COPY scripts ./scripts
COPY workspace ./workspace

# Install Python dependencies
SHELL ["/bin/bash", "-c"]
RUN source /opt/conda/bin/activate wallx && \
    pip install --no-cache-dir -r requirements.txt && \
    MAX_JOBS=4 pip install flash-attn==2.7.4.post1 --no-build-isolation

# Install LeRobot
RUN source /opt/conda/bin/activate wallx && \
    git clone https://github.com/huggingface/lerobot.git /tmp/lerobot && \
    cd /tmp/lerobot && \
    pip install -e . && \
    cd /workspace/wall-x

# Install Wall-X with CUDA extensions
RUN source /opt/conda/bin/activate wallx && \
    git submodule update --init --recursive && \
    MAX_JOBS=4 pip install --no-build-isolation --verbose .

# Expose ports (for potential Jupyter/TensorBoard)
EXPOSE 8888 6006

# Set default command
CMD ["/bin/bash", "-c", "source /opt/conda/bin/activate wallx && /bin/bash"]