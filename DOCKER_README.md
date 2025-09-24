# WALL-X Docker 部署指南

## 📋 系统要求

### 硬件要求
- **GPU**: NVIDIA GPU (计算能力 7.5+)
  - 单 GPU 训练: 48GB+ VRAM (RTX 6000 Ada, A6000)
  - 多 GPU 训练: 8x GPU 推荐 (启用 FSDP2)
- **内存**: 64GB+ 系统内存
- **存储**: 100GB+ 可用空间

### 软件要求
- **操作系统**: Ubuntu 22.04 / 20.04 / RHEL 8+
- **Docker**: 24.0+
- **NVIDIA Driver**: 535+ (支持 CUDA 12.4)
- **nvidia-docker2** 或 **NVIDIA Container Toolkit**

## 🚀 快速开始

### 1. 安装 NVIDIA Container Toolkit

```bash
# Ubuntu/Debian
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt-get update
sudo apt-get install -y nvidia-docker2
sudo systemctl restart docker
```

### 2. 验证 GPU 访问

```bash
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
```

### 3. 构建 Docker 镜像

```bash
# 克隆仓库
git clone <your-wall-x-repo>
cd wall-x

# 构建镜像 (需要 20-30 分钟)
docker build -t wall-x:latest .

# 或使用 docker-compose
docker-compose build
```

### 4. 准备数据和模型

```bash
# 创建必要目录
mkdir -p workspace data checkpoints

# 下载预训练模型 (选择一个)
# WALL-OSS-FLOW
git clone https://huggingface.co/x-square-robot/wall-oss-flow ./checkpoints/wall-oss-flow

# WALL-OSS-FAST
git clone https://huggingface.co/x-square-robot/wall-oss-fast ./checkpoints/wall-oss-fast

# (可选) 下载 FAST tokenizer
git clone https://huggingface.co/physical-intelligence/fast ./checkpoints/fast
```

### 5. 启动容器

#### 方法 A: 使用 docker-compose (推荐)

```bash
docker-compose up -d
docker-compose exec wall-x bash
```

#### 方法 B: 使用 docker run

```bash
docker run -it --rm \
  --gpus all \
  --shm-size=32g \
  --ipc=host \
  -v $(pwd)/workspace:/workspace/wall-x/workspace \
  -v $(pwd)/data:/workspace/wall-x/data \
  -v $(pwd)/checkpoints:/workspace/wall-x/checkpoints \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  wall-x:latest
```

## 🔧 配置训练

### 1. 更新配置文件

在容器内修改配置:

```bash
cd /workspace/wall-x/workspace/lerobot_example
vim config_qact.yml
```

必须修改的路径:
```yaml
pretrained_wallx_path: "/workspace/wall-x/checkpoints/wall-oss-flow"
save_path: "/workspace/wall-x/workspace/outputs"
use_fast_tokenizer: false
action_tokenizer_path: "/workspace/wall-x/checkpoints/fast"  # 如使用 FAST
```

### 2. 更新运行脚本

```bash
vim run.sh
```

设置正确的路径:
```bash
code_dir="/workspace/wall-x"
config_path="/workspace/wall-x/workspace/lerobot_example/config_qact.yml"
```

### 3. 启动训练

```bash
# 在容器内执行
source activate wallx
bash ./run.sh
```

## 📊 GPU 使用建议

### 单 GPU (48GB+ VRAM)
```bash
CUDA_VISIBLE_DEVICES=0 bash run.sh
```

配置:
```yaml
batch_size_per_gpu: 1
FSDP2: false
torch_compile: false
```

### 多 GPU (8x GPU, 推荐)
```bash
CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 bash run.sh
```

配置:
```yaml
batch_size_per_gpu: 1
FSDP2: true
torch_compile: false  # 除非确保数据形状一致
```

## 🧪 测试推理

### 1. 基础动作推理

```bash
source activate wallx
python ./scripts/fake_inference.py
```

### 2. 开环评估

```bash
python ./scripts/draw_openloop_plot.py
```

### 3. VQA 和思维链测试

```bash
python ./scripts/vqa_inference.py
```

## 🐛 常见问题

### Q1: CUDA 内存不足
**解决方案**:
- 减小 `batch_size_per_gpu`
- 启用 FSDP2 (多 GPU)
- 增加 `gradient_accumulation_steps`

### Q2: Flash-Attention 编译失败
**解决方案**:
```bash
# 在 Dockerfile 中调整 MAX_JOBS
ENV MAX_JOBS=2  # 降低并行编译数
```

### Q3: CUDA 版本不匹配
**检查**:
```bash
nvidia-smi  # 查看驱动支持的 CUDA 版本
nvcc --version  # 查看容器内 CUDA 版本
```

### Q4: 容器内无法访问 GPU
**解决方案**:
```bash
# 确保安装了 nvidia-docker2
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi

# 重启 Docker 服务
sudo systemctl restart docker
```

## 📦 数据持久化

容器使用卷挂载保持数据持久化:

```bash
宿主机                          → 容器内
./workspace                     → /workspace/wall-x/workspace
./data                          → /workspace/wall-x/data
./checkpoints                   → /workspace/wall-x/checkpoints
~/.cache/huggingface            → /root/.cache/huggingface
```

## 🔄 更新代码

```bash
# 停止容器
docker-compose down

# 拉取最新代码
git pull

# 重新构建镜像
docker-compose build

# 重新启动
docker-compose up -d
```

## 📝 日志和监控

### 查看训练日志
```bash
# 实时查看
docker-compose logs -f wall-x

# 或在容器内
tail -f /workspace/wall-x/workspace/outputs/training.log
```

### 监控 GPU 使用
```bash
# 宿主机上
watch -n 1 nvidia-smi

# 容器内
watch -n 1 nvidia-smi
```

## 🛠️ 高级配置

### 自定义 CUDA 架构

修改 Dockerfile:
```dockerfile
ENV TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0"  # 根据你的 GPU
```

### 使用多节点训练

需要配置 Docker Swarm 或 Kubernetes。参考 PyTorch 分布式训练文档。

### 开发模式

挂载源代码以便实时修改:
```bash
docker run -it --rm \
  --gpus all \
  -v $(pwd):/workspace/wall-x \
  wall-x:latest
```

## 📚 参考资源

- [NVIDIA Container Toolkit 文档](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/)
- [Docker GPU 支持](https://docs.docker.com/config/containers/resource_constraints/#gpu)
- [PyTorch Docker 镜像](https://hub.docker.com/r/pytorch/pytorch)
- [WALL-X 项目主页](https://x2robot.com/en/research/68bc2cde8497d7f238dde690)