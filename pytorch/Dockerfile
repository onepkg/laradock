FROM pytorch/pytorch:2.10.0-cuda13.0-cudnn9-runtime

# https://developer.nvidia.com/cuda-downloads?target_os=Linux&target_arch=x86_64&Distribution=WSL-Ubuntu&target_version=2.0&target_type=deb_local

RUN apt-get update
RUN apt-get install -y \
    # 字体
    fonts-wqy-zenhei \
    fonts-wqy-microhei \
    ttf-wqy-zenhei \
    ttf-wqy-microhei \
    fonts-arphic-ukai \
    fonts-arphic-uming \
    fonts-noto-cjk \
    && rm -rf /var/lib/apt/lists/*
RUN fc-cache -fv

# 设置环境变量允许破坏系统包
ENV PIP_BREAK_SYSTEM_PACKAGES=1

# 安装 Python 依赖
RUN pip install --no-cache-dir \
    matplotlib \
    seaborn \
    scikit-learn \
    jupyter

WORKDIR /app

EXPOSE 8888

CMD ["jupyter", "notebook", \
     "--ip=0.0.0.0", \
     "--port=8888", \
     "--no-browser", \
     "--allow-root", \
     "--NotebookApp.token=''", \
     "--NotebookApp.password=''"]
