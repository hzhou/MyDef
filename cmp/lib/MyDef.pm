use strict;
package MyDef;
our $def;
our $page;
our $var={};
use MyDef::parseutil;
use MyDef::compileutil;
import_config("config");
if($ENV{MYDEFLIB}){
    $var->{include_path}.=":$ENV{MYDEFLIB}";
}
sub init {
    my (%config)=@_;
    while(my ($k, $v) = each %config){
        $var->{$k}=$v;
    }
    my $module=$var->{module};
    if(!$module){
        die "Module type not defined in config!\n";
    }
    elsif($module eq "www"){
        require MyDef::output_www;
        MyDef::compileutil::set_interface(MyDef::output_www::get_interface());
    }
    elsif($module eq "c"){
        require MyDef::output_c;
        MyDef::compileutil::set_interface(MyDef::output_c::get_interface());
    }
    elsif($module eq "xs"){
        require MyDef::output_xs;
        MyDef::compileutil::set_interface(MyDef::output_xs::get_interface());
    }
    elsif($module eq "apple"){
        require MyDef::output_apple;
        MyDef::compileutil::set_interface(MyDef::output_apple::get_interface());
    }
    elsif($module eq "win32"){
        require MyDef::output_win32;
        MyDef::compileutil::set_interface(MyDef::output_win32::get_interface());
    }
    elsif($module eq "win32rc"){
        require MyDef::output_win32rc;
        MyDef::compileutil::set_interface(MyDef::output_win32rc::get_interface());
    }
    elsif($module eq "perl"){
        require MyDef::output_perl;
        MyDef::compileutil::set_interface(MyDef::output_perl::get_interface());
    }
    elsif($module eq "js"){
        require MyDef::output_js;
        MyDef::compileutil::set_interface(MyDef::output_js::get_interface());
    }
    elsif($module eq "general"){
        require MyDef::output_general;
        MyDef::compileutil::set_interface(MyDef::output_general::get_interface());
    }
    elsif($module eq "glsl"){
        require MyDef::output_glsl;
        MyDef::compileutil::set_interface(MyDef::output_glsl::get_interface());
    }
    else{
        die "Undefined module type $module\n";
    }
}
sub addpath {
    my ($path)=@_;
    $var->{path}=$path;
}
sub createpage_lines {
    my ($pagename)=@_;
    $page=$def->{pages}->{$pagename};
    my ($plines, $ext)=MyDef::compileutil::compile;
    return $plines;
}
sub createpage {
    my ($pagename)=@_;
    $page=$def->{pages}->{$pagename};
    my ($plines, $ext)=MyDef::compileutil::compile;
    MyDef::compileutil::output($plines, $ext);
}
sub import_data_lines {
    my $plines=shift;
    $def= MyDef::parseutil::import_data_lines($plines, $var);
}
sub import_data {
    my $file=shift;
    $def= MyDef::parseutil::import_data($file, $var);
}
sub is_sub {
    my $subname=shift;
    if($page->{codes}->{$subname}){
        return 1;
    }
    elsif($def->{codes}->{$subname}){
        return 1;
    }
    else{
        return 0;
    }
}
sub import_config {
    my ($file)=@_;
    open In, $file or return;
    while(<In>){
        if(/^(\w+):\s*(.*\S)/){
            $var->{$1}=$2;
        }
    }
    close In;
}
1;
