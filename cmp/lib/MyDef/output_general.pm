use MyDef::dumpout;
package MyDef::output_general;
my $debug;
sub get_interface {
    return (\&init_page, \&parsecode, \&modeswitch, \&dumpout);
}
sub init_page {
    my ($page)=@_;
    my $ext="txt";
    if($page->{type}){
        $ext=$page->{type};
    }
    return ($ext, "sub");
}
sub modeswitch {
    my ($pmode, $mode, $out)=@_;
}
sub parsecode {
    my ($l, $mode, $out)=@_;
    if($debug eq "parse"){
        my $yellow="\033[33;1m";
        my $normal="\033[0m";
        print "$yellow parsecode: [$l]$normal\n";
    }
    if($l=~/^DEBUG (\w+)/){
        if($1 eq "OFF"){
            $debug=0;
        }
        else{
            $debug=$1;
        }
    }
    push @$out, $l;
}
sub dumpout {
    my ($f, $out)=@_;
    my $dump={out=>$out,f=>$f};
    MyDef::dumpout::dumpout($dump);
}
1;
