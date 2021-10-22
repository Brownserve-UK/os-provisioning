#!/bin/bash -e
# Clear /etc/machine-id so that it is recreated once the VM next boots.
# Do not delete the file as it is required for systemd.

set -e
set -x

echo "" > /etc/machine-id