FROM debian:bookworm

SHELL ["/bin/bash", "-c"]

# Install apt repositories
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get upgrade --yes && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes apt-utils ca-certificates curl gnupg wget
RUN install -m 0755 -d /etc/apt/keyrings
COPY docker-archive-keyring.gpg /tmp/docker-archive-keyring.gpg
RUN gpg --dearmor -o /etc/apt/keyrings/docker.gpg < /tmp/docker-archive-keyring.gpg
RUN chmod a+r /etc/apt/keyrings/docker.gpg
RUN echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN rm /tmp/docker-archive-keyring.gpg
COPY hashicorp-archive-keyring.gpg /tmp/hashicorp-archive-keyring.gpg
RUN gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg < /tmp/hashicorp-archive-keyring.gpg
RUN gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo "$VERSION_CODENAME") main" | tee /etc/apt/sources.list.d/hashicorp.list
RUN rm /tmp/hashicorp-archive-keyring.gpg

# Install baseline packages
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
      bash \
      build-essential \
      ca-certificates \
      containerd.io \
      docker-ce \
      docker-ce-cli \
      docker-buildx-plugin \
      docker-compose-plugin \
      git \
      gnupg \
      gnupg1 \
      gnupg2 \
      htop \
      jq \
      locales \
      man \
      python3 \
      python3-pip \
      rsync \
      screen \
      software-properties-common \
      sudo \
      systemd \
      systemd-sysv \
      terraform \
      tmux \
      unzip \
      vim \
      wget \
      zsh

# Enables Docker starting with systemd
RUN systemctl enable docker

# Add docker-compose
RUN curl -L "https://github.com/docker/compose/releases/download/v2.16.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
RUN chmod +x /usr/local/bin/docker-compose

# Make typing unicode characters in the terminal work.
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
RUN locale-gen --purge "en_US.UTF-8"
RUN update-locale "LANG=en_US.UTF-8"
RUN dpkg-reconfigure --frontend noninteractive locales

# Add a user `coder` so that you're not developing as the `root` user
RUN useradd coder \
      --create-home \
      --shell=/bin/bash \
      --groups=docker \
      --uid=1000 \
      --user-group && \
    echo "coder ALL=(ALL) NOPASSWD:ALL" >>/etc/sudoers.d/nopasswd

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

# Install Taskfile
RUN sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin
RUN curl https://raw.githubusercontent.com/go-task/task/main/completion/zsh/_task --create-dirs -o /usr/local/share/zsh/site-functions/_task
RUN curl https://raw.githubusercontent.com/go-task/task/main/completion/bash/task.bash --create-dirs -o /usr/share/bash-completion/completions/task.bash
RUN chmod +x /usr/share/bash-completion/completions/task.bash

USER coder

# Install code-server
RUN sh -c 'curl -fsSL https://code-server.dev/install.sh | sh'
