#!/bin/bash

# Disable photos from opening when a device is connected
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true