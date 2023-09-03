#!/bin/bash
cd "$HOME"

# Add github.com to known_hosts
echo '===== Configuring GitHub SSH ====='
mkdir -p ~/.ssh
ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts


# Configure preferred shell
echo '===== Configuring preferred shell ====='
sudo chsh -s $(which "${preferred_shell}") $(whoami)
if [[ "${preferred_shell}" == "zsh" && ! -d "$HOME/.oh-my-zsh/" ]]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended"
  zsh -c '${oh_my_zsh_plugins_cmd}'
fi


# Add local binaries directory to $PATH
echo '===== Configuring $PATH ====='
mkdir -p "$HOME/.local/bin"
if ! grep -qxF 'export PATH=$PATH:$HOME/.local/bin' "$HOME/.${preferred_shell}rc" ; then
  echo 'export PATH=$PATH:$HOME/.local/bin' >> "$HOME/.${preferred_shell}rc"
fi
if [[ "$PATH" != *"$HOME/.local/bin"* ]]; then
  export PATH=$PATH:$HOME/.local/bin
fi


# Use coder CLI to clone and install dotfiles TODO
#echo '===== Configuring dotfiles ====='
# coder dotfiles -y ${dotfiles_uri} &


# Start code-server
echo '===== Starting code-server and installing extensions ====='
code-server --auth none --port 13337 "$HOME" > /tmp/code-server.log 2>&1 &
SERVICE_URL=https://open-vsx.org/vscode/gallery ITEM_URL=https://open-vsx.org/vscode/item code-server \
  %{ for ext in vscode_extensions ~} --install-extension "${ext}" %{ endfor }
