use strict;
use MyDef::output_c;

package MyDef::output_win32;
our $out;
our $debug;

sub get_interface {
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout);
}
sub set_output {
    my ($newout)=@_;
    $out = $newout;
    MyDef::output_c::set_output($newout);
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
    if($l=~/^DEBUG (\w+)/){
        if($1 eq "OFF"){
            $debug=0;
        }
        else{
            $debug=$1;
        }
        return MyDef::output_c::parsecode($l);
    }
    elsif($l=~/^\$eval\s+(\w+)(.*)/){
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
        $MyDef::output_c::has_main=1;
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
            if($1 ne "m"){
                push @$f, "#pragma comment(lib, \"$1\")\n";
                $MyDef::output_c::objects{$i}=undef;
            }
        }
    }
    MyDef::output_c::dumpout($f, $out, $pagetype);
}
1;
