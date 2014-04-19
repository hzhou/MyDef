#!/bin/sh
cd cmp
perl Makefile.PL INSTALL_BASE=$HOME #pmake
make install
cd ..
perl install_def.pl
mydef_make.pl # MyDef, perl
touch perlmake.def mydef.def
make
cd MyDef
perl Makefile.PL INSTALL_BASE=$HOME #pmake
cd ..
make install

