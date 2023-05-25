# VIMCRYPT2 vim plugin - encrypt your files with openssl

I had my adaptation for encrypting/decrypting files with vim [VIMCRYPT](https://github.com/MoserMichael/vimcrypt), now it has a problem: you need to enter the encryption key every time that the file is read/decrypted and every time that the file is saved/encryted.

Now it is quite possible to make a typo, while saving the file. In this event you might have lost your precious file, as you may no longer be aware of the current encryption key.

One fix might be to make a backup before saving the file, in this event you may be lucky with the backup. That's what VIMCRYPT is doing.

The VIMCRYPT2 plugin solves this issue as follows:

- After decrypting a file, we take the decryption key and keep it in memory. Now the key is not kept in plain text form, it is encrypted with a master key, the master key is a random key that is generated per editor session. The encrypted key is kept as a buffer variable.
- The very same key that has been used for decryption is then used for encryption, when the file is saved back to disk.
- The key is passed to openssl via a pipe, and not via a command line option. It would be visible to anyone, as a command line option, it is less exposed, as it is passed via a pipe. Now this can't be done with vimscript, that's were we need to use python3;

Other changes, relative to [openssl.vim](https://github.com/vim-scripts/openssl.vim)

- use aes-256-ecb instead of aes-256-cbc. Reason: if the file gets damaged, then all the data after the damage point is lost, when using cipher block chaining (CBC). The damage would be limited to the AES block with the damaged byte, when using ECB
- turn off vim options ```shelltemp``` and ```undofile``` when working with encrypted stuff.
- exclude vulnerable ciphers from the list of supported file extensions (each supported file extension maps to a cipher type)
- Now the following file extensions map to the following ciphers:
    - .aes  file extension uses -aes-256-ecb
    - .cast file extension uses -cast
    - .rc5  file extension uses -rc5
    - .desx file extension uses -desx

- before saving to an existing file with any of these extensions it backs up the old file. 
- throw out the password safe stuff, I don't need it.

# Install details

Install from git

```mkdir -p ~/.vim/pack/vendor/start/vimcrypt2; git clone --depth 1 https://github.com/MoserMichael/vimcrypt2 ~/.vim/pack/vendor/start/vimcrypt2```
 
Download zip from [www.vim.org](https://www.vim.org/scripts/script.php?script_id=5985)
```mkdir -p ~/.vim/pack/vendor/start/vimcrypt2; unzip vimcrypt2.zip -d  ~/.vim/pack/vendor/start/vimcrypt2```

# OSX Gotchas.

I got the following issues on OsX Catalina (10.15.7):

### default vim does not have python3 enabled

VIM is installed by default on OSX it is located in ```/usr/bin/vim```, however that version currently has no support for the python3, you can install a proper vim with brew

```brew install vim```

Now that one is put to ```/usr/local/bin/vim```.

### multiple versions of openssl

On OSX you do have openssl installed by default, however they use the LibreSSL fork 

```
$ which openssl
/usr/bin/openssl

$ openssl version
LibreSSL 2.8.3
```

Now you can install openssl with brew, this gives you a real openssl

```
$ brew install openssl

```

Let's find where openssl is installed

```
brew list openssl

...
/usr/local/opt/openssl/bin/openssl

...



$ /usr/local/opt/openssl/bin/openssl version
OpenSSL 3.0.0 7 sep 2021 (Library: OpenSSL 3.0.0 7 sep 2021)
```

Now the interesting detail: the output of these two utilities can't be mixed.

The following command encrypts and decrypts a string with the same password, while using the same version of openssl


```
echo '123' | /usr/bin/openssl enc -e -aes-256-ecb -pass pass:blabla | /usr/bin/openssl enc -d -aes-256-ecb -pass pass:blabla
123

echo '123' | /usr/local/opt/openssl/bin/openssl enc -e -aes-256-ecb -pass pass:blabla | /usr/local/opt/openssl/bin/openssl enc -d -aes-256-ecb -pass pass:blabla
123

```

However the same does not work, if you  try to decrypt the output of the libre ssl fork with a different utility from OpenSSL.

```
echo '123' | /usr/local/opt/openssl/bin/openssl enc -e -aes-256-ecb -pass pass:blabla | /usr/bin/openssl enc -d -aes-256-ecb -pass pass:blabla
<error error error>

echo '123' | /usr/bin/openssl enc -e -aes-256-ecb -pass pass:blabla | /usr/local/opt/openssl/bin/openssl enc -d -aes-256-ecb -pass pass:blabla
<error error error>

```

What's the reason? it appears that libressl has a different way of deriving the AES encryption key from the password. In older versions of libressl
they used MD5 for deriving the AES key from the password, then they changed it to SHA256.

Adding the ```-md sha256``` or ```-md md5``` parameter to both versions of openssl will force them to use the same algorithm!!!

```

echo '123' | /usr/local/opt/openssl/bin/openssl enc -e -aes-256-ecb -pass pass:blabla -md md5 | /usr/bin/openssl enc -d -aes-256-ecb -md md5  -pass pass:blabla

echo '123' | /usr/local/opt/openssl/bin/openssl enc -e -aes-256-ecb -pass pass:blabla -md sha256 | /usr/bin/openssl enc -d -aes-256-ecb -md sha256  -pass pass:blabla

```


This is something that should be remembered, when moving encrypted files between different locations.

## Supported ciphers

you can get the list of supported ciphers as follows

```
/usr/bin/openssl enc -list

/usr/local/opt/openssl/bin/openssl enc -list
```

The OpenSSL version supports more ciphers than the LibreSSL version; 
For example OpenSSL has ```chacha20``` , whereas LibreSSL doesn't.

# Acknowledgement

This plugin is based on openssl.vim by Noah Spurrier [link](https://github.com/vim-scripts/openssl.vim)


