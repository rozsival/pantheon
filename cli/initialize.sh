PANTHEON_REPO_ROOT="$(pantheon_repo_root)"
declare -gr PANTHEON_REPO_ROOT
declare -gr PANTHEON_CLI_BIN="$PANTHEON_REPO_ROOT/bin/pantheon"
declare -gr PANTHEON_SSHD_CONFIG="/etc/ssh/sshd_config"
declare -gr PANTHEON_SSHD_CONFIG_DIR="/etc/ssh/sshd_config.d"
declare -gr PANTHEON_FAIL2BAN_JAIL="/etc/fail2ban/jail.local"
declare -gr PANTHEON_GITHUB_REPO="rozsival/pantheon"
declare -gr PANTHEON_RELEASE_ASSET="pantheon.tar.gz"
declare -gr PANTHEON_INSTALL_COMMAND="curl -fsSL https://github.com/$PANTHEON_GITHUB_REPO/releases/latest/download/install.sh | bash"
