#/bin/bash

# common function to compare versions
function ver()
{
    printf "%03d%03d%03d%03d" $(echo "$1" | tr '.' ' ');
}

# install golang required for sops
install_go()
{
    # Verify the Go installed version
    go_version=$(sudo go version 2>/dev/null | grep -oP '\d+\.\d+')

    # Install only when Go version is not the right version or not installed
    if [ -z "$go_version" ] || [ $(ver $go_version) -lt $(ver 1.8) ]; then

        # Download and install the package
        sudo apt-get update
        sudo apt-get install golang-go


    else
        echo "Go version $go_version already installed."
    fi
}

# install sops
install_sops()
{
    go install go.mozilla.org/sops/v3/cmd/sops@latest
}

# install age
install_age()
{
    sudo apt install age
}

# install flux
install_flux()
{
    curl -s https://fluxcd.io/install.sh | sudo bash
}


# install pre-commit
install_pre_commit()
{
    pip install pre-commit
}


# install kubectl
install_kubectl()
{
    sudo snap install kubectl --classic
}

# install helm
install_helm()
{
    sudo snap install helm --classic
}

# install task
install_task()
{
    sudo snap install task --classic
}


# ############## MAIN ###############

# sops installation
install_go
if [ $? == 0 ]; then
    install_sops
else
    "Problem during Go language installation"
    exit 1
fi

# age installation
install_age

# flux-cli installation
install_flux

# pre-commit installation
install_pre_commit

# kubectl installation
install_kubectl

# helm installation
install_helm

# task installation
install_task
