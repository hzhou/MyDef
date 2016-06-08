#!/bin/sh

# install from bootstrap
cd bootstrap
perl Makefile.PL INSTALL_BASE=$HOME #pmake
make install
cd ..

PERL5LIB=$HOME/lib/perl5
MYDEFLIB=$HOME/lib/MyDef

# install deflib 
$HOME/bin/mydef_install deflib $HOME/lib/MyDef

# compile from source
#    note: only those source files that are newer
$HOME/bin/mydef_make # MyDef, perl
touch perlmake.def mydef.def
make

# install the updated version
cd MyDef
perl Makefile.PL INSTALL_BASE=$HOME #pmake
cd ..
$HOME/bin/mydef_make
make install

echo "# ----------------------------------------------------"
echo "By Default, MyDef is intalled in $HOME/bin and $HOME/lib"
echo "    to use MyDef, you need add $HOME/bin to your PATH"
echo "    and set PERL5LIB=$HOME/lib/perl5 and MYDEFLIB=$HOME/lib/MyDef"
echo "    It is recommended to set them in your ~/.bashrc"
