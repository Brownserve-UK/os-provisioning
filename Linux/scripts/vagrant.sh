#!/bin/bash
# Prepares the machine for Vagrant

# Download the well-known keypair from https://github.com/hashicorp/vagrant/tree/main/keys
mkdir /home/vagrant/.ssh
curl 'https://raw.githubusercontent.com/hashicorp/vagrant/main/keys/vagrant.pub' --output vagrant.pub
mv vagrant.pub /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh
chmod 0700 /home/vagrant/.ssh
chmod 0600 /home/vagrant/.ssh/authorized_keys