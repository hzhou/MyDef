#!/usr/bin/perl
use MyDef;
my $def_file=$ARGV[0];
if(!-f $def_file){
    die "Please supply data definition file.";
}
my $module_type;
my %config;
foreach my $a (@ARGV){
    if($a =~ /-m(\w+)/){
        $config{module} = $1;
    }
    elsif($a =~/-o(\S+)/){
        $config{output_dir} = $1;
    }
}
MyDef::init(%config);
MyDef::import_data($ARGV[0]);
$pages=$MyDef::def->{pages};
while(my ($t, $p)=each (%$pages)){
    if(!$p->{subpage}){
        MyDef::createpage($t);
    }
}
