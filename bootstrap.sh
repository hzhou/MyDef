C='\033[0;32m'
NC='\033[0m'

if [ -z "$MYDEFLIB" ]; then
    printf "\n${C}#---- New install, set PERL5LIB, MYDEFLIB, and PATH ----${NC}\n"
    NEWINSTALL=1
    install -d $HOME/bin
    install -d $HOME/lib/perl5
    install -d $HOME/lib/MyDef
    install -m555 bootstrap/script/mydef_install $HOME/bin/

    PATH=$HOME/bin:/bin:/usr/bin:/usr/local/bin
    export PERL5LIB=$HOME/lib/perl5
    export MYDEFLIB=$HOME/lib/MyDef
fi

printf "\n${C}#---- Install from bootstrap [Perl package] ----${NC}\n"
for a in parseutil compileutil dumpout utils output_perl; do
    touch bootstrap/lib/MyDef/$a.pm
done
touch bootstrap/lib/MyDef.pm
touch bootstrap/script/mydef_make
touch bootstrap/script/mydef_page
mydef_install bootstrap/script $HOME/bin -
mydef_install bootstrap/lib    $HOME/lib/perl5 pm
mydef_install deflib           $HOME/lib/MyDef def

printf "\n${C}#---- Compile from fresh MyDef source ----${NC}\n"
mydef_make
touch mydef.def
make
# In case some system do not record file stamps higher than 1 sec.
sleep 1

printf "\n${C}#---- Install updated MyDef ----${NC}\n"
mydef_install MyDef/lib    . pm
mydef_install MyDef/script . -

if [ "$NEWINSTALL" = 1 ]; then
    printf "\n${C}#---- MyDef INSTALLED ----${NC}\n"
    echo "By Default, MyDef is intalled in $HOME/bin and $HOME/lib"
    echo "    to use MyDef, you need:" 
    echo "    * add $HOME/bin to your PATH"
    echo "    * set PERL5LIB=$HOME/lib/perl5"
    echo "    * set MYDEFLIB=$HOME/lib/MyDef"
    echo "    * set MYDEFSRC=`pwd`"
    echo "    It is recommended to set them in your ~/.bashrc"
fi
