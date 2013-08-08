#!/usr/bin/perl
use MyDef;
my $def_file;
my $module;
my %config;
my $default_module=$MyDef::var->{module};
foreach my $a (@ARGV){
    if($a =~ /^-m(\w+)/){
        $config{module} = $1;
    }
    elsif($a =~/-o(\S+)/){
        $config{output_dir} = $1;
    }
    elsif($a=~/\.def$/){
        if($def_file){
            die "Multiple def source files not supported\n";
        }
        if(-f $a){
            $def_file=$a;
        }
        else{
            die "$a is not a regular file\n";
        }
    }
}
if(!$def_file){
    die "Please supply data definition file.";
}
MyDef::init(%config);
my $module=$MyDef::var->{module};
MyDef::import_data($def_file);
my $pages=$MyDef::def->{pages};
my $pagelist=$MyDef::def->{pagelist};
foreach my $t (@$pagelist){
    my $p=$pages->{$t};
    if($p->{subpage}){
        next;
    }
    my $t_module=$default_module;
    if($p->{module}){
        $t_module=$p->{module};
    }
    if($t_module and ($t_module ne $module)){
        next;
    }
    MyDef::createpage($t);
}
