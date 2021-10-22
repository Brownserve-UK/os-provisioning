#!/bin/bash
# -*- coding: utf-8 -*-
# This script sets up a local admin user

crypt_password=$(mkpasswd -m SHA-512 --rounds=4096 $LOCAL_ADMIN_PASSWORD)

useradd -G 'sudo' -m -s /bin/bash -p "$crypt_password" $LOCAL_ADMIN_USERNAME
echo "Defaults:$LOCAL_ADMIN_USERNAME !requiretty" >/etc/sudoers.d/$LOCAL_ADMIN_USERNAME
echo "$LOCAL_ADMIN_USERNAME ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers.d/$LOCAL_ADMIN_USERNAME
chmod 440 /etc/sudoers.d/$LOCAL_ADMIN_USERNAME
