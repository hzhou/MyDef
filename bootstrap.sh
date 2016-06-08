#!/bin/sh

# install from bootstrap
cd bootstrap
perl Makefile.PL INSTALL_BASE=$HOME #pmake
make install
cd ..

PATH=$HOME/bin:/bin:/usr/bin:/usr/local/bin
export PERL5LIB=$HOME/lib/perl5
export MYDEFLIB=$HOME/lib/MyDef

# install deflib 
mydef_install deflib $HOME/lib/MyDef

# compile from source
#    note: only those source files that are newer
mydef_make # MyDef, perl
touch perlmake.def mydef.def
make

# install the updated version
cd MyDef
perl Makefile.PL INSTALL_BASE=$HOME #pmake
cd ..
mydef_make
make install

echo "# ----------------------------------------------------"
echo "By Default, MyDef is intalled in $HOME/bin and $HOME/lib"
echo "    to use MyDef, you need add $HOME/bin to your PATH"
echo "    and set PERL5LIB=$HOME/lib/perl5 and MYDEFLIB=$HOME/lib/MyDef"
echo "    you may also need to set MYDEFSRC=$(pwd) used for installing output modules"
echo "    It is recommended to set them in your ~/.bashrc"
