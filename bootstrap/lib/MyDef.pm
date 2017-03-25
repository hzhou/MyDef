use strict;
use MyDef::utils;
use MyDef::parseutil;
use MyDef::compileutil;
use MyDef::dumpout;

package MyDef;
our $def;
our $page;
our $var={};
our $time_start = time();

sub init {
    my (%config) = @_;
    ;
    while(my ($k, $v) = each %config){
        $var->{$k}=$v;
    }
    my $module=$var->{module};
    if(!$module and -f $config{def_file}){
        open In, "$config{def_file}" or die "Can't open $config{def_file}.\n";
        ;
        while(<In>){
            if(/^\s*module:\s+(\w+)\s*$/){
                $var->{module}=$1;
                $module=$1;
            }
        }
        close In;
    }
    if(!$module){
        die "Module type not defined in config!\n";
    }
    elsif($module eq "php"){
        require MyDef::output_php;
        MyDef::compileutil::set_interface(MyDef::output_php::get_interface());
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
    elsif($module eq "general"){
        require MyDef::output_general;
        MyDef::compileutil::set_interface(MyDef::output_general::get_interface());
    }
    elsif($module eq "glsl"){
        require MyDef::output_glsl;
        MyDef::compileutil::set_interface(MyDef::output_glsl::get_interface());
    }
    elsif($module eq "make"){
        require MyDef::output_make;
        MyDef::compileutil::set_interface(MyDef::output_make::get_interface());
    }
    elsif($module eq "ino"){
        require MyDef::output_ino;
        MyDef::compileutil::set_interface(MyDef::output_ino::get_interface());
    }
    elsif($module eq "matlab"){
        require MyDef::output_matlab;
        MyDef::compileutil::set_interface(MyDef::output_matlab::get_interface());
    }
    elsif($module eq "cpp"){
        require MyDef::output_cpp;
        MyDef::compileutil::set_interface(MyDef::output_cpp::get_interface());
    }
    elsif($module eq "plot"){
        require MyDef::output_plot;
        MyDef::compileutil::set_interface(MyDef::output_plot::get_interface());
    }
    elsif($module eq "java"){
        require MyDef::output_java;
        MyDef::compileutil::set_interface(MyDef::output_java::get_interface());
    }
    elsif($module eq "autoit"){
        require MyDef::output_autoit;
        MyDef::compileutil::set_interface(MyDef::output_autoit::get_interface());
    }
    elsif($module eq "python"){
        require MyDef::output_python;
        MyDef::compileutil::set_interface(MyDef::output_python::get_interface());
    }
    elsif($module eq "fortran"){
        require MyDef::output_fortran;
        MyDef::compileutil::set_interface(MyDef::output_fortran::get_interface());
    }
    elsif($module eq "asm"){
        require MyDef::output_asm;
        MyDef::compileutil::set_interface(MyDef::output_asm::get_interface());
    }
    elsif($module eq "go"){
        require MyDef::output_go;
        MyDef::compileutil::set_interface(MyDef::output_go::get_interface());
    }
    else{
        die "Undefined module type $module\n";
    }
}

sub import_data {
    my ($file) = @_;
    $def= MyDef::parseutil::import_data($file);
}

sub createpage {
    my ($pagename) = @_;
    $page=$def->{pages}->{$pagename};
    if($page->{output_path} and !$page->{output_dir}){
        $page->{output_dir}=$page->{output_path};
    }
    my $plines=MyDef::compileutil::compile();
    MyDef::compileutil::output($plines);
}

sub pipe_page {
    my ($module) = @_;
    $var->{module}=$module;
    if(!$module){
        die "Module type not defined in config!\n";
    }
    elsif($module eq "php"){
        require MyDef::output_php;
        MyDef::compileutil::set_interface(MyDef::output_php::get_interface());
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
    elsif($module eq "general"){
        require MyDef::output_general;
        MyDef::compileutil::set_interface(MyDef::output_general::get_interface());
    }
    elsif($module eq "glsl"){
        require MyDef::output_glsl;
        MyDef::compileutil::set_interface(MyDef::output_glsl::get_interface());
    }
    elsif($module eq "make"){
        require MyDef::output_make;
        MyDef::compileutil::set_interface(MyDef::output_make::get_interface());
    }
    elsif($module eq "ino"){
        require MyDef::output_ino;
        MyDef::compileutil::set_interface(MyDef::output_ino::get_interface());
    }
    elsif($module eq "matlab"){
        require MyDef::output_matlab;
        MyDef::compileutil::set_interface(MyDef::output_matlab::get_interface());
    }
    elsif($module eq "cpp"){
        require MyDef::output_cpp;
        MyDef::compileutil::set_interface(MyDef::output_cpp::get_interface());
    }
    elsif($module eq "plot"){
        require MyDef::output_plot;
        MyDef::compileutil::set_interface(MyDef::output_plot::get_interface());
    }
    elsif($module eq "java"){
        require MyDef::output_java;
        MyDef::compileutil::set_interface(MyDef::output_java::get_interface());
    }
    elsif($module eq "autoit"){
        require MyDef::output_autoit;
        MyDef::compileutil::set_interface(MyDef::output_autoit::get_interface());
    }
    elsif($module eq "python"){
        require MyDef::output_python;
        MyDef::compileutil::set_interface(MyDef::output_python::get_interface());
    }
    elsif($module eq "fortran"){
        require MyDef::output_fortran;
        MyDef::compileutil::set_interface(MyDef::output_fortran::get_interface());
    }
    elsif($module eq "asm"){
        require MyDef::output_asm;
        MyDef::compileutil::set_interface(MyDef::output_asm::get_interface());
    }
    elsif($module eq "go"){
        require MyDef::output_go;
        MyDef::compileutil::set_interface(MyDef::output_go::get_interface());
    }
    else{
        die "Undefined module type $module\n";
    }
    $def = MyDef::parseutil::import_data("-pipe");
    my $pagename = $def->{pagelist}->[0];
    if($pagename){
        $page=$def->{pages}->{$pagename};
        my $plines=MyDef::compileutil::compile();
        foreach my $l (@$plines){
            print $l;
        }
    }
}

sub addpath {
    my ($path) = @_;
    $var->{path}=$path;
}

sub is_sub {
    my ($subname) = @_;
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

sub set_page_extension {
    my ($default_ext) = @_;
    my $ext=$default_ext;
    if(exists $var->{filetype}){
        $ext=$var->{filetype};
    }
    if(exists $page->{type}){
        $ext=$page->{type};
    }
    if($ext eq "none"){
        $ext="";
    }
    $page->{_pageext}=$ext;
}

sub import_config {
    my ($file) = @_;
    open In, $file or return;
    ;
    while(<In>){
        if(/^(\w+):\s*(.*\S)/){
            $var->{$1}=$2;
        }
    }
    close In;
    if($var->{output_path} and !$var->{output_dir}){
        $var->{output_dir}=$var->{output_path};
    }
}

sub bases {
    my ($n, @bases) = @_;
    my @t;
    foreach my $b (@bases){
        push @t, $n % $b;
        $n = int($n/$b);
        if($n<=0){
            last;
        }
    }
    if($n>0){
        push @t, $n;
    }
    return @t;
}

sub get_time {
    my $t = time()-$time_start;
    my @t;
    push @t, $t % 60;
    $t = int($t/60);
    push @t, $t % 60;
    $t = int($t/60);
    push @t, $t % 60;
    $t = int($t/60);
    if($t>0){
        push @t, $t % 24;
        $t = int($t/24);
        return sprintf("%d day %02d:%02d:%02d", $t[3], $t[2], $t[1], $t[0]);
    }
    else{
        return sprintf("%02d:%02d:%02d", $t[2], $t[1], $t[0]);
    }
}

import_config("config");
MyDef::parseutil::add_path($var->{include_path});
MyDef::parseutil::add_path($ENV{MYDEFLIB});
1;
