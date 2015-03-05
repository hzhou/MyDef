use strict;
package MyDef::output_win32;
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
        $page->{type}="c";
    }
    MyDef::output_c::init_page(@_);
    MyDef::output_c::parsecode("\$global HINSTANCE cur_instance");
    MyDef::output_c::parsecode("\$global HWND hwnd_main");
    return $page->{init_mode};
}
sub parsecode {
    my ($l)=@_;
    if($l=~/^\$eval\s+(\w+)(.*)/){
        my ($codename, $param)=($1, $2);
        $param=~s/^\s*,\s*//;
        my $t=MyDef::compileutil::eval_sub($codename);
        eval $t;
        if($@ and !$MyDef::compileutil::eval_sub_error{$codename}){
            $MyDef::compileutil::eval_sub_error{$codename}=1;
            print "evalsub - $codename\n";
            print "[$t]\n";
            print "eval error: [$@] package [", __PACKAGE__, "]\n";
        }
        return;
    }
    return MyDef::output_c::parsecode($l);
}
sub dumpout {
    my ($f, $out, $pagetype)=@_;
    my $extern;
    my $winmain=$MyDef::output_c::functions{"WinMain"};
    if($winmain){
        $winmain->{skip_declare}=1;
        $winmain->{ret_type}="int APIENTRY";
        $winmain->{param_list}=["HINSTANCE hInst", "HINSTANCE hPrev", "LPSTR s_cmdline", "int n_cmdshow"];
        push @{$winmain->{init}}, "cur_instance=hInst;";
        push @{$winmain->{init}}, "DUMP_STUB main_init";
        push @{$winmain->{finish}}, "DUMP_STUB main_exit";
        push @{$winmain->{finish}}, "return 0;";
    }
    if(!$winmain){
        $MyDef::output_c::global_hash->{cur_instance}->{attr}="extern";
        $MyDef::output_c::global_hash->{hwnd_main}->{attr}="extern";
    }
    push @$f, "#define _CRT_SECURE_NO_WARNINGS\n";
    push @$f, "#define WIN32_LEAN_AND_MEAN\n";
    push @$f, "#include <windows.h>\n";
    foreach my $i (keys %MyDef::output_c::objects){
        if($i=~/^lib(.*)/){
            push @$f, "#pragma comment(lib, \"$1\")\n";
            $MyDef::output_c::objects{$i}=undef;
        }
    }
    MyDef::output_c::dumpout($f, $out, $pagetype);
}
1;
