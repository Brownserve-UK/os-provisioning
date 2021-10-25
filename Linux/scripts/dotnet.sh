#!/bin/bash -e
# Installs the dotnet core SDK

# Dot source /etc/lsb-release to get the vars
. /etc/lsb-release

wget https://packages.microsoft.com/config/ubuntu/$DISTRIB_RELEASE/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb

apt update
apt install -y apt-transport-https dotnet-sdk-5.0