#!/bin/bash -e

set -e
set -x

# Clear /etc/machine-id so that it is recreated once the VM next boots.
# Do not delete the file as it is required for systemd.
echo "" > /etc/machine-id