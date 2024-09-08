#!/bin/bash

# Цветовые переменные
BOLD='\033[1m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
CYAN='\033[36m'
NC='\033[0m'

# Обновление и установка необходимых пакетов
echo -e "${BOLD}${YELLOW}Updating and installing required packages...${NC}"
sudo apt update && sudo apt upgrade -y && sleep 1
sudo apt install -y curl tar cargo wget clang pkg-config protobuf-compiler libssl-dev jq build-essential bsdmainutils git make ncdu gcc chrony liblz4-tool cmake && sleep 1
sudo apt -qy upgrade -y
sudo apt install jq -y

# Установка Go
echo -e "${BOLD}${YELLOW}Installing Go...${NC}"
sudo rm -rf /usr/local/go
curl -L https://go.dev/dl/go1.21.6.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
source $HOME/.bash_profile
go version

# Установка Rustup
echo -e "${BOLD}${YELLOW}Installing Rustup...${NC}"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Установка бинарного файла
echo -e "${BOLD}${YELLOW}Cloning 0G Storage Node repository...${NC}"
git clone -b v0.4.6 https://github.com/0glabs/0g-storage-node.git
cd 0g-storage-node
git submodule update --init
cargo build --release
sudo cp $HOME/0g-storage-node/target/release/zgs_node /usr/local/bin
cd $HOME

# Установка переменной RPC
echo -e "${BOLD}${CYAN}Setting RPC environment variables...${NC}"
echo 'export NETWORK_LISTEN_ADDRESS="$(wget -qO- eth0.me)"' >> ~/.bash_profile
echo 'export BLOCKCHAIN_RPC_ENDPOINT="https://archive-0g.josephtran.xyz"' >> ~/.bash_profile
source ~/.bash_profile

# Установка конфигурации
echo -e "${BOLD}${CYAN}Configuring the node...${NC}"
sed -i '
s|^\s*#\s*network_dir = "network"|network_dir = "network"|
s|^\s*#\s*rpc_enabled = true|rpc_enabled = true|
s|^\s*#\s*network_listen_address = "0.0.0.0"|network_listen_address = "'"$NETWORK_LISTEN_ADDRESS"'"|
s|^\s*#\s*network_libp2p_port = 1234|network_libp2p_port = 1234|
s|^\s*#\s*network_discovery_port = 1234|network_discovery_port = 1234|
s|^\s*#\s*blockchain_rpc_endpoint = "http://127.0.0.1:8545"|blockchain_rpc_endpoint = "'"$BLOCKCHAIN_RPC_ENDPOINT"'"|
s|^\s*#\s*log_contract_address = ""|log_contract_address = "0xbD2C3F0E65eDF5582141C35969d66e34629cC768"|
s|^\s*#\s*log_sync_start_block_number = 0|log_sync_start_block_number = 595059|
s|^\s*#\s*rpc_listen_address = "0.0.0.0:5678"|rpc_listen_address = "0.0.0.0:5678"|
s|^\s*#\s*mine_contract_address = ""|mine_contract_address = "0x6815F41019255e00D6F34aAB8397a6Af5b6D806f"|
s|^\s*#\s*miner_key = ""|miner_key = ""|
' $HOME/0g-storage-node/run/config.toml

# Ввод приватного ключа
read -p "Enter your private key: " PRIVATE_KEY
sed -i 's|^miner_key = ""|miner_key = "'"$PRIVATE_KEY"'"|' $HOME/0g-storage-node/run/config.toml

# Установка снапшота
echo -e "${BOLD}${CYAN}Installing snapshot...${NC}"
sudo systemctl stop zgs
sudo apt-get update
sudo apt-get install wget lz4 aria2 pv -y
aria2c -x5 -s4 https://vps5.josephtran.xyz/0g/storage_0gchain_snapshot.lz4
lz4 -c -d storage_0gchain_snapshot.lz4 | pv | tar -x -C $HOME/0g-storage-node/run

# Создание сервисного файла
echo -e "${BOLD}${CYAN}Creating systemd service file...${NC}"
sudo tee /etc/systemd/system/zgs.service > /dev/null <<EOF
[Unit]
Description=0G Storage Node
After=network.target

[Service]
User=$USER
Type=simple
WorkingDirectory=$HOME/0g-storage-node/run
ExecStart=$HOME/0g-storage-node/target/release/zgs_node --config $HOME/0g-storage-node/run/config.toml
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# Запуск ноды
echo -e "${BOLD}${CYAN}Starting the node...${NC}"
sudo systemctl daemon-reload
sudo systemctl enable zgs
sudo systemctl restart zgs
sudo systemctl status zgs

# Проверка блоков
echo -e "${BOLD}${CYAN}Monitoring block synchronization...${NC}"
while true; do 
    response=$(curl -s -X POST http://localhost:5678 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"zgs_getStatus","params":[],"id":1}')
    logSyncHeight=$(echo $response | jq '.result.logSyncHeight')
    connectedPeers=$(echo $response | jq '.result.connectedPeers')
    echo -e "logSyncHeight: \033[32m$logSyncHeight\033[0m, connectedPeers: \033[34m$connectedPeers\033[0m"
    sleep 5; 
done