use strict;
package MyDef::output_ino;
use MyDef::output_c;
sub get_interface {
    return (\&init_page, \&parsecode, \&MyDef::output_c::set_output, \&modeswitch, \&dumpout);
}
sub modeswitch {
    my ($mode, $in)=@_;
}
sub init_page {
    my ($page)=@_;
    if(!$page->{type}){
        $page->{type}="ino";
    }
    my ($ext, $c_init_mode) = MyDef::output_c::init_page(@_);
    return ($ext, "sub");
}
sub parsecode {
    my ($l)=@_;
    if($l=~/^\$eval\s+(\w+)(.*)/){
        my ($codename, $param)=($1, $2);
        $param=~s/^\s*,\s*//;
        my $t=MyDef::compileutil::eval_sub($codename);
        eval $t;
        if($@){
            print "Error [$l]: $@\n";
            print "  $t\n";
        }
        return;
    }
    return MyDef::output_c::parsecode($l);
}
sub dumpout {
    my ($f, $out, $pagetype)=@_;
    MyDef::output_c::dumpout($f, $out, $pagetype);
}
1;
