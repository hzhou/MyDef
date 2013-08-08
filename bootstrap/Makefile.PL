use 5.008001;
use ExtUtils::MakeMaker;
my @scripts=glob("script/*");
WriteMakefile(
    ABSTRACT          => 'A higher language system',
    AUTHOR            => 'Hui Zhou <hzhou@hzsolutions.net>',
    NAME              => 'MyDef',
    VERSION           => 0.2,
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1;
    EXE_FILES         => \@scripts,
);
package MY;
sub install{
    my $t=shift->SUPER::install(@_);
    $t=~s/(?<=install :: )/def_install /;
    return $t;
}
sub postamble {
    my @defs=glob("deflib/*.def");
    my @deflist;
    my $t="\$(INSTALL_BASE)/lib/MyDef:\n";
    $t.="\tinstall -d \$(INSTALL_BASE)/lib/MyDef\n\n";
    push @deflist, "\$(INSTALL_BASE)/lib/MyDef";
    foreach my $def(@defs){
        if($def=~/.*\/(\S+).def/){
            push @deflist, "\$(INSTALL_BASE)/lib/MyDef/$1.def";
            $t.="\$(INSTALL_BASE)/lib/MyDef/$1.def: deflib/$1.def\n";
            $t.="\tinstall  deflib/$1.def \$(INSTALL_BASE)/lib/MyDef/$1.def\n\n";
        }
    }
    $t.="def_install :: ".join(" ", @deflist)."\n\t\$(NOECHO) \$(NOOP)\n\n";
    return $t;
}
