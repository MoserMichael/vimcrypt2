#!/bin/bash

set -ex
# remove files not under git
git clean -f -d

if [[ -f vimcrypt2.zip ]]; then
  rm -f vimcrypt2.zip 
fi

zip vimcrypt2.zip $(git ls-files | grep -v .sh)
