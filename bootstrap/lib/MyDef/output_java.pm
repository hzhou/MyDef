use strict;
use MyDef::output_c;

package MyDef::output_java;
our %common_classes;
our $out;
our @import_list;
our %import_hash;
our $debug;
our $time_start = time();

sub add_import {
    my ($l) = @_;
    if(!$import_hash{$l}){
        $import_hash{$l}=1;
        push @import_list, $l;
    }
}

sub parse_print {
    my ($t) = @_;
    my $P = "System.out.println";
    if($t=~/^(["\s]+)(-?)$/){
        if($2){
            $t = $1;
        }
        $P = "System.out.print";
    }
    else{
        if($t!~/^"|"$/){
            $t="\"$t\"";
        }
        if($t=~/(.*)-"$/){
            $t = "$1\"";
            $P = "System.out.print";
        }
    }
    push @$out, "$P($t);";
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

%common_classes=(
    Random => "java.util.Random",
);
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
        $page->{type}="java";
    }
    MyDef::output_c::init_page(@_);
    @import_list=();
    %import_hash=();
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
    if($l=~/^\$print\s*(.*)/){
        parse_print($1);
        return;
    }
    elsif($l=~/^(\w+)\s*=\s*new\s*(\w+)\s*(.*)\s*;?/){
        my ($v, $cls, $p)=($1, $2, $3);
        if(!$p){
            push @$out, "$cls $v = new $cls();";
        }
        elsif($p=~/^\((.*)\)/){
            push @$out, "$cls $v = new $cls($1);";
        }
        else{
            push @$out, "$cls $v = new $cls($p);";
        }
        if($common_classes{$cls}){
            add_import($common_classes{$cls});
        }
        return;
    }
    return MyDef::output_c::parsecode($l);
}
sub dumpout {
    my ($f, $out, $pagetype)=@_;
    my $page=$MyDef::output_c::page;
    if($page->{package}){
        push @$f, "package $page->{package};\n";
    }
    if(@import_list){
        push @$f, "\n";
        foreach my $imp (@import_list){
            push @$f, "import $imp;\n";
        }
    }
    unshift @$out, "public class $page->{_pagename} {\n", "INDENT";
    push @$out, "DEDENT", "}\n";
    my $funclist=\@MyDef::output_c::function_list;
    foreach my $func (@$funclist){
        my $name=$func->{name};
        if($name eq "main"){
            $func->{skip_makefile}=1;
            $func->{ret_type}="public static void";
            $func->{param_list}=["String[] args"];
        }
        else{
            if(!$func->{ret_type}){
                $func->{ret_type}="void";
            }
            $func->{ret_type}="public static $func->{ret_type}";
        }
        MyDef::output_c::process_function_std($func);
        $func->{skip_declare}=1;
        $func->{processed}=1;
    }
    MyDef::output_c::dumpout($f, $out, $pagetype);
}
1;
