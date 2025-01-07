#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# 初始端口
START_PORT=2222

# 检查docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker未安装！正在安装...${NC}"
        
        # 检查系统类型
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$NAME
        fi
        
        case $OS in
            "Ubuntu")
                # 添加Docker官方GPG密钥
                sudo apt-get update
                sudo apt-get install -y ca-certificates curl gnupg
                sudo install -m 0755 -d /etc/apt/keyrings
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
                sudo chmod a+r /etc/apt/keyrings/docker.gpg
                
                # 添加Docker官方仓库
                echo \
                "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
                "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
                sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                
                # 安装Docker
                sudo apt-get update
                sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                ;;
                
            "CentOS Linux" | "Red Hat Enterprise Linux")
                # 安装必要的包
                sudo yum install -y yum-utils
                
                # 添加Docker仓库
                sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                
                # 安装Docker
                sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                ;;
                
            *)
                echo -e "${RED}不支持的操作系统！请手动安装Docker${NC}"
                exit 1
                ;;
        esac
        
        # 启动Docker服务
        sudo systemctl start docker
        sudo systemctl enable docker
        
        # 添加当前用户到docker组
        sudo usermod -aG docker $USER
        
        echo -e "${GREEN}Docker安装完成！${NC}"
        echo -e "${BLUE}请重新登录以应用组权限更改${NC}"
        
        # 等待Docker服务完全启动
        sleep 5
    else
        echo -e "${GREEN}Docker已安装${NC}"
    fi
    
    # 检查Docker服务状态
    if ! sudo systemctl is-active --quiet docker; then
        echo -e "${RED}Docker服务未运行，正在启动...${NC}"
        sudo systemctl start docker
    fi
}

# 创建新容器
create_container() {
    echo -e "${BLUE}创建新的Ubuntu容器${NC}"
    read -p "请输入容器名称: " container_name
    
    # 修改端口检查逻辑，使用 ss 命令替代 netstat
    while true; do
        if ! ss -tuln | grep ":$START_PORT " > /dev/null; then
            break
        fi
        START_PORT=$((START_PORT + 1))
    done
    
    # 或者使用 lsof 检查端口（如果系统有 lsof）
    # while true; do
    #     if ! lsof -i :$START_PORT > /dev/null 2>&1; then
    #         break
    #     fi
    #     START_PORT=$((START_PORT + 1))
    # done
    
    # 生成随机密码
    root_password=$(openssl rand -base64 12)
    
    echo -e "${BLUE}正在创建容器...${NC}"
    
    # 创建容器
    docker run -d \
        --name $container_name \
        --network host \
        --restart unless-stopped \
        ubuntu:22.04 \
        tail -f /dev/null
        
    # 等待容器完全启动
    sleep 3
    
    # 首先安装基本工具
    docker exec $container_name apt-get update
    docker exec $container_name apt-get install -y iproute2 net-tools iputils-ping
    
    # 安装必要的包，添加语言支持
    docker exec $container_name apt-get install -y \
        openssh-server \
        sudo \
        vim \
        curl \
        wget \
        git \
        language-pack-zh-hans \
        locales \
        fonts-noto-cjk
    
    # 配置中文支持
    docker exec $container_name locale-gen zh_CN.UTF-8
    docker exec $container_name update-locale LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8
    
    # 配置SSH和SFTP
    docker exec $container_name mkdir -p /run/sshd
    docker exec $container_name bash -c "cat > /etc/ssh/sshd_config << 'EOL'
Port $START_PORT
PermitRootLogin yes
Subsystem sftp internal-sftp
UsePAM yes
X11Forwarding yes
PrintMotd no
AcceptEnv LANG LC_*
EOL"
    
    # 设置root密码
    docker exec $container_name bash -c "echo 'root:$root_password' | chpasswd"
    
    # 设置环境变量
    docker exec $container_name bash -c "cat >> /root/.bashrc << 'EOL'
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
export LANGUAGE=zh_CN:en_US
EOL"
    
    # 启动SSH服务
    docker exec $container_name service ssh restart
    
    echo -e "${GREEN}容器创建成功！${NC}"
    echo -e "容器名称: ${GREEN}$container_name${NC}"
    echo -e "SSH端口: ${GREEN}$START_PORT${NC}"
    echo -e "Root密码: ${GREEN}$root_password${NC}"
    echo -e "连接命令: ${GREEN}ssh root@<服务器IP> -p $START_PORT${NC}"
    echo -e "SFTP命令: ${GREEN}sftp -P $START_PORT root@<服务器IP>${NC}"
    
    # 保存容器信息
    echo "$container_name,$START_PORT,$root_password" >> container_info.csv
}

# 管理用户
manage_users() {
    echo -e "${BLUE}容器用户管理${NC}"
    echo "可用的容器："
    docker ps --format "{{.Names}}"
    
    read -p "请输入容器名称: " container_name
    
    echo "1. 添加用户"
    echo "2. 删除用户"
    read -p "请选择操作 (1/2): " choice
    
    read -p "请输入用户名: " username
    
    case $choice in
        1)
            password=$(openssl rand -base64 12)
            docker exec $container_name useradd -m -s /bin/bash $username
            docker exec $container_name bash -c "echo '$username:$password' | chpasswd"
            docker exec $container_name usermod -aG sudo $username
            echo -e "${GREEN}用户创建成功！${NC}"
            echo -e "用户名: ${GREEN}$username${NC}"
            echo -e "密码: ${GREEN}$password${NC}"
            ;;
        2)
            docker exec $container_name userdel -r $username
            echo -e "${GREEN}用户已删除${NC}"
            ;;
        *)
            echo -e "${RED}无效的选择${NC}"
            ;;
    esac
}

# 查看容器信息
list_containers() {
    echo -e "${BLUE}当前运行的容器：${NC}"
    docker ps --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}"
    
    if [ -f container_info.csv ]; then
        echo -e "\n${BLUE}容器访问信息：${NC}"
        echo "容器名称 | SSH端口 | Root密码"
        echo "------------------------"
        while IFS=, read -r name port pass; do
            echo "$name | $port | $pass"
        done < container_info.csv
    fi
}

# 删除容器
delete_container() {
    echo -e "${BLUE}删除容器${NC}"
    docker ps --format "{{.Names}}"
    read -p "请输入要删除的容器名称: " container_name
    
    docker stop $container_name
    docker rm $container_name
    
    # 从记录文件中删除
    if [ -f container_info.csv ]; then
        sed -i "/$container_name,/d" container_info.csv
    fi
    
    echo -e "${GREEN}容器已删除${NC}"
}

# 主菜单
main_menu() {
    # 显示logo
    echo -e "${GREEN}"
    cat << "EOF"
╭━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━-╮
┃                                                  ┃
┃   ██╗   ██╗████████╗ ██████╗ ██████╗ ██╗ █████╗  ┃
┃   ██║   ██║╚══██╔══╝██╔═══██╗██╔══██╗██║██╔══██╗ ┃
┃   ██║   ██║   ██║   ██║   ██║██████╔╝██║███████║ ┃
┃   ██║   ██║   ██║   ██║   ██║██╔═══╝ ██║██╔══██║ ┃
┃   ╚██████╔╝   ██║   ╚██████╔╝██║     ██║██║  ██║ ┃
┃    ╚═════╝    ╚═╝    ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝ ┃
┃                                                  ┃
┃        ╔═╗─╔╗╔═══╗╔════╗╔═══╗╔═══╗╔══╗╔═══╗      ┃
┃        ║║╚╗║║║╔═╗║║╔╗╔╗║║╔═╗║║╔═╗║╚╣─╝║╔═╗║      ┃
┃        ║╔╗╚╝║║║─║║╚╝║║╚╝║║─║║║╚═╝║─║║─║║─║║      ┃
┃        ║║╚╗║║║╚═╝║──║║──║║─║║║╔══╝─║║─║║─║║      ┃ 
┃        ║║─║║║║╔═╗║──║║──║╚═╝║║║───╔╣─╗║╚═╝║      ┃ 
┃        ╚╝─╚═╝╚╝─╚╝──╚╝──╚═══╝╚╝───╚══╝╚═══╝      ┃
┃                                                  ┃
┃            Solana多容器车队管理系统 v1.0            ┃
┃                  By: 乌托邦社区                    ┃
┃      TG交流群:https://t.me/xiaojiucaiPC           ┃
╰━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━-╯
EOF
    echo -e "${NC}"

    while true; do
        echo -e "\n${BLUE}=== 功能菜单 ===${NC}"
        echo "1. 创建新容器"
        echo "2. 管理用户"
        echo "3. 查看容器信息"
        echo "4. 删除容器"
        echo "5. 退出"
        
        read -p "请选择操作 (1-5): " choice
        
        case $choice in
            1) create_container ;;
            2) manage_users ;;
            3) list_containers ;;
            4) delete_container ;;
            5) exit 0 ;;
            *) echo -e "${RED}无效的选择${NC}" ;;
        esac
    done
}

# 检查Docker并启动主程序
check_docker
main_menu 