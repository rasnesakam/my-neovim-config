#!/bin/bash

destination="$HOME/.local/share/nvim/site/pack/packer/start/packer.nvim"

if [ ! -d $destination ]
then
	echo "cloning repository to $destination";
	git clone --depth 1 https://github.com/wbthomason/packer.nvim $destination;
fi
