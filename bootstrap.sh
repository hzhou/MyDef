#!/bin/sh

# install from bootstrap
cd bootstrap
perl Makefile.PL INSTALL_BASE=$HOME #pmake
make install
cd ..

# install deflib 
mydef_install deflib .

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

