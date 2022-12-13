#!/bin/bash

# ==============================================================================
# This script is used to setup the work environment and install common tools
# on a new machine.
# ------------------------------------------------------------------------------
# Usage: sudo ./setup.sh
# ==============================================================================

# --- Common methods and shortcuts ---------------------------------------------

# Display an informative message to the console
log () {
    case $1 in
        "info")  color="\e[1;34m" symbol="i";;
        "warn")  color="\e[1;33m" symbol="!";;
        "ok")    color="\e[1;32m" symbol="+";;
        "error") color="\e[1;31m" symbol="x";;
        *)       color="\e[1;37m" symbol="*";;
    esac

    if [[ $1 == "ok" ]]; then
        printf '\e[A\e[K'
    fi

    info=("${@:2}")
    echo -e "$color[$symbol]\e[0m $(printf "%s " "${info[@]}")"
}

# Run a command with no output to STDOUT
quiet () {
    $@ &> /dev/null
}

# Run a command with unelevated privileges
unelevated () {
    sudo -u $USER_NAME $@
}

# Run a command with unelevated privileges and no output to STDOUT
quiet_unelevated () {
    sudo -u $USER_NAME $@ &> /dev/null
}

# Get a passwd file entry for the current user
passwd_ent () {
    case $1 in
        "login") field=1;;
        "pass")  field=2;;
        "uid")   field=3;;
        "gid")   field=4;;
        "info")  field=5;;
        "home")  field=6;;
        "shell") field=7;;
        *)       field=0;;
    esac

    if [ $field -eq 0 ]; then
        echo $(getent passwd $USER_NAME)
    else
        echo $(getent passwd $USER_NAME | cut -d: -f${field})
    fi
}

# --- Check for root privileges ------------------------------------------------

if [ "$EUID" -ne 0 ]; then
    warning=(
        "Part of this script must be run with elevated privileges, "
        "please run it again with permissions: sudo $0"
    )
    log error $(printf "%s" "${warning[@]}")
    exit 1
fi

# --- Variables used accros this script ----------------------------------------

USER_NAME=$(logname)
USER_PATH=""

# --- Check for missing packages and install them if necessary -----------------

declare -a packages=()

# Enable the RPM Fusion repositories:
# https://docs.fedoraproject.org/en-US/quick-docs/setup_rpmfusion/#proc_enabling-the-rpmfusion-repositories-using-command-line-utilities_enabling-the-rpmfusion-repositories

if ! rpm -qa | grep rpmfusion-free-release &> /dev/null; then
    log info "Enabling RPM Fusion Free repositories..."
    quiet dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
    log ok "Enabled RPM Fusion Free repositories"
fi

if ! rpm -qa | grep rpmfusion-nonfree-release &> /dev/null; then
    log info "Enabling RPM Fusion Non-Free repositories..."
    quiet dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    log ok "Enabled RPM Fusion Non-Free repositories"
fi

# Utilities
if ! command -v chsh &> /dev/null; then
    packages+=("util-linux-user")
fi

# LSD
if ! command -v lsd &> /dev/null; then
    packages+=("lsd")
fi

# TheFuck
if ! command -v thefuck &> /dev/null; then
    packages+=("thefuck")
fi

# Git: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git
if ! command -v git &> /dev/null; then
    packages+=("git-all")
fi

# Python: https://www.python.org/downloads/source/
if ! command -v python3 &> /dev/null; then
    packages+=("python")
    packages+=("python-devel")
fi

# ZSH: https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH#install-and-set-up-zsh-as-default
if ! command -v zsh &> /dev/null; then
    packages+=("zsh")
fi

# VSCode: https://code.visualstudio.com/docs/setup/linux#_rhel-fedora-and-centos-based-distributions
if ! command -v code &> /dev/null; then
    packages+=("code")
    rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
fi

# LPF: https://github.com/leamas/lpf#installation
if ! command -v lpf &> /dev/null; then
    packages+=("lpf")
fi

# Spotify: https://docs.fedoraproject.org/en-US/quick-docs/installing-spotify
if ! rpm -qa | grep lpf-spotify-client &> /dev/null; then
    packages+=("lpf-spotify-client")
fi

# Discord: 
if ! command -v Discord &> /dev/null; then
    packages+=("discord")
fi

# Chrome: 
if ! command -v google-chrome &> /dev/null; then
    packages+=("google-chrome-stable")
    quiet dnf install -y fedora-workstation-repositories
    quiet dnf config-manager --set-enabled google-chrome
fi

# Docker: https://docs.docker.com/engine/install/fedora/
if ! command -v docker &> /dev/null; then
    packages+=("docker-ce")
    packages+=("docker-ce-cli")
    packages+=("containerd.io")
    packages+=("docker-compose-plugin")
    quiet dnf remove -y docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-selinux \
                  docker-engine-selinux \
                  docker-engine
    quiet dnf install -y dnf-plugins-core
    quiet dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
fi

# Install missing packages
if [ ${#packages[@]} -gt 0 ]; then
    packages_str=$(printf "%s " "${packages[@]}")
    log info "Installing missing packages: ${packages_str}..."
    quiet dnf update
    quiet dnf install -y ${packages_str}
    log ok "Installed packages: ${packages_str}"

    # Install LPF packages
    if [[ ${packages[*]} =~ "lpf" ]] ; then
        quiet unelevated lpf update
    else
        for package in ${packages[@]}; do
            if [[ $package =~ "lpf-" ]] ; then
                log info "Installing LPF package: ${package}..."
                quiet unelevated lpf update
                quiet lpf install ${package}
                log ok "Installed LPF package: ${package}"
            fi
        done
    fi

    # Enable the Docker service
    if [[ ${packages[*]} =~ "docker" ]] ; then
        log info "Enabling the Docker service..."
        quiet systemctl start docker
        quiet systemctl enable docker
        log ok "Enabled the Docker service"
    fi
fi

# --- Configure ZSH as the default shell interpreter for the current user ------

if [[ $(passwd_ent shell) != $(which zsh) ]]; then
    log info "Configuring ZSH as the default shell interpreter..."
    quiet chsh -s $(which zsh) $USER_NAME
    log ok "Configured ZSH as the default shell interpreter"
fi

# --- Install Oh-My-Zsh --------------------------------------------------------
# See: https://github.com/ohmyzsh/ohmyzsh/wiki#welcome-to-oh-my-zsh

USER_PATH=$(passwd_ent home)

if ! test -f "$USER_PATH/.oh-my-zsh/oh-my-zsh.sh"; then
    if test -d "$USER_PATH/.oh-my-zsh"; then
        log info "Removing existing Oh-My-Zsh installation..."
        quiet_unelevated rm -rf "$USER_PATH/.oh-my-zsh"
        log ok "Removed existing Oh-My-Zsh installation"
    fi

    log info "Installing Oh-My-Zsh..."
    unelevated sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    log ok "Installed Oh-My-Zsh"
fi

# --- Install ZSH syntax-highlighting plugin -----------------------------------

if ! test -d "${ZSH_CUSTOM:-$USER_PATH/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"; then
    log info "Installing ZSH syntax-highlighting plugin..."
    quiet_unelevated git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-$USER_PATH/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    log ok "Installed ZSH syntax-highlighting plugin"
fi

# --- Install ZSH autosuggestions plugin ---------------------------------------

if ! test -d "${ZSH_CUSTOM:-$USER_PATH/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"; then
    log info "Installing ZSH autoautosuggestions plugin..."
    quiet_unelevated git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-$USER_PATH/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    log ok "Installed ZSH autoautosuggestions plugin"
fi

# --- Add the ZSH configuration file -------------------------------------------

if ! test -f "$USER_PATH/.zshrc"; then
    log info "Adding a default ZSH configuration file..."
    unelevated curl -fsSL https://raw.githubusercontent.com/brinkflew/workstation-setup/fedora/profile/zshrc -o $USER_PATH/.zshrc
    log ok "Added a default ZSH configuration file"
fi

# --- Install the Powerlevel10k theme for ZSH ----------------------------------

if ! test -d "${ZSH_CUSTOM:-$USER_PATH/.oh-my-zsh/custom}/themes/powerlevel10k"; then
    log info "Installing Powerlevel10k for ZSH..."
    quiet_unelevated git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$USER_PATH/.oh-my-zsh/custom}/themes/powerlevel10k"
    unelevated sed -i 's+ZSH_THEME=.*+ZSH_THEME="powerlevel10k/powerlevel10k"+' $USER_PATH/.zshrc
    unelevated curl -fsSL https://raw.githubusercontent.com/brinkflew/workstation-setup/fedora/profile/p10k.zsh -o $USER_PATH/.p10k.zsh
    log ok "Installed Powerlevel10k for ZSH"
fi

# --- Create an SSH key if not existing ----------------------------------------

if ! test -f "$USER_PATH/.ssh/id_ed25519"; then
    log info "Creating an SSH key..."
    quiet_unelevated ssh-keygen -t ed25519 -C "$USER_NAME@$(hostname)" -f "$USER_PATH/.ssh/id_ed25519" -N \"\"
    log ok "Created an SSH key"
fi

# --- Add profile.d scripts ----------------------------------------------------

if ! test -f "$USER_PATH/.profile.d/01_ssh_agent"; then
    log info "Adding the SSH agent loading script..."
    unelevated mkdir -p "$USER_PATH/.profile.d"
    unelevated curl -fsSL https://raw.githubusercontent.com/brinkflew/workstation-setup/fedora/profile/ssh_agent.sh -o $USER_PATH/.profile.d/01_ssh_agent
    log ok "Added the SSH agent loading script"
fi

# --- Install custom fonts -----------------------------------------------------

FONTS_PATH="$USER_PATH/.local/share/fonts"

# Sauce Code Pro (Source Code Pro patched with Nerd Fonts)
if ! test -d "$USER_PATH/.local/share/fonts/sauce-code-pro"; then
    log info "Installing patched Sauce Code Pro Nerd Font..."
    FONT_PATH_SAUCE="$FONTS_PATH/sauce-code-pro"
    quiet_unelevated mkdir -p "$FONT_PATH_SAUCE"
    quiet_unelevated curl -fsSL \
        -o "$FONT_PATH_SAUCE/Sauce Code Pro Nerd Font Complete.ttf" \
        "https://github.com/ryanoasis/nerd-fonts/blob/master/patched-fonts/SourceCodePro/Regular/complete/Sauce%20Code%20Pro%20Nerd%20Font%20Complete%20Mono.ttf?raw=true"
    quiet_unelevated fc-cache -v
    log ok "Installed patched Sauce Code Pro Nerd Font"
fi

# Font Awesome 6 Free
if ! test -d "$USER_PATH/.local/share/fonts/font-awesome"; then
    log info "Installing FontAwesome..."
    FONT_PATH_AWESOME="$FONTS_PATH/font-awesome"
    AWESOME_DIR="fontawesome-free-6.2.1-desktop"
    quiet_unelevated mkdir -p "$FONT_PATH_AWESOME"
    quiet_unelevated curl -L \
        -o "$FONT_PATH_AWESOME/$AWESOME_DIR.zip"
        "https://use.fontawesome.com/releases/v6.2.1/$AWESOME_DIR.zip" \
    quiet_unelevated unzip "$FONT_PATH_AWESOME/$AWESOME_DIR.zip" -d "$FONT_PATH_AWESOME"
    quiet_unelevated mv "$FONT_PATH_AWESOME/$AWESOME_DIR/otfs/*" "$FONT_PATH_AWESOME/"
    quiet_unelevated rm "$FONT_PATH_AWESOME/$AWESOME_DIR.zip"
    quiet_unelevated rm -rf "$FONT_PATH_AWESOME/$AWESOME_DIR"
    quiet_unelevated fc-cache -v
    log ok "Installed FontAwesome"
fi

# --- Done! --------------------------------------------------------------------

log ok "Done!"
