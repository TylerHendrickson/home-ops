#!/bin/bash
cd "$HOME"


# Add github.com to known_hosts
echo '===== BEGIN: Configure Git ====='
mkdir -p ~/.ssh
ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts
[ -n "${git_config_auto_user_name}" ] && git config --global user.name "${git_config_auto_user_name}"
[ -n "${git_config_auto_user_email}" ] && git config --global user.email "${git_config_auto_user_email}"
git config --global alias.unstage 'reset HEAD --'
git config --global alias.pr '!f() { if [ $# -lt 1 ]; then echo "Usage: git pr <id> [<remote>]  # assuming <remote>[=origin] is on GitHub"; else git checkout -q "$(git rev-parse --verify HEAD)" && git fetch -fv "$${2:-origin}" pull/"$1"/head:pr/"$1" && git checkout pr/"$1"; fi; }; f'
echo '===== END: Configure Git ====='


# Clone and checkout repo
echo '===== BEGIN: Clone and checkout repo ====='
if [[ ! -z "${git_clone_url}" && ! -d "$HOME/${git_repo_name}" ]]; then
  git clone ${git_clone_url}
  git -C ./${git_repo_name} checkout ${git_checkout_branch} 2> /dev/null || git -C ./${git_repo_name} checkout -b ${git_checkout_branch} ${git_checkout_base}
fi
echo '===== END: Clone and checkout repo ====='


# Ensure default working directory exists
echo '===== BEGIN: Ensure default working directory exists ====='
[ ! -d "${default_working_directory}" ] && mkdir -p "${default_working_directory}"
echo '===== END: Ensure default working directory exists ====='


# Configure preferred shell
echo '===== BEGIN: Configure preferred shell ====='
sudo chsh -s $(which "${preferred_shell}") $(whoami)
if [[ "${preferred_shell}" == "zsh" && ! -d "$HOME/.oh-my-zsh/" ]]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended"
  zsh -c '${oh_my_zsh_plugins_cmd}'
  mkdir -p "$HOME/.oh-my-zsh/completions"
  cp "$HOME/.default-completions/zsh/_task" "$HOME/.oh-my-zsh/completions/_task"
fi
if [[ "${preferred_shell}" == "bash" && ! -f "$HOME/.bash_profile" ]]; then
  echo 'source ~/.default-completions/task.bash' >> "$HOME/.bash_profile"
fi
echo '===== END: Configure preferred shell ====='


# Add local binaries directory to $PATH
echo '===== BEGIN: Configure $PATH ====='
mkdir -p "$HOME/.local/bin"
if ! grep -qxF 'export PATH=$PATH:$HOME/.local/bin' "$HOME/.${preferred_shell}rc" ; then
  echo 'export PATH=$PATH:$HOME/.local/bin' >> "$HOME/.${preferred_shell}rc"
fi
if [[ "$PATH" != *"$HOME/.local/bin"* ]]; then
  export PATH=$PATH:$HOME/.local/bin
fi
echo '===== END: Configure $PATH ====='


# Use coder CLI to clone and install dotfiles TODO
#echo '===== BEGIN: Configure dotfiles ====='
# coder dotfiles -y ${dotfiles_uri} &
#echo '===== END: Configure dotfiles ====='


# Start code-server
echo '===== BEGIN: Start code-server and install extensions ====='
code-server --auth none --port 13337 "$HOME" > /tmp/code-server.log 2>&1 &
SERVICE_URL=https://open-vsx.org/vscode/gallery ITEM_URL=https://open-vsx.org/vscode/item code-server \
  %{ for ext in vscode_extensions ~} --install-extension "${ext}" %{ endfor }
echo '===== END: Start code-server and install extensions ====='
