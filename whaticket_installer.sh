#!/bin/bash

source ./bash_loading_animations.sh
trap BLA::stop_loading_animation SIGINT

sudo apt update

install_docker() {
  start_animation_message "Installing docker" "${BLA_growing_dots[@]}"

  sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

  if [[ $(uname -m) == "x86_64" ]]; then
    ARCH="amd64"
  elif [[ $(uname -m) == "arm"* ]]; then
    if [[ $(uname -m) == *"armv7"* ]]; then
        ARCH="armhf"
    else
        ARCH="arm64"
    fi
  else
    echo "Architecture not supported, docker will not be installed."
    stop_loading_animation
    exit 1
  fi

  sudo add-apt-repository "deb [arch=$ARCH] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  sudo apt update

  sudo apt install -y docker-ce
  sudo usermod -aG docker $USER

  stop_loading_animation
  start_animation_message "Installing docker-compose" "${BLA_growing_dots[@]}"

  sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose

  if ! docker --version &> /dev/null; then
    echo "Error on Docker instalation."
    exit 1
  fi

  if ! docker-compose --version &> /dev/null; then
    echo "Error on Docker Compose instalation."
    exit 1
  fi

  stop_loading_animation
  echo "Docker and Docker Compose are installed."
}

install_nodejs_npm() {
  start_animation_message "Installing Node.js" "${BLA_growing_dots[@]}"

  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
  source ~/.bashrc

  nvm install node
  nvm alias default node

  if command -v node &>/dev/null; then
    echo "Node.js installed."
  else
    echo "Error on Node.js instalation."
    stop_loading_animation
    exit 1
  fi

  stop_loading_animation
}

git_clone_whaticket() {
  start_animation_message "Cloning Whaticket repository" "${BLA_growing_dots[@]}"

  local repository_url="https://github.com/canove/whaticket-community"
  local whaticket_dir="$HOME/whaticket"

  if [ -d "$whaticket_dir" ]; then
    echo "Whaticket directory already exists."
    return 1
  fi

  git clone "$repository_url" "$whaticket_dir"

  if [ $? -eq 0 ]; then
    echo "Repository cloned to '$whaticket_dir'."
  else
    echo "Error cloning repository."
    stop_loading_animation
    exit 1
  fi

  stop_loading_animation
}

create_whaticket_database() {
  start_animation_message "Creating whaticket database" "${BLA_growing_dots[@]}"

  docker run --name whaticketdb \
             -e MYSQL_ROOT_PASSWORD=password \
             -e MYSQL_DATABASE=whaticket \
             -e MYSQL_USER=user \
             -e MYSQL_PASSWORD=whaticket \
             --restart always \
             -p 3306:3306 \
             -d mariadb:latest \
             --character-set-server=utf8mb4 \
             --collation-server=utf8mb4_bin

  docker exec whaticketdb mysql -u user -pwhaticket -e "USE whaticket;" >/dev/null 2>&1

  if [ $? -eq 0 ]; then
    echo "The database WhaTicket is running."
  else
    echo "Error on running Whaticket database"
    stop_loading_animation
    exit 1
  fi

  stop_loading_animation
}

edit_wbot_ts() {
  start_animation_message "Editing wbot.ts" "${BLA_growing_dots[@]}"

  local wbot_file=~/whaticket/backend/src/libs/wbot.ts
  local temp_file=$(mktemp)

  if [ ! -f "$wbot_file" ]; then
    echo "File wbot.ts not in ~/whaticket/backend/src/libs/"
    stop_loading_animation
    exit 1
  fi

  cp "$wbot_file" "$temp_file"

  sed -i '48,57d' "$temp_file"
  cat <<EOF >> "$temp_file"
      const wbot: Session = new Client({
        session: sessionCfg,
        authStrategy: new LocalAuth({
          dataPath: "sessions"
        }),
        webVersionCache: {
          type: "remote",
          remotePath:
            "https://raw.githubusercontent.com/wppconnect-team/wa-version/main/html/2.2412.54.html"
        },
        puppeteer: {
          executablePath: process.env.CHROME_BIN || undefined,

          // @ts-ignore
          browserWSEndpoint: process.env.CHROME_WS || undefined,
          //args: args.split(' ')
          args: ["--no-sandbox", "--disable-setuid-sandbox"]
        }
      });
EOF

  mv "$temp_file" "$wbot_file"

  stop_loading_animation
  echo "wbot.ts edited with success"
}

create_whaticket_backend_env() {
  start_animation_message "Creating backend '.env'" "${BLA_growing_dots[@]}"

  local whaticket_dir=~/whaticket/backend
  local env_file=$whaticket_dir/.env

  if [ ! -d "$whaticket_dir" ]; then
    echo "Directory ~/whaticket/backend not found"
    stop_loading_animation
    exit 1
  fi

  cat <<EOF > "$env_file"
NODE_ENV=DEVELOPMENT
BACKEND_URL=http://localhost
FRONTEND_URL=http://localhost:3000
PROXY_PORT=8080
PORT=8080

DB_DIALECT=mysql
DB_HOST=localhost
DB_USER=root
DB_PASS=password
DB_NAME=whaticket

JWT_SECRET=
JWT_REFRESH_SECRET=
EOF

  stop_loading_animation
  echo "File .env created in ~/whaticket/backend/"
}

create_whaticket_frontend_env() {
  start_animation_message "Creating frontend '.env'" "${BLA_growing_dots[@]}"

  local frontend_dir=~/whaticket/frontend
  local env_example_file=$frontend_dir/.env.example
  local env_file=$frontend_dir/.env

  if [ ! -d "$frontend_dir" ]; then
    echo "Directory ~/whaticket/frontend not found."
    stop_loading_animation
    exit 1
  fi

  if [ ! -f "$env_example_file" ]; then
    echo "File .env.example not found in $frontend_dir"
    stop_loading_animation
    exit 1
  fi

  cp "$env_example_file" "$env_file"

  stop_loading_animation
  echo "File .env.example copied to .env in ~/whaticket/frontend/"
}

install_whaticket_dependencies() {
  start_animation_message "Installing backend and frontend node dependencies" "${BLA_growing_dots[@]}"

  local backend_dir=~/whaticket/backend
  local frontend_dir=~/whaticket/frontend

  if [ -d "$backend_dir" ]; then
    cd "$backend_dir" || exit 1
    npm install
    npm run build &>/dev/null || { echo "Error on building backend."; exit 1; }
    echo "Backend dependencies installed."
  else
    echo "Backend directory not found in $backend_dir"
  fi

  if [ -d "$frontend_dir" ]; then
    cd "$frontend_dir" || return 1
    npm install
    echo "Frontend dependencies installed."
  else
    echo "Frontend directory not found in $frontend_dir"
  fi

  stop_loading_animation
}

run_sequelize_commands() {
  start_animation_message "Running migrations and seeds" "${BLA_growing_dots[@]}"

  local backend_dir=~/whaticket/backend

  if [ -d "$backend_dir" ]; then
    cd "$backend_dir" || return 1
    npx sequelize db:migrate
    echo "Database migration succeed."

    npx sequelize db:seed:all
    echo "Database seed succeed."
  else
    echo "Backend directory not found in $backend_dir"
  fi
}


install_docker
install_nodejs_npm
git_clone_whaticket
create_whaticket_database
edit_wbot_ts
create_whaticket_backend_env
create_whaticket_frontend_env
install_whaticket_dependencies
run_sequelize_commands
