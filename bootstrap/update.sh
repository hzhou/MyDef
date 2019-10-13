lib=$HOME/lib/perl5/MyDef
def=$HOME/lib/MyDef

cp -rv ../MyDef/lib ../MyDef/script ./

for a in compileutil.pm  dumpout.pm  output_general.pm  output_perl.pm  parseutil.pm  regex.pm  utils.pm; do
    cp -v $lib/$a lib/MyDef/
done

cp -v $def/std_perl.def deflib/

A_set="c cpp java fortran sh python php js www go rust pascal"
A_set="$A_set xs win32 win32rc ino glsl plot"
A_set="$A_set awk asm tcl lua latex tex as matlab"
for a in $A_set; do
    if test -f $lib/output_$a.pm; then
        cp -v $lib/output_$a.pm all_lib/MyDef/
        cp -v $def/std_$a.def all_deflib/
    fi
done

