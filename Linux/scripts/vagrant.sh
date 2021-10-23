#!/bin/bash
# Prepares the machine for Vagrant

# Download the well-known keypair from https://github.com/hashicorp/vagrant/tree/main/keys
mkdir /home/vagrant/.ssh
wget https://raw.githubusercontent.com/hashicorp/vagrant/main/keys/vagrant.pub -o /home/vagrant/.ssh/authorized_keys
chmod 0600 /home/vagrant/.ssh/authorized_keys