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

    info=("${@:2}")
    echo -e "$color[$symbol]\e[0m $(printf "%s " "${info[@]}")"
}

# Run a command with unelevated privileges
unelevated () {
    sudo -u $USER_NAME $@
}

# Get a passwd file entry for the current user
passwd_ent() {
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
        return $(getent passwd $USER_NAME)
    else
        return $(getent passwd $USER_NAME | cut -d: -f${field})
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
log info "Enabling RPM Fusion repositories"
dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

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
if ! command -v spotify &> /dev/null; then
    packages+=("lpf-spotify-client")
fi

# Discord: 
if ! command -v discord &> /dev/null; then
    packages+=("discord")
fi

# Chrome: 
if ! command -v google-chrome &> /dev/null; then
    packages+=("google-chrome-stable")
    dnf install -y fedora-workstation-repositories
    dnf config-manager --set-enabled google-chrome
fi

# Docker: https://docs.docker.com/engine/install/fedora/
if ! command -v docker &> /dev/null; then
    packages+=("docker-ce")
    packages+=("docker-ce-cli")
    packages+=("containerd.io")
    packages+=("docker-compose-plugin")
    dnf remove -y docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-selinux \
                  docker-engine-selinux \
                  docker-engine
    dnf install -y dnf-plugins-core
    dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
fi

# Install missing packages
if [ ${#packages[@]} -gt 0 ]; then
    packages_str=$(printf ",%s" "${packages[@]}")
    log info "Installing missing packages: ${packages_str:1}"
    dnf update -y
    dnf install -y ${packages_str:1}

    # Install LPF packages
    if [[ ${packages[*]} =~ "lpf" ]] ; then
        unelevated lpf update -y
    else
        for package in ${packages[@]}; do
            if [[ $package =~ "lpf-" ]] ; then
                unelevated lpf update -y
            fi
        done
    fi

    # Enable the Docker service
    if [[ ${packages[*]} =~ "docker" ]] ; then
        log info "Enabling the Docker service"
        systemctl start docker
        systemctl enable docker
    fi
fi

# - Configure ZSH as the default shell interpreter for the current user --------
if [ $(passwd_ent shell) != $(which zsh) ]; then
    log info "Configuring ZSH as the default shell interpreter"
    chsh -s $(which zsh) $USER_NAME
fi

# --- Install Oh-My-Zsh --------------------------------------------------------
# See: https://github.com/ohmyzsh/ohmyzsh/wiki#welcome-to-oh-my-zsh

USER_PATH=$(passwd_ent home)

if ! test -f $USER_PATH/.oh-my-zsh/oh-my-zsh.sh; then
    log info "Installing Oh-My-Zsh"
    unelevated sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# --- Install the Powerlevel10k theme for ZSH ----------------------------------

if ! test -d ${ZSH_CUSTOM:-$USER_PATH/.oh-my-zsh/custom}/themes/powerlevel10k; then
    log info "Installing Powerlevel10k for ZSH"
    unelevated git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$USER_PATH/.oh-my-zsh/custom}/themes/powerlevel10k
    unelevated sed -i 's+ZSH_THEME=.*+ZSH_THEME="powerlevel10k/powerlevel10k"+' $USER_PATH/.zshrc
fi
