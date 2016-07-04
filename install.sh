#!/bin/bash

# Install homebrew
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

echo "Install brewfiles"
brew bundle
brew bundle --file=Caskfile

echo "Bootstrap settings"
./bootstrap.sh