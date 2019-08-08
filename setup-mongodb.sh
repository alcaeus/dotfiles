#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE}")";

sudo rsync -avh --no-perms mongo-orchestration/ /usr/local/mongo-orchestration
if [ ! -f /usr/local/bin/mo ]; then ln -s /usr/local/bin/mo /usr/local/mongo-orchestration/mo; fi
