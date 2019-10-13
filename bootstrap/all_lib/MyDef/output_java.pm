use strict;
use MyDef::output_c;
package MyDef::output_java;

our %common_classes;
our $out;
our @import_list;
our %import_hash;
our @const_list;
our %const_hash;
our @extends;
our @implements;
our $public_hash;
our $public_list;
our $private_hash;
our $private_list;
our $debug;
our $print_type=1;
%common_classes=(
    Random => "java.util.Random",
    "ArrayList<>" => "java.util.*",
);
$MyDef::output_c::var_fmts{String} = '%s';
$MyDef::output_c::var_fmts{default} = '%s';


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
    my ($t_page)=@_;
    my $page=$t_page;
    MyDef::set_page_extension("java");

    $page->{autolist}="page";

    my $init_mode = MyDef::output_c::init_page(@_);
    $MyDef::output_c::page->{has_bool}="boolean";
    $MyDef::output_c::type_prefix{b} = "boolean";
    $MyDef::output_c::type_prefix{is} = "boolean";
    $MyDef::output_c::type_prefix{has} = "boolean";
    $MyDef::output_c::type_prefix{do} = "boolean";
    @import_list=();
    %import_hash=();
    @const_list=();
    %const_hash=();
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
    return $init_mode;
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
    elsif($l=~/^\$throws\s*(.+)/){
        $MyDef::output_c::cur_function->{throws}=$1;
        return;
    }
    elsif($l=~/^\$const\s+(.+?)\s*=\s*(.*)/){
        my ($v, $value) = ($1, $2);
        if($v=~/^\w+$/){
            my $type = MyDef::output_c::get_type_name($v);
            if($type){
                $v="$type $v";
            }
        }
        add_const($v,$value);
        return;
    }
    elsif($l=~/^\$foreach\s*(.+) in (.+)/){
        my ($v, $L) = ($1, $2);
        if($v=~/^(\w+),\s*(\w+)/){
            my ($v1, $v2) = ($1, $2);
            my $L_type = MyDef::output_c::get_var_type($L);
            if($L_type=~/<(.+),\s*(.+)>/){
                my ($t1, $t2) = ($1, $2);
                my @src;
                push @src, "for (Map.Entry<$t1, $t2> entry : $L.entrySet()){";
                push @src, "INDENT";
                $t1=~s/Integer/int/;
                $t2=~s/Integer/int/;
                push @src, "PARSE: \$my $t1 $v1 = entry.getKey();";
                push @src, "PARSE: \$my $t2 $v2 = entry.getValue();";
                push @src, "BLOCK";
                push @src, "DEDENT";
                push @src, "}";
                MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                return "NEWBLOCK-foreach";
            }
        }
        if($v=~/^\w+$/){
            if($L=~/(.+)\.(keys|keySet|values)/){
                my ($t1, $t2) = ($1, $2);
                my $L_type = MyDef::output_c::get_var_type($t1);
                if($L_type=~/<(.+),\s*(.+)>/){
                    if($t2 eq "values"){
                        $v = "$2 $v";
                    }
                    else{
                        $v = "$1 $v";
                    }
                }
            }
            else{
                my $L_type = MyDef::output_c::get_var_type($L);
                if($L_type=~/(.*)\[\]/){
                    $v = "$1 $v";
                }
                elsif($L_type=~/<(.*)>/){
                    $v = "$1 $v";
                }
                else{
                    if($v=~/^\w+$/){
                        my $type = MyDef::output_c::get_type_name($v);
                        if($type){
                            $v="$type $v";
                        }
                    }
                }
            }
        }
        return MyDef::output_c::single_block("for($v : $L){", "}");
    }
    elsif($l=~/^\$extends\s*(.+)/){
        push @extends, $1;
        return;
    }
    elsif($l=~/^\$implements\s*(.+)/){
        push @implements, $1;
        return;
    }
    elsif($l=~/^\$my\s.*=\s*(\w+)\(/){
        if($MyDef::output_c::function_autolist{$1}){
            if(!$MyDef::output_c::list_function_hash{$1}){
                $MyDef::output_c::list_function_hash{$1}=1;
                push @MyDef::output_c::list_function_list, $1;
            }
        }
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
            if($p=~/(\w.*)\s+(\w+)$/){
                $type = $1;
                $p = $2;
            }
            my $name=MyDef::output_c::f_add_var($h, $l, $p, $type);
            if($val or $val eq "0"){
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
    elsif($l=~/^\$print\s*(.*)/){
        parse_print($1);
        return;
    }
    elsif($l=~/^\$dump\s*(.*)/){
        my @tlist = split /,\s*/, $1;
        my @fmt;
        foreach my $t (@tlist){
            push @fmt, "$t=%s";
        }
        my $fmt = "\"  :| ".join(', ', @fmt)."\", ".join(', ', @tlist);
        parse_print($fmt);
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
    foreach my $type (keys %MyDef::output_c::all_types){
        if($type=~/(Collection|Iterator|List|HashMap|HashSet|Enumeration)/){
            add_import("java.util.*");
        }
    }
    if(@import_list){
        push @$f, "\n";
        foreach my $imp (@import_list){
            push @$f, "import $imp;\n";
        }
        push @$f, "\n";
    }
    my $blk = MyDef::compileutil::get_named_block("meta_init");
    if(@$blk){
        foreach my $l (@$blk){
            push @$f, "$l\n";
        }
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
    foreach my $t (@const_list){
        push @$f, "    static final $t;\n";
    }
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

    my %classes;
    foreach my $name (@MyDef::output_c::struct_list){
        my $st = $MyDef::output_c::structs{$name};
        my $h  = $st->{hash};
        push @$out, "\n";
        push @$out, "class $name {\n";
        push @$out, "INDENT";
        foreach my $p (@{$st->{list}}){
            my $type = $h->{$p};
            if($type=~/^const\s+(.*)/){
                $type= "static final $1";
            }
            elsif($type!~/^(public|private)/){
                $type = "public $type";
            }
            push @$out, "$type $p;\n";
        }

        my $s_stub = "_$name\_methods";
        push @$out, "NEWLINE";
        push @$out, "DUMP_STUB $s_stub";
        $classes{$name} = MyDef::compileutil::get_named_block($s_stub);

        push @$out, "DEDENT";
        push @$out, "};\n";
    }
    my $alt_out;
    foreach my $l (@$out){
        if(!$alt_out and $l=~/DUMP_STUB fn(\d+)_open/){
            my $func = $MyDef::output_c::function_list[$1];
            if($func->{name}=~/^(\w+)\.(\w+)/){
                if($classes{$1}){
                    $alt_out = $classes{$1};
                }
            }
        }

        if($alt_out){
            push @$alt_out, $l;

            if($l=~/DUMP_STUB fn(\d+)_close/){
                undef $alt_out;
            }

            $l = "NOOP";
        }
    }

    foreach my $func (@MyDef::output_c::function_list){
        my $name=$func->{name};
        if($name=~/(\w+)\.(\w+)/){
            $func->{name}=$2;
            $func->{class}=$1;
            $name=$2;
        }
        else{
            $func->{class}=$page->{_pagename};
        }
        if($name eq "main"){
            $func->{skip_makefile}=1;
            $func->{return_type}="public static void";
            $func->{param_list}=["String[] args"];
        }
        elsif($name =~/^_(\w*)_init$/){
            $func->{return_type}="public";
            $func->{name}=$func->{class};
        }
        else{
            if($func->{return_type} and $func->{return_type}=~/^(public|private)/){
            }
            else{
                if(!$func->{return_type}){
                    $func->{return_type}="void";
                }

                if($MyDef::output_c::function_autolist{$name} =~/^(public|private)/){
                    $func->{return_type}="$MyDef::output_c::function_autolist{$name} $func->{return_type}";
                }
                else{
                    $func->{return_type}="public static $func->{return_type}";
                }
            }
        }

        MyDef::output_c::process_function_std($func);
        if($func->{throws}){
            my $open = $func->{openblock};
            if($open->[-1] =~/^{/){
                $open->[-2] .= " throws $func->{throws}";
            }
            else{
                $open->[-1]=~s/\{$/ throws $func->{throws} {/;
            }
        }
        $func->{skip_declare}=1;
        $func->{processed}=1;
    }

    MyDef::dumpout::dumpout({out=>$out,f=>$f});
    return;
    MyDef::output_c::dumpout($f, $out);
}


1;

# ---- subroutines --------------------------------------------
sub add_import {
    my ($l) = @_;
    if(!$import_hash{$l}){
        $import_hash{$l}=1;
        push @import_list, $l;
    }
}

sub add_const {
    my ($v, $init) = @_;
    if(!$const_hash{$v}){
        $const_hash{$v}=1;
        push @const_list, "$v = $init";
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

1;
