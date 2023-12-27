FROM codercom/enterprise-base:ubuntu

USER root

RUN apt update

ENV LC_ALL="en_US.UTF-8"
RUN locale-gen --purge "en_US.UTF-8"
RUN update-locale "LANG=en_US.UTF-8"
RUN dpkg-reconfigure --frontend noninteractive locales

RUN apt install bash-completion fd-find gnupg gnupg1 gnupg2 iproute2 jq postgresql-client ripgrep screen tmux zsh -y

# Install AWS CLI
RUN mkdir -p /tmp/awscli
COPY aws-public-key.gpg /tmp/awscli/key.gpg
RUN gpg --import /tmp/awscli/key.gpg
RUN sh -c 'curl -o "/tmp/awscli/awscliv2.sig" https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip.sig'
RUN sh -c 'curl -o "/tmp/awscli/awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip"'
RUN gpg --verify /tmp/awscli/awscliv2.sig /tmp/awscli/awscliv2.zip
RUN unzip -u -d /tmp/awscli/ /tmp/awscli/awscliv2.zip
RUN sudo /tmp/awscli/aws/install
RUN aws --version
RUN rm -rf /tmp/awscli

# Install tflint
RUN curl -s 'https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh' | bash

USER coder

# Install code-server
RUN sh -c 'curl -fsSL https://code-server.dev/install.sh | sh'
