use strict;
use MyDef::output_c;

package MyDef::output_java;
our %common_classes;
our $out;
our @import_list;
our %import_hash;
our @extends;
our @implements;
our $public_hash;
our $public_list;
our $private_hash;
our $private_list;
our $debug;
our $print_type=1;

sub add_import {
    my ($l) = @_;
    if(!$import_hash{$l}){
        $import_hash{$l}=1;
        push @import_list, $l;
    }
}

sub parse_print {
    my ($param) = @_;
    if(!$param){
        push @$out, "System.out.println();";
    }
    else{
        $param=~s/^\s+//;
        if($param=~/^usesub:\s*(\w+)/){
            $print_type=$1;
        }
        else{
            my ($n, $fmt)=MyDef::output_c::fmt_string($param, 1);
            if($print_type==1){
                my $print_to = MyDef::compileutil::get_macro_word("print_to", 1);
                if($print_to){
                    if($print_to =~/s_/){
                        push @$out, "$print_to = String.format($fmt);";
                    }
                    else{
                        push @$out, "$print_to.printf($fmt);";
                    }
                }
                else{
                    if($n==0 and $fmt=~/^"(.*)\\n"/){
                        push @$out, "System.out.println(\"$1\");";
                    }
                    elsif($fmt=~/^"%[sdf]\\n", (.*)/){
                        push @$out, "System.out.println($1);";
                    }
                    else{
                        push @$out, "System.out.printf($fmt);";
                    }
                }
            }
            elsif($print_type){
                MyDef::compileutil::call_sub("$print_type, $fmt");
            }
        }
        return;
    }
}

%common_classes=(
    Random => "java.util.Random",
    "ArrayList<>" => "java.util.*",
);
$MyDef::output_c::var_fmts{String} = '%s';
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
    $page->{autolist}="page";
    if(!$page->{type}){
        $page->{type}="java";
    }
    MyDef::output_c::init_page(@_);
    @import_list=();
    %import_hash=();
    @extends=();
    @implements=();
    $public_hash={};
    $public_list=[];
    $private_hash={};
    $private_list=[];
    push @MyDef::output_c::scope_stack, {var_hash=>$public_hash, var_list=>$public_list};
    push @MyDef::output_c::scope_stack, {var_hash=>$private_hash, var_list=>$private_list};
    %MyDef::output_c::type_name=(
        c=>"byte",
        d=>"double",
        f=>"float",
        i=>"int",
        j=>"int",
        k=>"int",
        l=>"long",
        m=>"int",
        n=>"int",
        s=>"String",
        buf=>"StringBuffer",
        buffer=>"StringBuffer",
        count=>"int",
        size=>"int",
    );
    %MyDef::output_c::type_prefix=(
        i=>"int",
        n=>"int",
        n1=>"byte",
        n2=>"short",
        n4=>"int",
        n8=>"long",
        c=>"byte",
        b=>"boolean",
        s=>"String",
        f=>"double",
        z=>"double complex",
        "char"=>"char",
        "has"=>"boolean",
        "is"=>"boolean",
        "do"=>"boolean",
    );
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
    if($l=~/^\$import\s*(.*)/){
        foreach my $p (split /,\s*/, $1){
            add_import($p);
        }
        return;
    }
    elsif($l=~/^\$print\s*(.*)/){
        parse_print($1);
        return;
    }
    elsif($l=~/^\$foreach\s*(.+) in (.+)/){
        return MyDef::output_c::single_block("for($1 : $2){", "}");
    }
    elsif($l=~/^\$extends\s*(.+)/){
        push @extends, $1;
        return;
    }
    elsif($l=~/^\$implements\s*(.+)/){
        push @implements, $1;
        return;
    }
    elsif($l=~/^\$\b(global|public|private)\s*(.*)/){
        my $param=$2;
        my ($h, $l);
        if($1 eq "public"){
            ($h, $l)=($public_hash, $public_list);
        }
        elsif($1 eq "private"){
            ($h, $l)=($private_hash, $private_list);
        }
        else{
            my $curfile=MyDef::compileutil::curfile_curline();
            print "[$curfile]\x1b[33m \$$1 not supported in java, use \$public or \$private\n\x1b[0m";
            return;
        }
        my @plist = MyDef::utils::proper_split($param);
        foreach my $p (@plist){
            my ($val, $type);
            if($p=~/(.*?)\s*=\s*(.*)/){
                $p=$1;
                $val = $2;
                if($val=~/^\s*new\s+(\w+)(.*)/){
                    my ($cls, $p)=($1, $2);
                    if($p=~/^<(.*?)>(.*)/){
                        $type = "$cls<$1>";
                    }
                    elsif($p=~/\[(.*?)\](.*)/){
                        $type = "$cls"."[]";
                    }
                    else{
                        $type = $cls;
                    }
                    if($common_classes{$cls}){
                        add_import($common_classes{$cls});
                    }
                }
            }
            my $name=MyDef::output_c::f_add_var($h, $l, $p, $type);
            if($val){
                push @$out, "$p = $val;";
            }
        }
        return;
    }
    elsif($l=~/^(\w+)\s*=\s*(new\s+.*)/){
        my ($name, $val) = ($1, $2);
        my $type;
        if($val=~/^\s*new\s+(\w+)(.*)/){
            my ($cls, $p)=($1, $2);
            if($p=~/^<(.*?)>(.*)/){
                $type = "$cls<$1>";
            }
            elsif($p=~/\[(.*?)\](.*)/){
                $type = "$cls"."[]";
            }
            else{
                $type = $cls;
            }
            if($common_classes{$cls}){
                add_import($common_classes{$cls});
            }
        }
        MyDef::output_c::auto_add_var($name, $type);
        if($val=~/{\s*$/){
            push @$out, "$name = $val";
        }
        else{
            push @$out, "$name = $val;";
        }
        return;
    }
    return MyDef::output_c::parsecode($l);
}
sub dumpout {
    my ($f, $out)=@_;
    my $page=$MyDef::output_c::page;
    if($page->{package}){
        push @$f, "package $page->{package};\n";
    }
    if(@import_list){
        push @$f, "\n";
        foreach my $imp (@import_list){
            push @$f, "import $imp;\n";
        }
        push @$f, "\n";
    }
    my $t = "public class $page->{_pagename}";
    if(@extends){
        $t .= " extends ".join(", ", @extends);
    }
    if(@implements){
        $t .= " implements ".join(", ", @implements);
    }
    push @$f, "$t {\n";
    unshift @$out, "INDENT";
    push @$out, "DEDENT", "}\n";
    if(@$public_list){
        foreach my $name (@$public_list){
            my $v = $public_hash->{$name};
            my $type = $v->{type};
            $type=~s/\*/[]/g;
            my $decl="$type $v->{name}";
            push @$f, "    public $decl;\n";
        }
        push @$f, "\n";
    }
    if(@$private_list){
        foreach my $name (@$private_list){
            my $v = $private_hash->{$name};
            my $type = $v->{type};
            $type=~s/\*/[]/g;
            my $decl="$type $v->{name}";
            push @$f, "    private $decl;\n";
        }
        push @$f, "\n";
    }
    foreach my $name (@MyDef::output_c::struct_list){
        my $st = $MyDef::output_c::structs{$name};
        my $h  = $st->{hash};
        push @$out, "\n";
        push @$out, "class $name {\n";
        my $sp = '    ';
        foreach my $p (@{$st->{list}}){
            my $type = $h->{$p}->{type};
            push @$out, "    public $type $p;\n";
        }
        push @$out, "};\n";
    }
    my $funclist=\@MyDef::output_c::function_list;
    foreach my $func (@$funclist){
        my $name=$func->{name};
        if($name eq "main"){
            $func->{skip_makefile}=1;
            $func->{ret_type}="public static void";
            $func->{param_list}=["String[] args"];
        }
        elsif($name =~/^_(\w*)_init$/){
            $func->{ret_type}="public";
            $func->{name}=$page->{_pagename};
        }
        else{
            if($func->{ret_type} and $func->{ret_type}=~/^(public|private)/){
            }
            else{
                if(!$func->{ret_type}){
                    $func->{ret_type}="void";
                }
                if($MyDef::output_c::function_autolist{$name} eq "global"){
                    $func->{ret_type}="public static $func->{ret_type}";
                }
                else{
                    $func->{ret_type}="public $func->{ret_type}";
                }
            }
        }
        MyDef::output_c::process_function_std($func);
        $func->{skip_declare}=1;
        $func->{processed}=1;
    }
    MyDef::dumpout::dumpout({out=>$out,f=>$f});
    return;
    MyDef::output_c::dumpout($f, $out);
}
1;
