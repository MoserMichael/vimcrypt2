#!/bin/bash

set -ex

PLUGIN=vimcrypt2


if [[ -f $PLUGIN.zip ]]; then
  rm -f $PLUGIN.zip 
fi

zip $PLUGIN.zip $(git ls-files | grep -v $0)
