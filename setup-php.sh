#!/bin/bash
source ~/.bash_profile;

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/"

brew bundle --file=brew/Brewfile-php

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/php/"

for version in *; do
    # Install PHP config files
    cp $version/*.ini $(brew --prefix)/etc/php/$version/conf.d

    # Install PECL extensions
    usephp $version
    while read -r extension; do
        pecl install $extension
    done < "$version/pecl.list"
done
