Documentation are now available at http://huizhou.gitbooks.io/programming-with-mydef/

MyDef is not a new programming language. It is an additional layer on top of your programming language -- a layer that can do almost anything without affecting the demands of the underlying language. The layer can be very thin, in which case you still write your code exactly the same way you used to. And you should if you never had complain in programming career. But if you do, MyDef allows you to do something about it. 

* I have always complained about semicolons. Now with MyDef, I don't type them anymore. 
* I have complained about curly braces. Now with MyDef, I avoided them, along with the grammatical parentheses.
* I have wished to refactor my code without worry about variable scopes. MyDef allows me to refactor with no side effects.
* I have wished a less uglier way to write JavaScript, with MyDef, I liked the new look.
* etc.

And they are not on/off switches. You may start refactor part of your code, and simply paste the rest of your legacy code. Unlike other programming language which will tell you what to do, often strictly, you just do what you want to do in MyDef. You do need know what you want to do in this case.

I cannot show you the freedom unless you feel the restriction. Before you ask what good does MyDef can buy you, recall what bad you have complained. MyDef offers solutions -- without changing your language and still allowing collaboration with your fellow coworkers even when they are stuck in their primal language. 

MyDef is not just syntax, it is about paradigm. If you have a vision on how you think to program, MyDef can realize them. Contrary to what others teach you, you don't need classes to do object oriented programming, you don't need first-class functions to do functional programming. You program in objects when you are thinking in objects, and you program functionally when you are thinking in functions. Do you want a language restrict you on how to think? MyDef liberates you.

INSTALL
=======

0. Dependency: 

        perl -- base language
        make, sh, git -- covenience requirement, only tested with GNU make, bash
        vim -- optional, but you need an editor that supports indentation, syntax, and short-cut keys

1. MyDef currently is in perl. First setup a custome installation environment:

        PATH=$PATH:$HOME/bin
        PERL5LIB=$HOME/lib/perl5
        MYDEFLIB=$HOME/lib/MyDef
        export PATH PERL5LIB MYDEFLIB

    The purpose is to install into one's home directory rather than system folders. I assume you will know how to change it into any installation destination.

2. Now install it:

        sh bootstrap.sh

3. If you haven't, read the documentation: http://huizhou.gitbooks.io/programming-with-mydef

4. Try it. e.g.

        $ vim t.def
        page: t
            $print Hello World!

        $ mydef_run t.def

5. If you use vim, there is simple mydef syntax.

        $ vim ~/.vim/filetype.vim
        augroup filetypedetect
        au BufNewFile,BufRead *.def setf mydef
        augroup END
        $ ln -s /path/to/MyDef/docs/mydef.vim ~/.vim/syntax/

    lastly, in .vimrc, I would consider minimally:

        :set shiftwidth=4
        :set expandtab 
        :nmap <F5> :!mydef_run %<CR>

6. Set those environment variables in step 1 in your login shell's startup file. In addition, set:

        MYDEFSRC=[your MyDef path]
        export MYDEFSRC

  This is needed when you install or develop specific output modules.

More Output Modules
===================

This repository only contains the general and perl output modules. You can use the general output module for any text based code. However, there are specialized output modules for various programming languages. For example, if you are working with C/C++ code, you may want to try the output_c module: https://github.com/hzhou/output_c. 
