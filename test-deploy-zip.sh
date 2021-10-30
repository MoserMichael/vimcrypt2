#!/bin/bash

echo "create zip"

set -e

PLUGIN=vimcrypt2

echo "*** test deploy from current dir, to test the thing. ***"
./bundle.sh

if [[ -d $HOME/.vim-bak ]]; then

    echo "can't test deploy, directory $HOME/.vim-bak already exists"
    exit 1
fi

if [[ -f $HOME/.vimrc-bak ]]; then

    echo "can't test deploy, file $HOME/.vimrc-bak already exists"
    exit 1
fi


mv $HOME/.vim $HOME/.vim-bak
mv $HOME/.vimrc $HOME/.vimrc-bak


rm -rf .vim/pack/vendor/start/$PLUGIN 
mkdir -p ~/.vim/pack/vendor/start/$PLUGIN; unzip $PLUGIN.zip -d  ~/.vim/pack/vendor/start/$PLUGIN




