#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

yum install -y createrepo isomd5sum genisoimage git
