use strict;
package MyDef::output_win32;
use MyDef::dumpout;
use MyDef::output_c;
sub get_interface {
    return (\&init_page, \&MyDef::output_c::parsecode, \&MyDef::output_c::set_output, \&MyDef::output_c::modeswitch, \&dumpout);
}
sub init_page {
    my @ret = MyDef::output_c::init_page(@_);
    MyDef::output_c::global_add_symbol("cur_instance", "HINSTANCE");
    return @ret;
}
sub dumpout {
    my ($f, $out)=@_;
    my $extern;
    my $func=$MyDef::output_c::functions{"WinMain"};
    if($func){
        $func->{skip_declare}=1;
        $func->{ret_type}="int APIENTRY";
        $func->{param_list}=["HINSTANCE hInst", "HINSTANCE hPrev", "LPSTR s_cmdline", "int n_cmdshow"];
        push @{$func->{init}}, "cur_instance=hInst;";
        push @{$func->{init}}, "DUMP_STUB main_init";
        push @{$func->{finish}}, "DUMP_STUB main_exit";
        push @{$func->{finish}}, "return 0;";
    }
    else{
        $extern="extern ";
    }
    push @MyDef::output_c::global_list, $extern."HINSTANCE cur_instance";
    push @$f, "#define WIN32_LEAN_AND_MEAN\n";
    push @$f, "#include <windows.h>\n";
    MyDef::output_c::dumpout($f, $out);
}
1;
