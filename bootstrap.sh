#!/bin/sh
cd bootstrap
perl Makefile.PL INSTALL_BASE=$HOME #pmake
make install
cd ..
mydef_install deflib .
mydef_make # MyDef, perl
touch perlmake.def mydef.def
make
cd MyDef
perl Makefile.PL INSTALL_BASE=$HOME #pmake
cd ..
mydef_make
make install

