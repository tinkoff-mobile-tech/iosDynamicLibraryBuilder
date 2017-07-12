#!/bin/bash


RED="\033[1;31m"
GREEN="\033[0;32m"
TEXT="\033[0m"
RUBY_VERSION="2.2.2"
COCOAPODS_VERSION="1.2.1"
XCODEPROJECT_VERSION="1.5.0"

# SETP 0. CREATE GEMFILE
echo -e "source \'https://rubygems.org\'\ngem 'cocoapods', '~> ${COCOAPODS_VERSION}'\ngem 'xcodeproj', '~> ${XCODEPROJECT_VERSION}'" > Gemfile

# STEP 1. INSTALLING RVM
echo -ne "Looking for RVM... "
if ! rvm info &>/dev/null; then
  echo -ne "${RED}Not found.${TEXT} Installing... "
  \curl -sSL https://get.rvm.io | bash 1> /dev/null
  exec bash
  echo -e "${GREEN}Done.${TEXT}";
else
  echo -e "${GREEN}Found.${TEXT}";
fi

# STEP 2. INSTALLING RUBY
echo -ne "Looking for RUBY ${RUBY_VERSION}... "
if ! rvm list | grep $RUBY_VERSION &>/dev/null; then
  echo -ne "${RED}Not found.${TEXT} Installing... ";
  rvm install ${RUBY_VERSION} 1> /dev/null;
  echo -e "${GREEN}Done.${TEXT}";
else
  echo -e "${GREEN}Found.${TEXT}";
fi

# STEP 3. INSTALLING BUNDLER
echo -ne "Looking for Bundler Gem... "
if ! gem list -i bundler | grep true &>/dev/null; then
  echo -ne "${RED}Not found.${TEXT} Installing... ";
  sudo gem install bundler -n /usr/local/bin 1> /dev/null;
  echo -e "${GREEN}Done.${TEXT}";
else
  echo -e "${GREEN}Found.${TEXT}";
fi

ruby buildLib.rb $@
