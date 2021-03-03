C='\033[0;32m'
NC='\033[0m'

if [ -z "$MYDEFLIB" ]; then
    printf "\n${C}#---- New install ----${NC}\n"
    NEWINSTALL=1
else
    printf "\n${C}#---- Install Path ----${NC}\n"
    echo PATH:     $PATH
    echo PERL5LIB: $PERL5LIB
    echo MYDEFLIB: $MYDEFLIB
    save_PATH=$PATH
    save_PERL5LIB=$PERL5LIB
    save_MYDEFLIB=$MYDEFLIB
fi

BOOT=mydef_boot
export PATH=$BOOT/bin:$PATH
export PERL5LIB=$BOOT/lib/perl5
export MYDEFLIB=$BOOT/lib/MyDef

printf "\n${C}#---- Compile from fresh MyDef source ----${NC}\n"
perl $BOOT/bin/mydef_make
touch *.def
make

printf "\n${C}#---- Install updated MyDef ----${NC}\n"
if [ "$NEWINSTALL" = 1 ]; then
    bin_dir=$HOME/bin
    lib_dir=$HOME/lib

    install -d $bin_dir
    install -d $lib_dir
    install -d $lib_dir/perl5
    install -d $lib_dir/MyDef

    export PATH=$bin_dir:$PATH
    export PERL5LIB=$lib_dir/perl5
    export MYDEFLIB=$lib_dir/MyDef
else    
    export PATH=$save_PATH
    export PERL5LIB=$save_PERL5LIB
    export MYDEFLIB=$save_MYDEFLIB
fi

MY_INSTALL="perl MyDef/script/mydef_install"
$MY_INSTALL deflib       . def
$MY_INSTALL MyDef/lib    . pm
$MY_INSTALL MyDef/script . -

if [ "$NEWINSTALL" = 1 ]; then
    printf "\n${C}#---- MyDef INSTALLED ----${NC}\n"
    echo "By Default, MyDef is intalled in $bin_dir and $lib_dir"
    echo "    to use MyDef, you need:" 
    echo "    * add $bin_dir to your PATH"
    echo "    * set PERL5LIB=$lib_dir/perl5"
    echo "    * set MYDEFLIB=$lib_dir/MyDef"
    echo "    * set MYDEFSRC=`pwd`"
    echo "    It is recommended to set them in your ~/.bashrc"
fi
