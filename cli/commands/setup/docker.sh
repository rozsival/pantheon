pantheon_setup_docker() {
  pantheon_prepare_setup_step 'Install Docker and Docker Compose.'

  pantheon_log_info 'Installing Docker and Docker Compose...'
  apt-get update
  apt-get install -y ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  # shellcheck source=/dev/null # the host's file, read at runtime
  tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
  apt-get update

  apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  if docker --version && docker compose version; then
    pantheon_log_success 'Docker installed.'
  else
    pantheon_log_error 'Docker installation failed.'
  fi

  usermod -aG docker "${PANTHEON_ALLOWED_USER}"
  pantheon_log_success 'User added to docker group.'
  pantheon_register_action "Log out and back in as ${PANTHEON_ALLOWED_USER} so the docker group applies to your session."
}

pantheon_setup_docker
