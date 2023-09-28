#!/bin/bash
cd "$HOME"

# Configure git
echo '========== BEGIN: Configure git =========='
mkdir -p ~/.ssh
ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts
git config --global credential.useHttpPath true
[ -n "${git_config_auto_user_name}" ] && git config --global user.name "${git_config_auto_user_name}"
[ -n "${git_config_auto_user_email}" ] && git config --global user.email "${git_config_auto_user_email}"
echo '========== END: Configure git =========='


# Start postgres
# NOTE: If a db already exist, its "psql create database" command will fail; that's ok!
# sudo chown -R ${postgres_user}:${postgres_user} /var/lib/postgresql
psql -c "alter user postgres with password '${postgres_password}'"
%{ for dbname in postgres_dbs_to_create ~}
psql -c "create database ${dbname}"
%{ endfor ~}


# Install NVM
curl -sSL -o- ${nvm_install_script_url} | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm


# Prepare development repo
if [[ ! -d "./${git_repo_name}" ]]; then
  git clone ${git_clone_url}
  git -C ./${git_repo_name} checkout ${git_checkout_branch} 2> /dev/null || git -C ./${git_repo_name} checkout -b ${git_checkout_branch} ${git_base_branch}
fi


# Configure ${git_repo_name} .env files
pushd ./${git_repo_name}
cp ./packages/server/.env.example ./packages/server/.env
%{ for ev, dbname in postgres_envvar_dbname_map ~}
sed -i 's|${ev}=.*|${ev}=postgres://${postgres_user}:${postgres_password}@localhost:5432/${dbname}|' ./packages/server/.env
%{ endfor ~}
sed -i 's|WEBSITE_DOMAIN=.*|WEBSITE_DOMAIN=${website_url}|' ./packages/server/.env
sed -i 's|API_DOMAIN=.*|API_DOMAIN=${gost_api_url}|' ./packages/server/.env
sed -i 's|AWS_ACCESS_KEY_ID=.*|AWS_ACCESS_KEY_ID=test|' ./packages/server/.env
sed -i 's|AWS_SECRET_ACCESS_KEY=.*|AWS_SECRET_ACCESS_KEY=test|' ./packages/server/.env
sed -i 's|NODEMAILER_HOST=.*|NODEMAILER_HOST=""|' ./packages/server/.env
cp ./packages/client/.env.example ./packages/client/.env
echo 'VUE_ALLOWED_HOSTS=all' >> ./packages/client/.env
popd


# Configure preferred shell
sudo chsh -s $(which "${preferred_shell}") $(whoami)
if [[ "${preferred_shell}" == "zsh" && ! -d "$HOME/.oh-my-zsh/" ]]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended"
  zsh -c '${oh_my_zsh_plugins_cmd}'
fi


# Add local binaries directory to $PATH
mkdir -p "$HOME/.local/bin"
if ! grep -qxF 'export PATH=$PATH:$HOME/.local/bin' "$HOME/.${preferred_shell}rc" ; then
  echo 'export PATH=$PATH:$HOME/.local/bin' >> "$HOME/.${preferred_shell}rc"
fi
if [[ "$PATH" != *"$HOME/.local/bin"* ]]; then
  export PATH=$PATH:$HOME/.local/bin
fi


# Use coder CLI to clone and install dotfiles TODO
# coder dotfiles -y ${dotfiles_uri} &


# Start code-server
code-server --auth none --port 13337 "$HOME/${git_repo_name}" > /tmp/code-server.log 2>&1 &
SERVICE_URL=https://open-vsx.org/vscode/gallery ITEM_URL=https://open-vsx.org/vscode/item code-server \
  %{ for ext in vscode_extensions ~} --install-extension "${ext}" %{ endfor }


# Install Node dependencies
pushd ./${git_repo_name}
export CI=1
nvm install || echo "Already installed"
npm install -g yarn
if [[ "${yarn_network_timeout}" != "0" ]]; then
  echo "Configuring yarn network-timeout"
  yarn config set network-timeout ${yarn_network_timeout} -g
fi
yarn run setup
yarn install --frozen-lockfile
unset CI
popd

# Start localstack and install localstack helpers
python3 -m pip install localstack
localstack wait -t 2 2> /dev/null || localstack start --detached --no-banner
chmod +x ${git_repo_name}/localstack/entrypoint/init-aws.sh
pip install "awscli-local" "terraform-local"
localstack wait && ${git_repo_name}/localstack/entrypoint/init-aws.sh
