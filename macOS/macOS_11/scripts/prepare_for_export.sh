#!/bin/bash
#  This script will prepare the machine for export

# As Packer cleans up the NVRAM file before we can get to it we need to shutdown the machine at the last stage of the build
shutdown -h now