#!/bin/bash

# 1. 根据实际代理配置修改代理ip和端口
# 2. 在 ~/.bashrc 文件中加入下面代码
#   if [ -f ~/code/laradock/scripts/proxy.sh ]; then
#       source ~/code/laradock/scripts/proxy.sh
#   fi

# 开启代理
function proxy_on() {
    export http_proxy="http://127.0.0.1:20172"
    export https_proxy="http://127.0.0.1:20172"
    # export all_proxy="socks5://127.0.0.1:20170"
    echo "代理已开启"
}

# 关闭代理
function proxy_off() {
    unset http_proxy
    unset https_proxy
    unset all_proxy
    echo "代理已关闭"
}
