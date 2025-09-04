#!/bin/bash

# Script to install Docker CLI and Docker Compose on various Linux distributions
# Supports Debian, Ubuntu Server, and Rocky Linux
# Includes error handling and attempts to install missing dependencies

echo "Docker Installation Script"
echo "-------------------------"

# Function to display error message and exit
error_exit() {
    echo "ERROR: $1" >&2
    exit 1
}

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "WARNING: $1 is not installed. Attempting to install it..."
        install_dependency "$1"
    else
        echo "$1 is installed."
    fi
}

# Function to install missing dependencies based on distro
install_dependency() {
    local dep="$1"
    case $DISTRO in
        "Debian"|"Ubuntu")
            if [ "$EUID" -ne 0 ]; then
                error_exit "Cannot install $dep without root privileges. Please run this script with sudo or install $dep manually."
            fi
            apt update || error_exit "Failed to update package index while installing $dep."
            apt install -y "$dep" || error_exit "Failed to install $dep."
            ;;
        "Rocky")
            if [ "$EUID" -ne 0 ]; then
                error_exit "Cannot install $dep without root privileges. Please run this script with sudo or install $dep manually."
            fi
            dnf install -y "$dep" || error_exit "Failed to install $dep."
            ;;
        *)
            error_exit "Distribution not selected yet. Cannot install $dep."
            ;;
    esac
    if ! command -v "$dep" &> /dev/null; then
        error_exit "Failed to install $dep. Please install it manually and rerun the script."
    fi
    echo "$dep has been installed successfully."
}

# Function to display menu and get user input for distro selection
select_distro() {
    # Check if running in a non-interactive environment
    if [ ! -t 0 ]; then
        error_exit "This script requires interactive input to select a distribution. Please download the script and run it manually with 'sudo bash install.sh'."
    fi

    local retries=0
    local max_retries=5
    DISTRO=""

    while [ -z "$DISTRO" ] && [ $retries -lt $max_retries ]; do
        echo "Please select your Linux distribution:"
        echo "1) Debian"
        echo "2) Ubuntu Server"
        echo "3) Rocky Linux"
        read -p "Enter the number of your choice (1-3): " choice

        case $choice in
            1)
                DISTRO="Debian"
                ;;
            2)
                DISTRO="Ubuntu"
                ;;
            3)
                DISTRO="Rocky"
                ;;
            *)
                echo "Invalid choice. Please select a number between 1 and 3."
                retries=$((retries + 1))
                if [ $retries -eq $max_retries ]; then
                    error_exit "Too many invalid attempts. Exiting."
                fi
                ;;
        esac
    done
}

# Function to install Docker on Debian
install_debian() {
    echo "Installing Docker on Debian..."
    # Update package index
    sudo apt update || error_exit "Failed to update package index."
    # Install prerequisites
    sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release || {
        echo "WARNING: Some prerequisites failed to install. Attempting to continue..."
    }
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || error_exit "Failed to add Docker GPG key."
    # Set up the stable repository
    if command -v lsb_release &> /dev/null; then
        CODENAME=$(lsb_release -cs)
    else
        echo "WARNING: lsb_release not found. Attempting to determine codename manually."
        CODENAME=$(grep -oP '(?<=^VERSION_CODENAME=).+' /etc/os-release | tr -d '"')
        [ -z "$CODENAME" ] && error_exit "Could not determine Debian codename."
    fi
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null || error_exit "Failed to add Docker repository."
    # Update package index again
    sudo apt update || error_exit "Failed to update package index after adding Docker repo."
    # Install Docker Engine, CLI, and Containerd
    sudo apt install -y docker-ce docker-ce-cli containerd.io || error_exit "Failed to install Docker packages."
    # Install Docker Compose from repository
    sudo apt install -y docker-compose-plugin || {
        echo "WARNING: Docker Compose plugin installation failed. Docker Compose will not be available."
    }
    # Verify installation
    if sudo docker --version &> /dev/null; then
        sudo docker --version
    else
        error_exit "Docker installation verification failed."
    fi
    if sudo docker compose version &> /dev/null; then
        sudo docker compose version
    else
        echo "WARNING: Docker Compose not installed or not working."
    fi
    # Add current user to docker group to run without sudo
    sudo usermod -aG docker "$USER" || echo "WARNING: Failed to add user to docker group. You may need to run Docker with sudo."
    echo "Docker and Docker Compose installed successfully on Debian!"
    echo "Please log out and log back in to apply group changes, or run 'newgrp docker'."
}

# Function to install Docker on Ubuntu Server
install_ubuntu() {
    echo "Installing Docker on Ubuntu Server..."
    # Update package index
    sudo apt update || error_exit "Failed to update package index."
    # Install prerequisites
    sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release || {
        echo "WARNING: Some prerequisites failed to install. Attempting to continue..."
    }
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || error_exit "Failed to add Docker GPG key."
    # Set up the stable repository
    if command -v lsb_release &> /dev/null; then
        CODENAME=$(lsb_release -cs)
    else
        echo "WARNING: lsb_release not found. Attempting to determine codename manually."
        CODENAME=$(grep -oP '(?<=^UBUNTU_CODENAME=).+' /etc/os-release | tr -d '"')
        [ -z "$CODENAME" ] && error_exit "Could not determine Ubuntu codename."
    fi
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null || error_exit "Failed to add Docker repository."
    # Update package index again
    sudo apt update || error_exit "Failed to update package index after adding Docker repo."
    # Install Docker Engine, CLI, and Containerd
    sudo apt install -y docker-ce docker-ce-cli containerd.io || error_exit "Failed to install Docker packages."
    # Install Docker Compose from repository
    sudo apt install -y docker-compose-plugin || {
        echo "WARNING: Docker Compose plugin installation failed. Docker Compose will not be available."
    }
    # Verify installation
    if sudo docker --version &> /dev/null; then
        sudo docker --version
    else
        error_exit "Docker installation verification failed."
    fi
    if sudo docker compose version &> /dev/null; then
        sudo docker compose version
    else
        echo "WARNING: Docker Compose not installed or not working."
    fi
    # Add current user to docker group to run without sudo
    sudo usermod -aG docker "$USER" || echo "WARNING: Failed to add user to docker group. You may need to run Docker with sudo."
    echo "Docker and Docker Compose installed successfully on Ubuntu Server!"
    echo "Please log out and log back in to apply group changes, or run 'newgrp docker'."
}

# Function to install Docker on Rocky Linux
install_rocky() {
    echo "Installing Docker on Rocky Linux..."
    # Install prerequisites
    sudo dnf install -y dnf-utils device-mapper-persistent-data lvm2 || {
        echo "WARNING: Some prerequisites failed to install. Attempting to continue..."
    }
    # Add Docker repository
    sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || error_exit "Failed to add Docker repository."
    # Install Docker Engine, CLI, and Containerd
    sudo dnf install -y docker-ce docker-ce-cli containerd.io || error_exit "Failed to install Docker packages."
    # Install Docker Compose plugin
    sudo dnf install -y docker-compose-plugin || {
        echo "WARNING: Docker Compose plugin installation failed. Docker Compose will not be available."
    }
    # Start and enable Docker service
    sudo systemctl start docker || error_exit "Failed to start Docker service."
    sudo systemctl enable docker || echo "WARNING: Failed to enable Docker service on boot."
    # Verify installation
    if sudo docker --version &> /dev/null; then
        sudo docker --version
    else
        error_exit "Docker installation verification failed."
    fi
    if sudo docker compose version &> /dev/null; then
        sudo docker compose version
    else
        echo "WARNING: Docker Compose not installed or not working."
    fi
    # Add current user to docker group to run without sudo
    sudo usermod -aG docker "$USER" || echo "WARNING: Failed to add user to docker group. You may need to run Docker with sudo."
    echo "Docker and Docker Compose installed successfully on Rocky Linux!"
    echo "Please log out and log back in to apply group changes, or run 'newgrp docker'."
}

# Main script execution

# Check if user has root privileges
if [ "$EUID" -ne 0 ]; then
    echo "This script needs to be run with root privileges to install dependencies and Docker."
    echo "Please run it with 'sudo' or as root."
    exit 1
fi

# Select distribution first to determine package manager for dependency installation
select_distro

# Check for essential tools and install if missing
check_command "curl"
if ! command -v "sudo" &> /dev/null; then
    echo "WARNING: sudo is not installed. Attempting to install it..."
    case $DISTRO in
        "Debian"|"Ubuntu")
            apt update || error_exit "Failed to update package index while installing sudo."
            apt install -y sudo || error_exit "Failed to install sudo. Please install it manually."
            ;;
        "Rocky")
            dnf install -y sudo || error_exit "Failed to install sudo. Please install it manually."
            ;;
    esac
    if ! command -v "sudo" &> /dev/null; then
        error_exit "Failed to install sudo. Please install it manually and rerun the script."
    fi
    echo "sudo has been installed successfully."
fi

# Install based on selected distribution
case $DISTRO in
    "Debian")
        install_debian
        ;;
    "Ubuntu")
        install_ubuntu
        ;;
    "Rocky")
        install_rocky
        ;;
esac

exit 0
