#!/bin/sh

C='\033[0;32m'
NC='\033[0m'

printf "\n${C}#---- install from bootstrap Perl package ----${NC}\n"

cd bootstrap
perl Makefile.PL INSTALL_BASE=$HOME #pmake
make install
cd ..

if [ -z "$MYDEFLIB" ]; then
    NEWINSTALL=1
    PATH=$HOME/bin:/bin:/usr/bin:/usr/local/bin
    export PERL5LIB=$HOME/lib/perl5
    export MYDEFLIB=$HOME/lib/MyDef
fi

printf "\n${C}#---- install MyDef library ---------------${NC}\n"

mydef_install deflib $HOME/lib/MyDef

printf "\n${C}#---- Compile MyDef source into Perl package ----${NC}\n"

mydef_make # MyDef, perl
#    note: only those source files that are newer will get updated
touch perlmake.def mydef.def
make

printf "\n${C}#---- Install updated MyDef Perl package ----${NC}\n"

cd MyDef
perl Makefile.PL INSTALL_BASE=$HOME #pmake
cd ..
mydef_make
make install

if [ "$NEWINSTALL" = 1 ]; then
    echo "# ----------------------------------------------------"
    echo "By Default, MyDef is intalled in $HOME/bin and $HOME/lib"
    echo "    to use MyDef, you need add $HOME/bin to your PATH"
    echo "    and set PERL5LIB=$HOME/lib/perl5 and MYDEFLIB=$HOME/lib/MyDef"
    echo "    you may also need to set MYDEFSRC=$(pwd) used for installing output modules"
    echo "    It is recommended to set them in your ~/.bashrc"
fi
