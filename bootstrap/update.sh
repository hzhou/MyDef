cp -rv ../MyDef/lib ../MyDef/script ./

for a in compileutil.pm  dumpout.pm  output_general.pm  output_perl.pm  parseutil.pm  regex.pm  utils.pm; do
    cp -v $HOME/lib/perl5/MyDef/$a lib/MyDef/
done

cp -v $HOME/lib/MyDef/std_perl.def deflib/
