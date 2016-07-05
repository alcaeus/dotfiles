#!/bin/bash

# Install homebrew
echo "Install homebrew"
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

echo "Install brewfiles"
brew bundle --file=brew/Brewfile
brew bundle --file=brew/Caskfile

echo "Bootstrap settings"
./bootstrap.sh

echo "Update macOS settings"
./setup-macos.sh

echo "Install app store programs"
./mas.sh