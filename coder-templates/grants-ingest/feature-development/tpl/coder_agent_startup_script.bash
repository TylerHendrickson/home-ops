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


# Prepare development repo
echo '========== BEGIN: Clone and checkout =========='
if [[ -d "$HOME/${git_repo_name}" ]]; then
  echo "Directory $HOME/${git_repo_name} already exists; skipping git clone and checkout."
else
  git clone "${git_clone_url}"
  git -C "$HOME/${git_repo_name}" checkout "${git_checkout_branch}" 2> /dev/null || git -C "$HOME/${git_repo_name}" checkout -b "${git_checkout_branch}" ${git_base_branch}
fi
echo '========== END: Clone and checkout =========='


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
echo '========== BEGIN: Add ~/.local/bin to PATH =========='
mkdir -p "$HOME/.local/bin"
ln -sf $(which fdfind) "$HOME/.local/bin/fd"
if ! grep -qxF 'export PATH=$PATH:$HOME/.local/bin' "$HOME/.${preferred_shell}rc" ; then
  echo 'export PATH=$PATH:$HOME/.local/bin' >> "$HOME/.${preferred_shell}rc"
fi
if [[ "$PATH" != *"$HOME/.local/bin"* ]]; then
  export PATH=$PATH:$HOME/.local/bin
fi
echo '========== END: Add ~/.local/bin to PATH =========='


# Install terraform with tfvm (Terraform version manager)
echo '========== BEGIN: Install terraform with tfvm (Terraform version manager) =========='
command -v tfvm || curl -sL https://raw.githubusercontent.com/cbuschka/tfvm/main/install.sh -o - | bash
pushd "$HOME/${git_repo_name}/terraform"
tfvm install
popd
echo '========== END: Install terraform with tfvm (Terraform version manager) =========='


# Use coder CLI to clone and install dotfiles TODO
echo '========== BEGIN: Configure dotfiles =========='
# coder dotfiles -y ${dotfiles_uri} &
echo '========== END: Configure dotfiles =========='


# Start code-server
echo '========== BEGIN: Start code-server =========='
code-server --auth none --port 13337 $HOME/${git_repo_name} > /tmp/code-server.log 2>&1 &
SERVICE_URL=https://open-vsx.org/vscode/gallery ITEM_URL=https://open-vsx.org/vscode/item code-server \
  %{ for ext in vscode_extensions ~} --install-extension "${ext}" %{ endfor }
echo '========== END: Start code-server =========='


# Install Go dependencies
echo '========== BEGIN: Install and cache Go dependencies =========='
echo 'This may take a moment on new workspaces, but should make things faster thereafter.'
cd "$HOME/${git_repo_name}"
go mod download
go list -export -test ./...
GO_BUILD_TMP=$(mktemp -d -p .)
go build -gcflags="-trimpath=$GOPATH" -ldflags="-s -w" -asmflags="-trimpath=$GOPATH" -trimpath -tags "lambda.norpc" -v -o "$GO_BUILD_TMP"
rm -rf "$GO_BUILD_TMP"
cd "$HOME"
echo '========== END: Install and cache Go dependencies =========='


# Start localstack and install localstack helpers
echo '========== BEGIN: Set up localstack =========='
python3 -m pip install -q localstack
localstack wait -t 2 2> /dev/null || localstack start --detached --no-banner
chmod +x ${git_repo_name}/localstack/entrypoint/init-aws.sh
pip install -q "awscli-local" "terraform-local"
localstack wait && ${git_repo_name}/localstack/entrypoint/init-aws.sh
echo '========== END: Set up localstack =========='

echo "All done!"
