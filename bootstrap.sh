C='\033[0;32m'
NC='\033[0m'

MY_INSTALL="perl bootstrap/script/mydef_install"

if [ -z "$MYDEFLIB" ]; then
    printf "\n${C}#---- New install, set PERL5LIB, MYDEFLIB, and PATH ----${NC}\n"
    NEWINSTALL=1
    install -d $HOME/bin
    install -d $HOME/lib/perl5
    install -d $HOME/lib/MyDef

    PATH=$HOME/bin:$PATH
    export PERL5LIB=$HOME/lib/perl5
    export MYDEFLIB=$HOME/lib/MyDef
fi

printf "\n${C}#---- Install from bootstrap ----${NC}\n"
for a in parseutil compileutil dumpout utils output_perl; do
    touch bootstrap/lib/MyDef/$a.pm
done
touch bootstrap/lib/MyDef.pm
touch bootstrap/script/mydef_make
touch bootstrap/script/mydef_page
$MY_INSTALL bootstrap/script . -
$MY_INSTALL bootstrap/lib    . pm
$MY_INSTALL bootstrap/deflib . def
$MY_INSTALL -f deflib        . def
# In case some system do not record file stamps higher than 1 sec.

if [ -z $1 ]; then # so "sh bootstrap.sh skip" will skip these
    sleep 1
    printf "\n${C}#---- Compile from fresh MyDef source ----${NC}\n"
    perl bootstrap/script/mydef_make
    touch *.def
    make
    printf "\n${C}#---- Install updated MyDef ----${NC}\n"
    $MY_INSTALL MyDef/lib    . pm
    $MY_INSTALL MyDef/script . -
fi

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
