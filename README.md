# Solana 节点多容器管理脚本

这是一个专门为 Solana 节点和 GRPC 合租服务器设计的 Docker 容器管理脚本。通过创建独立的 Ubuntu 容器，实现用户隔离和私钥保护功能。

## 主要功能

- **安全隔离**：每个用户独立容器，保护私钥安全
- **自动配置**：自动设置 SSH/SFTP 访问
- **中文支持**：完整的中文环境配置
- **网络共享**：容器可访问宿主机 Solana 节点服务
- **用户管理**：便捷的用户添加和删除功能

## 使用场景

- Solana 节点合租服务器
- GRPC 服务共享
- 多用户私钥隔离
- 安全的远程访问管理

## 环境要求

- Linux 服务器（推荐 Ubuntu）
- Docker 环境（脚本会自动安装）
- 开放的 SSH 端口范围（默认从 2222 开始）

## 快速开始

1. **下载脚本**：
   ```bash
   wget https://raw.githubusercontent.com/your-repo/Solana_Sharing_script.sh
   chmod +x Solana_Sharing_script.sh
   ```

2. **运行脚本**：
   ```bash
   ./Solana_Sharing_script.sh
   ```

3. **创建容器**：
   - 选择选项 1
   - 输入容器名称（建议使用用户标识）
   - 获取自动分配的端口和密码

4. **连接方式**：
   ```bash
   # SSH 连接
   ssh root@<服务器IP> -p <分配的端口>
   
   # SFTP 连接
   sftp -P <分配的端口> root@<服务器IP>
   ```

## 安全特性

- 容器间完全隔离，保护用户私钥
- 独立的 SSH 访问端口
- 随机生成的强密码
- 共享网络但隔离文件系统

## 使用建议

- 为每个租户创建独立容器
- 定期备份 container_info.csv
- 建议使用强密码策略
- 监控容器资源使用情况

## 常见问题

1. **端口访问问题**
   - 检查防火墙设置
   - 确认端口未被占用

2. **中文显示问题**
   - 容器已预装中文支持
   - 可通过 LANG 环境变量调整

3. **网络访问问题**
   - 使用 host 网络模式
   - 可直接访问宿主机服务

## 技术支持

- TG 交流群：https://t.me/xiaojiucaiPC
- TG 交流群：https://t.me/chainbuff
- 问题反馈：提交 Issue
- 建议改进：欢迎 PR


## 免责声明

本脚本仅用于合法的服务器管理用途，用户需自行承担使用风险和责任。 