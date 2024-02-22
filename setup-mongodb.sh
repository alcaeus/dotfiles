#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE}")";

rsync -avh --no-perms mongo-orchestration/ ~/.local/mongo-orchestration
if [ ! -f ~/.local/bin/mo ]; then ln -s ~/.local/mongo-orchestration/mo ~/.local/bin/mo; fi
