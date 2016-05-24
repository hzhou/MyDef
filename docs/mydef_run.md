# Quick Workflow with mydef_run

When I explain to people how MyDef works -- you edit .def source, run mydef_page to produce the actual source code in your targeted language, run compiler of your targeted language, and run the final executables -- it sounds quite complicated. However in reality of my experience, most of the time is simply edit code and press F5 to run. It doesn't matter how many layers are involved in the work flow, as long as your editor is capable of rudimentary customization, all it mean to you is setup once, and a single key press to remember.

In fact, this is nothing new. Almost any compiler, from GCC to Perl interpreter, they all go through multiple layers before they produce actual code that runs. Of course in these typical scenerio, those layers are hidden from you. Out of sight, out of mind. The philosophy of MyDef is to hide nothing, so it always try to show you what is really going on and allow you the ability to peak and tweak at each layer. It only seems complicated to the novice; but nevertheless, novice needs help or get deterred.

So I am going to show you one of my typical setup for quick code. It is by no mean to be the only workflow, but since it works for me, it may as well work for you.

1. Use vim. 
I use vim, and I know how to use vim. If you use another editor and assume you know how to use it, simply use this document as reference.

2. Add a shortcut key.
In my case, that is to add following line in ~/.vimrc:

        :nmap <F5> :!mydef_run %<CR>

`mydef_run` is a simple script that *guesses* your intended workflow and runs them for you. In my case, if it is C, it runs mydef_page, gcc, and finally runs the executable. Did I mention it is a simple script and it *guesses* your intention? There is nothing magic there; if it doesn't fit your workflow, simply edit mydef_run.def in your MyDef source tree and customize to your way -- make it more sophiscated if you would like.

3. You are all set!

## Quick Demo

Let's say you want to dump a list from reddit homepage.

1. wget -O t.html www.reddit.com

2. vim t.def (t is my favorate name for anything quick or temorary)

    include: c/files.def
    include: c/regex.def

    page: test, basic_frame
        module: c

        s_file="t.html"

        $call stat_file, s_file
        n=$(fsize)
        $local_allocate(n+1, 0) s

        &call open_r, s_file
            fread(s, 1, n, file_in)

        $while s=~/class="title [^"]*" href="(http[^"]*)"/g
            $regex_capture ts_url
            $print link: $ts_url

3. ":w" and hit <F5>

    PAGE: test
      --> [./test.c]
    gcc -otest ./test.c  -lpcre && ./test
    link: http://i.imgur.com/JmlEcvO.jpg
    link: http://edition.cnn.com/2016/05/24/middleeast/isis-offensive-raqq a/index.html
    ...

Of course your experience may not as smooth as this. Your code may not compile either at MyDef compilation or gcc compilation or it conatains run-time bugs. All it means is to re-edit and re-press <F5>, rinse and repeat. I can't help you there, but there you are doing *real* work, aren't you?

