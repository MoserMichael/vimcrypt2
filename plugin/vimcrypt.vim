if exists("vimcrypt_encrypted_loaded")
    finish
endif
let vimcrypt_encrypted_loaded = 1

" use openssl to encrypt decrypt files.
" copied/adapted from https://github.com/vim-scripts/openssl.vim/blob/master/plugin/openssl.vim
" my changes;
"   - use aes-ecb instead of aes-cbc. Reason: if file gets damaged then with cbc
"   everything is lost after the damage point, ecb mode is good enough for text)
"   - turn off shelltemp and undofile when working with encrypted stuff.
"   - throw out the password safe stuff, I don't need it.
"   - exclude vulnerable ciphers from the list of supported file extensions


python3 <<EOF

import vim
import os
import shlex
import subprocess
import time

#openssl_bin="/usr/local/opt/openssl/bin/openssl"
openssl_bin="openssl"

class RunCommand:
    trace_on = False
    exit_on_error = True

    #    @staticmethod
    #    def trace(on_off):
    #        RunCommand.trace_on = on_off
    #
    #    @staticmethod
    #    def exit_on_error(on_off):
    #        RunCommand.exit_on_error = on_off
    #
    def __init__(self):
        self.exit_code = 0
        self.command_line = ""

    def __stdin(self, arg):
        if not arg is None:
            return subprocess.PIPE
        return None

    def __input(self, arg):
        if not arg is None:
            if isinstance(arg,str):
                return arg.encode("utf-8")
            if isinstance(arg,bytes):
                return arg

        return None

    def run(self, command_line, in_arg = None):
        try:
            if RunCommand.trace_on:
                print(">", command_line)

            with subprocess.Popen(
                shlex.split(command_line),
                stdin=self.__stdin(in_arg),
                close_fds=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            ) as process:

                self.command_line = command_line

                (output, error_out) = process.communicate(input=self.__input(in_arg))

                self.exit_code = process.wait()
                if isinstance(output,str):
                    self.output = output.decode("utf-8")
                else:
                    self.output = output

                if isinstance(error_out,str):
                    self.error_out = error_out.decode("utf-8")
                else:
                    self.error_out = error_out

                self.exit_code = process.wait()

                if RunCommand.trace_on:
                    msg = ">exit_code: " + str(self.exit_code)
                    if self.output != "":
                        msg += "\n  stdout: " + self.output
                    if self.error_out != "":
                        msg += "\n  stderr: " + self.error_out
                    print(msg)

                if RunCommand.exit_on_error and self.exit_code != 0:
                    print(self.make_error_message())
                    sys.exit(1)

                return self.exit_code
        except FileNotFoundError:
            self.output = ""
            self.error_out = "file not found"
            self.exit_code = 1
            return self.exit_code

    def result(self):
        return self.exit_code, self.output

    def make_error_message(self):
        return_value = ""
        if self.command_line != "":
            return_value += f" command line: {self.command_line}."
        if self.exit_code != 0:
            return_value += f" exit status: {self.exit_code}. "
        if self.error_out != "":
            if isinstance(self.error_out,str):
                return_value += " " + self.error_out
            else:
                return_value += " " + bytes.hex(self.error_out)

        return return_value


def _prompt_key(action):
    while True:
        key = vim.eval("inputsecret('Enter key: ')")
        if action == 'read':
            return key
        key_verify = vim.eval("inputsecret('Verify key: ')")
        if key == key_verify:
            return key
        vim.eval("echo 'keys do not match'")

def _prepare_read_pipe(key):
    read_end, write_end = os.pipe()
    os.write(write_end, bytes(key, encoding='utf-8'))
    os.close(write_end)

    os.set_inheritable(read_end, True)
    return os.fdopen(read_end, mode='rt', encoding='utf-8')

def _key_op(op, master_key, key):

    with _prepare_read_pipe(master_key) as read_file:
        cmd = RunCommand()

        action = ""
        if op == 'enc':
            action = '-e'
            cmd.run(f"{openssl_bin} enc {action} -aes-256-ecb -pass fd:{read_file.fileno()}" , bytes(key, 'utf-8'))  #| xxd -p -c 128" 
            if cmd.exit_code == 0:
                key = bytes.hex(cmd.output)
                return key
        elif op == 'dec':
            action = '-d'
            #key = binascii.unhexlify( key )
            key_bin = bytes.fromhex(key)
            cmd.run(f"{openssl_bin} enc {action} -aes-256-ecb -pass fd:{read_file.fileno()}", key_bin)
            raw_key = cmd.output.decode('utf-8')
            return raw_key

        else:
            return ''

#    read_end, write_end = os.pipe()
#    write_file = os.fdopen(write_end,'w')
#    write_file.write(master_key)
#    write_file.close()
#    fd_str=str(read_end)
#    cmd.run(f"{openssl_bin} enc {action} -aes-256-ecb -pass fd:{fd_str}", key)


    if cmd.exit_code == 0:
       return binascii.hexlify( cmd.output )

    return None


def run_enc_dec(action):

    try:
        cipher = vim.eval( 'expand("%:e")' )
        master_key = vim.eval("g:open_ssl_mkey")
        buf_key = vim.eval("g:openssl_enc_key2")

        if buf_key == '':
            key = _prompt_key(action)
            ret_val = _key_op('enc', master_key, key)
            vim.command("let g:openssl_enc_key2 = '" + ret_val + "'")
        else:
            key = _key_op('dec', master_key, buf_key)
            vim.command("let g:openssl_enc_key2 = ''")


        with _prepare_read_pipe(key) as read_file:

            if cipher == "aes":
               cipher = "-aes-256-ecb"

            if action == 'write':
                ocmd = f"0,$!{openssl_bin} enc {cipher} -e -salt -pass fd:{read_file.fileno()}"
            else:
                ocmd = f"0,$!{openssl_bin} enc {cipher} -d -salt -pass fd:{read_file.fileno()}"

            vim.command('let l:expr = "' + ocmd + '"')
            vim.command(ocmd) 

        key = ''
        return ocmd

    except vim.error as ex:
        print("Error: " + str(ex))
#       vim.command("echo '" + str(ex) + "'")
#       time.sleep(5)

    return ""

EOF

let g:open_ssl_mkey = ''

function! s:OpenSSLGetMKey()
    if g:open_ssl_mkey == ''
        if !executable("openssl")
            echo "Can't find openssl. can't encrypt/decrypt"
        else
            let g:open_ssl_mkey = system("openssl rand -hex 9")
        let g:open_ssl_mkey = substitute(g:open_ssl_mkey, '\n\+$', '', '')
        endif
    endif
endfunction

function! s:OpenSSLReadPre()
    set cmdheight=3
    set viminfo=
    if &undofile != 0
        set noundofile
    endif
    if &swapfile != 0
        set noswapfile
    endif
    if &shelltemp != 0
        set noshelltemp
    endif
    set shell=/bin/sh
    set bin

    call s:OpenSSLGetMKey()

endfunction

function! s:OpenSSLCheckError(action)
    if v:shell_error
        silent! 0,$y
        silent! undo
        echo "COULD NOT " . a:action . " USING EXPRESSION: " . l:expr
        echo "Note that your version of openssl may not have the given cipher engine built in"
        echo "even though the engine may be documented in the openssl man pages."
        echo "ERROR FROM OPENSSL:"
        echo @"
        echo "COULD NOT ENCRYPT"
        exe 'sleep 5'
        return
    endif
endfunction

function! s:OpenSSLReadPost()

    let l:cipher = expand("%:e")

    if getbufvar("%","openssl_enc_key","$error$") == "$error$"
        let g:openssl_enc_key2 = ''
    else
        let g:openssl_enc_key2 = b:openssl_enc_key
    endif

    python3 run_enc_dec('read')

    " can't access buffer variables from python
    if g:openssl_enc_key2 != ''
        call setbufvar('%', 'openssl_enc_key', g:openssl_enc_key2)
        let g:openssl_enc_key2 = ''
    endif

    call s:OpenSSLCheckError("DECRYPT") 

    set nobin
    set cmdheight&
    set shell&
    execute ":doautocmd BufReadPost ".expand("%:r")
    redraw!
endfunction

function! s:OpenSSLWritePre()

    echo "init"
    call s:OpenSSLReadPre()

    if getbufvar("%","openssl_enc_key","$error$") == "$error$"
        let g:openssl_enc_key2 = ''
    else
        let g:openssl_enc_key2 = b:openssl_enc_key
    endif

    python3 run_enc_dec( 'write' )
    
    call s:OpenSSLCheckError("ENCRYPT") 

endfunction

function! s:OpenSSLWritePost()
    silent! undo
    set nobin
    set shell&
    set cmdheight&
    redraw!
endfunction

if !has("python3")
    echo "Error: python3 is not enabled here, can't encrypt/decrypt"
else
    autocmd BufReadPre,FileReadPre     *.aes,*.cast,*.rc5,*.desx call s:OpenSSLReadPre()
    autocmd BufReadPost,FileReadPost   *.aes,*.cast,*.rc5,*.desx call s:OpenSSLReadPost()
    autocmd BufWritePre,FileWritePre   *.aes,*.cast,*.rc5,*.desx call s:OpenSSLWritePre()
    autocmd BufWritePost,FileWritePost *.aes,*.cast,*.rc5,*.desx call s:OpenSSLWritePost()
endif

