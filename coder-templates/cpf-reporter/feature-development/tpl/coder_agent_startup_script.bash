#!/bin/bash
cd "$HOME"

# Configure git
echo '========== BEGIN: Configure git =========='
mkdir -p "$HOME/.ssh"
ssh-keyscan -t ed25519 github.com >> "$HOME/.ssh/known_hosts"
git config --global credential.useHttpPath true
[ -n "${git_config_auto_user_name}" ] && git config --global user.name "${git_config_auto_user_name}"
[ -n "${git_config_auto_user_email}" ] && git config --global user.email "${git_config_auto_user_email}"
echo '========== END: Configure git =========='


# Set up postgres
echo '========== BEGIN: Set up postgres =========='
# NOTE: If a db already exist, its "psql create database" command will fail; that's ok!
psql -c "alter user postgres with password '${postgres_password}'"
%{ for dbname in postgres_dbs_to_create ~}
psql -c "create database ${dbname}"
%{ endfor ~}
echo '========== END: Set up postgres =========='


# Install NVM
echo '========== BEGIN: Install NVM =========='
curl -sSL -o- ${nvm_install_script_url} | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
echo '========== END: Install NVM =========='


# Prepare development repo
echo '========== BEGIN: Clone repo =========='
if [[ ! -d "./${git_repo_name}" ]]; then
  git clone ${git_clone_url}
  git -C ./${git_repo_name} checkout ${git_checkout_branch} 2> /dev/null || git -C ./${git_repo_name} checkout -b ${git_checkout_branch} ${git_base_branch}
fi
echo '========== END: Clone repo =========='


# Populate ${git_repo_name} .env file
echo '========== BEGIN: Populate ${git_repo_name} .env file =========='
pushd ./${git_repo_name}
if [[ ! -f './.env' ]]; then
  %{ for ev, dbname in postgres_envvar_dbname_map ~}
  echo '${ev}=postgres://${postgres_user}:${postgres_password}@localhost:5432/${dbname}' >> .env
  %{ endfor ~}
  echo "WEBHOOK_SECRET=$(openssl rand -base64 2000 | head -c 64)" >> .env
  echo 'AWS_ACCESS_KEY_ID=test' >> .env
  echo 'AWS_SECRET_ACCESS_KEY=test' >> .env
  echo 'AWS_REGION=us-west-2' >> .env
  echo 'AWS_DEFAULT_REGION=us-west-2' >> .env
fi
popd
echo '========== END: Populate ${git_repo_name} .env file =========='


# Configure preferred shell
echo '========== BEGIN: Configure preferred shell (${preferred_shell}) =========='
sudo chsh -s $(which "${preferred_shell}") $(whoami)
if [[ "${preferred_shell}" == "zsh" && ! -d "$HOME/.oh-my-zsh/" ]]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended"
  [ -n "${oh_my_zsh_plugins}" ] && zsh -c 'source .zshrc && omz plugin enable ${oh_my_zsh_plugins}'
  mkdir -p "$HOME/.oh-my-zsh/completions"
fi
if [[ "${preferred_shell}" == "bash" && ! -f "$HOME/.bash_profile" ]]; then
  echo 'source /etc/profile.d/bash_completion.sh' >> "$HOME/.bash_profile"
  echo "complete -C '/usr/local/bin/aws_completer' aws" >> "$HOME/.bash_profile"
  echo 'source "$HOME/.bash_profile"' >> "$HOME/.bashrc"
fi
echo '========== END: Configure preferred shell (${preferred_shell}) =========='


# Add local binaries directory to $PATH
echo '========== BEGIN: Add local binaries directory to $PATH =========='
mkdir -p "$HOME/.local/bin"
if ! grep -qxF 'export PATH=$PATH:$HOME/.local/bin' "$HOME/.${preferred_shell}rc" ; then
  echo 'export PATH=$PATH:$HOME/.local/bin' >> "$HOME/.${preferred_shell}rc"
fi
if [[ "$PATH" != *"$HOME/.local/bin"* ]]; then
  export PATH=$PATH:$HOME/.local/bin
fi
command -v fd > /dev/null || test -f "$HOME/.local/bin/fd" || ln -s $(which fdfind) "$HOME/.local/bin/fd"
echo '========== END: Add local binaries directory to $PATH =========='


# Install terraform with tfvm (Terraform version manager)
echo '========== BEGIN: Install terraform with tfvm (Terraform version manager) =========='
command -v tfvm || curl -sL https://raw.githubusercontent.com/cbuschka/tfvm/main/install.sh -o - | bash
# TODO
# pushd "$HOME/${git_repo_name}/terraform"
# tfvm install
#popd
echo '========== END: Install terraform with tfvm (Terraform version manager) =========='


# Use coder CLI to clone and install dotfiles TODO
echo '========== BEGIN: Configure dotfiles =========='
# coder dotfiles -y ${dotfiles_uri} &
echo '========== END: Configure dotfiles =========='


# Start code-server
echo '========== BEGIN: Start code-server =========='
code-server --auth none --port 13337 "$HOME/${git_repo_name}" > /tmp/code-server.log 2>&1 &
SERVICE_URL=https://open-vsx.org/vscode/gallery ITEM_URL=https://open-vsx.org/vscode/item code-server \
  %{ for ext in vscode_extensions ~} --install-extension "${ext}" %{ endfor }
echo '========== END: Start code-server =========='


# Install Node dependencies
echo '========== BEGIN: Install Node dependencies =========='
pushd ./${git_repo_name}
export CI=1
[ -f .nvmrc ] || echo 'v18' > .nvmrc
nvm install || echo "Correct Node version is already installed"
corepack enable
corepack prepare yarn@3.7.0 --activate
if [[ "${yarn_network_timeout}" != "0" ]]; then
  echo "Configuring yarn network-timeout"
  yarn config set network-timeout ${yarn_network_timeout} -g
fi
yarn install --frozen-lockfile
unset CI
popd
echo '========== END: Install Node dependencies =========='


# Start localstack and install localstack helpers
echo '========== BEGIN: Start localstack =========='
python3 -m pip install localstack
localstack wait -t 2 2> /dev/null || localstack start --detached --no-banner
chmod +x ${git_repo_name}/localstack/entrypoint/init-aws.sh
pip install "awscli-local" "terraform-local"
localstack wait && ${git_repo_name}/localstack/entrypoint/init-aws.sh
echo '========== END: Start localstack =========='


echo "All done!"
