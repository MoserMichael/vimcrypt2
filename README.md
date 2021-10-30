# VIMCRYPT2 vim plugin - encrypt your files with openssl

I had my adaptation for encrypting/decrypting files with vim [VIMCRYPPT](https://github.com/MoserMichael/vimcrypt), now it has a problem: you need to enter the encryption key every time that the file is read/decrypted and every time that the file is saved/encryted.

Now it is quite possible to make a typo, while saving the file. In this event you might have lost your precious file, as you may no longer be aware of the current encryption key.

One fix might be to make a backup before saving the file, in this event you may be lucky with the backup.

The VIMCRYPT2 plugin solves the issue as follows:

- After decrypting a file, we take the decryption key and save it in memory. Now the key is not kept in plain text form, it is encrypted with a master key, the master key is a random  key that is generated per editor session.
- The very same key that has been used for decryption is then used for encryption, when the file is saved back to disk.
- The key is passed to openssl via a pipe, and not via a command line option. It would be visible to anyone, as a command line option, it is less exposed, as it is passed via a pipe. Now this can't be done with vimscript, that's were we need to use python3;

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

$ /usr/local/opt/openssl/bin/openssl version
OpenSSL 3.0.0 7 sep 2021 (Library: OpenSSL 3.0.0 7 sep 2021)
```

Now the interesting detail: the output of these two utilities can't be mixed.

The following command encrypts and decrypts a string with the same password, while using the same libre ssl version of openssl

```
echo '123' | openssl enc -e -aes-256-ecb -pass pass:blabla | /usr/bin/openssl enc -d -aes-256-ecb -pass pass:blabla 
```

However the same does not work, if you  try to decrypt the output of the libre ssl fork with a different utility from OpenSSL.

```
echo '123' | /usr/local/opt/openssl/bin/openssl enc -e -aes-256-ecb -pass pass:blabla | /usr/bin/openssl enc -d -aes-256-ecb -pass pass:blabla
<error error error>

echo '123' | /usr/bin/openssl enc -e -aes-256-ecb -pass pass:blabla | /usr/local/opt/openssl/bin/openssl enc -d -aes-256-ecb -pass pass:blabla
<error error error>

```

This is something that should be remembered, when moving encrypted files from location to location.


