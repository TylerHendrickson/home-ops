FROM codercom/enterprise-base:ubuntu

USER root

RUN apt update

ENV LC_ALL="en_US.UTF-8"
RUN locale-gen --purge "en_US.UTF-8"
RUN update-locale "LANG=en_US.UTF-8"
RUN dpkg-reconfigure --frontend noninteractive locales

RUN apt install iproute2 postgresql-client zsh jq tmux screen gnupg gnupg2 gnupg1 -y

RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
RUN sh -c 'echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list'
RUN apt update
RUN apt install terraform -y

USER coder

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

RUN sh -c 'curl -fsSL https://code-server.dev/install.sh | sh'
