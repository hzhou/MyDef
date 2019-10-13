use strict;
package MyDef::output_c;

our @scope_stack;
our $cur_scope;
our @function_stack;
our %list_function_hash;
our @list_function_list;
our %basic_types;
our %type_name;
our %type_prefix;
our %fntype;
our %stock_functions;
our %lib_include;
our %type_include;
our %text_include;
our %var_fmts;
our $debug=0;
our $out;
our $mode;
our $page;
our %misc_vars;
our $global_hash;
our $global_list;
our $main_func;
our %functions;
our $cur_function;
our @function_list;
our @extern_binary;
our @include_list;
our %includes;
our %objects;
our @object_list;
our $define_id_base;
our @define_list;
our %defines;
our @typedef_list;
our %typedef_hash;
our %enums;
our @enum_list;
our @function_declare_list;
our %declare_hash;
our @declare_list;
our %structs;
our @struct_list;
our @initcodes;
our %structure_autolist;
our %function_autolist;
our $case_if="if";
our $case_elif="else if";
our @case_stack;
our $case_state;
our %plugin_statement;
our %plugin_condition;
our $anonymous_count=0;
our %class_names;
our %type_class;
our $yield;
our $print_type=1;
our $has_main;
our $dump_classes;
our $custom_split_var_line;
our %protected_var;
our %tuple_hash;
our %all_types;
our %re_hash;
our $re_index=0;
$cur_scope={var_list=>[], var_hash=>{}, name=>"default"};
%basic_types=(
    "int"=>1,
    "char"=>1,
    "unsigned"=>1,
    "unsigned char"=>1,
    "long"=>1,
    "float"=>1,
    "double"=>1,
);
%type_name=(
    c=>"unsigned char",
    d=>"double",
    f=>"float",
    i=>"int",
    j=>"int",
    k=>"int",
    l=>"long",
    m=>"int",
    n=>"int",
    s=>"char*",
    buf=>"unsigned char*",
    buffer=>"unsigned char*",
    count=>"int",
    size=>"int",
);
%type_prefix=(
    i=>"int",
    n=>"int",
    n1=>"int8_t",
    n2=>"int16_t",
    n4=>"int32_t",
    n8=>"int64_t",
    ui=>"unsigned int",
    u=>"unsigned int",
    u1=>"uint8_t",
    u2=>"uint16_t",
    u4=>"uint32_t",
    u8=>"uint64_t",
    i16=>"int16_t",
    u16=>"uint16_t",
    i32=>"int32_t",
    u32=>"uint32_t",
    i64=>"int64_t",
    u64=>"uint64_t",
    c=>"unsigned char",
    uc=>"unsigned char",
    b=>"bool",
    s=>"char*",
    f=>"float",
    d=>"double",
    z=>"double complex",
    "char"=>"char",
    "size"=>"size_t",
    "time"=>"time_t",
    "file"=>"FILE *",
    "has"=>"bool",
    "is"=>"bool",
    "do"=>"bool",
);

%stock_functions=(
    "printf"=>1,
);

%lib_include=(
    glib=>"glib",
);

%type_include=(
    time_t=>"time",
    int8_t=>"stdint",
    int16_t=>"stdint",
    int32_t=>"stdint",
    int64_t=>"stdint",
    uint8_t=>"stdint",
    uint16_t=>"stdint",
    uint32_t=>"stdint",
    uint64_t=>"stdint",
    "double complex"=>"complex",
);

%text_include=(
    "printf|perror"=>"stdio",
    "malloc"=>"stdlib",
    "str(len|dup|cpy)|memcpy"=>"string",
    "\\bopen\\("=>"fcntl",
    "sin|cos|sqrt|pow"=>"math",
    "fstat"=>"sys/stat",
    "assert"=>"assert",
);
%var_fmts = (
    float=>'%g',
    double=>'%g',
    "unsigned"=>'%d',
    "unsigned char"=>'%d',
    char=>'%c',
    bool=>'%d',
);
our $except;

sub get_interface {
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout);
}

sub init_page {
    my ($t_page)=@_;
    $page=$t_page;
    MyDef::set_page_extension("c");
    my $init_mode="sub";
    @function_stack=();
    %list_function_hash=();
    @list_function_list=();
    @scope_stack=();

    $global_hash={};
    $global_list=[];
    $cur_scope={var_list=>$global_list, var_hash=>$global_hash, name=>"global"};

    $main_func={param_list=>[], var_list=>[], var_hash=>{}};

    %functions=();
    $cur_function = $main_func;

    @function_list = ();
    @extern_binary=();
    @include_list=();
    %includes=();
    %objects=();
    $define_id_base=1000;
    @define_list=();
    %defines=();
    @typedef_list=();
    %typedef_hash=();
    %enums=();
    @enum_list=();
    @function_declare_list=();
    %declare_hash=();
    @declare_list=();
    %structs=();
    @struct_list=();
    @initcodes=();
    my $macros=$MyDef::def->{macros};
    if($macros->{use_double} and !defined $page->{use_double}){
        $page->{use_double}=$macros->{use_double};
    }
    if($macros->{has_bool} and !defined $page->{has_bool}){
        $page->{has_bool}=$macros->{has_bool};
    }
    if($macros->{use_int64} and !defined $page->{use_int64}){
        $page->{use_int64}=$macros->{use_int64};
    }
    if($macros->{use_prefix} and !defined $page->{use_prefix}){
        $page->{use_prefix}=$macros->{use_prefix};
    }

    if($page->{"use_double"}){
        $type_name{f}="double";
        $type_prefix{f}="double";
    }
    else{
        $type_name{f}="float";
        $type_prefix{f}="float";
    }

    if($page->{"use_int64"}){
        $type_name{i}="int64_t";
        $type_name{j}="int64_t";
        $type_name{k}="int64_t";
        $type_name{l}="int64_t";
        $type_prefix{i}="int64_t";
        $type_prefix{n}="int64_t";
        $type_prefix{u}="uint64_t";
    }
    else{
        $type_name{i}="int";
        $type_name{j}="int";
        $type_name{k}="int";
        $type_name{l}="int";
        $type_prefix{i}="int";
        $type_prefix{n}="int";
        $type_prefix{u}="unsigned int";
    }
    if($page->{"use_libmydef"}){
        my $lines=MyDef::parseutil::get_lines("c/libmydef.inc");
        my $struct_lines;
        foreach my $l (@$lines){
            if($l=~/^F\s+(\S.+)\s+(\w+)\((.*)\)/){
                my ($name, $type, $param)=($2, $1, $3);
                $functions{$name}={declare=>"$type $name($param)", return_type=>$type};
                $function_autolist{$name}="declare";
            }
            elsif($l=~/^S\s+(.*)/){
                my @tlist=split /,\s*/, $1;
                foreach my $t (@tlist){
                    $structure_autolist{$t}=1;
                }
            }
            elsif($l=~/^struct (\w+)\{/){
                $struct_lines=[];
                $structure_autolist{$1}=$struct_lines;
            }
            elsif($l=~/^}/){
                undef $struct_lines;
            }
            elsif($struct_lines){
                push @$struct_lines, $l;
            }
        }
    }
    if($page->{autodecl}){
        my @tlist=split /,\s*/, $page->{autodecl};
        foreach my $f (@tlist){
            my $lines=MyDef::parseutil::get_lines("$f");
            my $struct_lines;
            foreach my $l (@$lines){
                if($l=~/^F\s+(\S.+)\s+(\w+)\((.*)\)/){
                    my ($name, $type, $param)=($2, $1, $3);
                    $functions{$name}={declare=>"$type $name($param)", return_type=>$type};
                    $function_autolist{$name}="declare";
                }
                elsif($l=~/^S\s+(.*)/){
                    my @tlist=split /,\s*/, $1;
                    foreach my $t (@tlist){
                        $structure_autolist{$t}=1;
                    }
                }
                elsif($l=~/^struct (\w+)\{/){
                    $struct_lines=[];
                    $structure_autolist{$1}=$struct_lines;
                }
                elsif($l=~/^}/){
                    undef $struct_lines;
                }
                elsif($struct_lines){
                    push @$struct_lines, $l;
                }
            }
        }
    }
    my $subcode=$MyDef::def->{codes}->{_autoload};
    my $source=$subcode->{source};
    my @t;
    foreach my $l (@$source){
        if($l=~/\$class\s+(.*)/){
            push @t, $l;
            $l="NOOP";
        }
    }

    if(@t){
        unshift @$source, @t;

    }

    my $codes=$MyDef::def->{codes};
    my @tlist;
    while(my ($k, $v)= each %$codes){
        if($v->{type} eq "fn"){
            push @tlist, $k;
        }
    }
    if(@tlist){
        @tlist=sort { $codes->{$a}->{index} <=> $codes->{$b}->{index} } @tlist;
        foreach my $name (@tlist){
            my $code=$codes->{$name};
            my $source=$code->{source};
            my $func = {};
            $functions{$name}=$func;

            if($code->{tail}){
                $func->{return_type} = $code->{tail};
            }

            foreach my $l (@$source){
                if($l=~/^SOURCE/){
                }
                elsif($l=~/^lexical:\s*(.+?)\s*$/){
                    $func->{lexical} = $1;
                    $l="NOOP";
                }
                elsif($l=~/^(return):\s*(.+?)\s*$/){
                    $func->{return_type} = $2;
                    $l="NOOP";
                }
                elsif($l=~/^(parameter|return_type|frame|autolist):\s*(.+?)\s*$/){
                    $func->{$1} = $2;
                    $l="NOOP";
                }
                elsif($l=~/^\x24(parameter|return_type|frame|autolist)\s+(.*)/){
                    $func->{$1} = $2;
                    $l="NOOP";
                }
                else{
                    last;
                }
            }

            if($func->{lexical}){
                my @tlist=split /,\s*/, $func->{lexical};
                my @params;
                my @segs;
                foreach my $t (@tlist){
                    if($t=~/(.*)\((\w+)\)$/){
                        push @params, $1;
                        push @segs, $2;
                    }
                    else{
                        push @params, $t;
                        if($t=~/^(.+)\s+(\S+)$/){
                            push @segs, $2;
                        }
                        else{
                            push @segs, $t;
                        }
                    }
                }

                $func->{append} = join(', ', @segs);
                $func->{parameter} = join(", ", @params);
            }
            if($func->{return_type}){
                if($func->{return_type} eq "bool"){
                    $page->{use_bool}=1;
                }
            }

            if($name=~/^\w+::/){
                $func->{autolist} = "class_member";
            }
            if($func->{autolist} eq "skip"){
                $function_autolist{$name}="static";
            }
            elsif($func->{autolist} or $page->{autolist} eq "global"){
                $function_autolist{$name}=$func->{autolist};
                if(!$list_function_hash{$name}){
                    $list_function_hash{$name}=1;
                    push @list_function_list, $name;
                }
                else{
                    $list_function_hash{$name}++;
                }
            }
            else{
                $function_autolist{$name}="static";
            }
        }
    }

    if($page->{autolist} eq "page"){
        my $codes=$page->{codes};
        my @tlist;
        while(my ($k, $v)= each %$codes){
            if($v->{type} eq "fn"){
                push @tlist, $k;
            }
        }
        if(@tlist){
            @tlist=sort { $codes->{$a}->{index} <=> $codes->{$b}->{index} } @tlist;
            foreach my $name (@tlist){
                my $code=$codes->{$name};
                if(!$list_function_hash{$name}){
                    $list_function_hash{$name}=1;
                    push @list_function_list, $name;
                }
                else{
                    $list_function_hash{$name}++;
                }
            }
        }
    }

    return $init_mode;
}

sub set_output {
    my ($newout)=@_;
    $out = $newout;
}

sub modeswitch {
    my ($mode, $in)=@_;
}

sub parsecode {
    my ($l)=@_;
    if($debug eq "parse"){
        my $yellow="\033[33;1m";
        my $normal="\033[0m";
        print "$yellow parsecode: [$l]$normal\n";
    }

    if($l=~/^\$warn (.*)/){
        my $curfile=MyDef::compileutil::curfile_curline();
        print "[$curfile]\x1b[33m $1\n\x1b[0m";
        return;
    }
    elsif($l=~/^DEBUG (\w+)/){
        if($1 eq "OFF"){
            $debug=0;
        }
        else{
            $debug=$1;
        }
        return;
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

    if($debug eq "case"){
        my $level=@case_stack;
        print "        $level:[$case_state]$l\n";
    }

    if($l=~/^\x24(if|elif|elsif|elseif|case)\s+(.*)$/){
        my $cond=$2;
        my $case=$case_if;
        if($1 eq "if"){
        }
        elsif($1 eq "case"){
            if(!$case_state){
                $case=$case_if;
            }
            else{
                $case=$case_elif;
            }
        }
        else{
            $case=$case_elif;
        }
        $cond=parse_condition($cond);
        my @src;
        if($case eq $case_if){
            push @src, "if ($cond) {";
            push @src, "INDENT";
            push @src, "BLOCK";
            push @src, "DEDENT";
            push @src, "}";
        }
        else{
            if($out->[-1] ne "}"){
                my $curfile=MyDef::compileutil::curfile_curline();
                print "[$curfile]\x1b[33m case: else missing } - [$out->[-1]]\n\x1b[0m";
            }
            pop @$out;
            push @src, "} else if ($cond) {";
            push @src, "INDENT";
            push @src, "BLOCK";
            push @src, "DEDENT";
            push @src, "}";
        }
        push @src, "PARSE:CASEPOP";
        push @case_stack, {state=>"if"};

        undef $case_state;
        if($debug eq "case"){
            my $level=@case_stack;
            print "Entering case [$level]: $l\n";
        }
        MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
        return "NEWBLOCK-if";
    }
    elsif($l=~/^\$else/){
        if(!$case_state and $l!~/NoWarn/i){
            my $curfile=MyDef::compileutil::curfile_curline();
            print "[$curfile]\x1b[33m Dangling \$else\n\x1b[0m";
        }
        my @src;
        if($out->[-1] ne "}"){
            my $curfile=MyDef::compileutil::curfile_curline();
            print "[$curfile]\x1b[33m case: else missing } - [$out->[-1]]\n\x1b[0m";
        }
        pop @$out;
        push @src, "} else {";
        push @src, "INDENT";
        push @src, "BLOCK";
        push @src, "DEDENT";
        push @src, "}";
        push @src, "PARSE:CASEPOP";
        push @case_stack, {state=>undef};

        undef $case_state;
        if($debug eq "case"){
            my $level=@case_stack;
            print "Entering case [$level]: $l\n";
        }
        MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
        return "NEWBLOCK-else";
    }
    elsif($l!~/^SUBBLOCK/){
        undef $case_state;
        if($l eq "CASEPOP"){
            if($debug eq "case"){
                my $level=@case_stack;
                print "    Exit case [$level]\n";
            }
            my $t_case=pop @case_stack;
            if($t_case){
                $case_state=$t_case->{state};
            }
            return 0;
        }
    }


    if($l=~/^DUMP_STUB\s/){
        push @$out, $l;
    }
    elsif($l=~/^SUBBLOCK BEGIN (\d+) (.*)/){
        open_scope($1, $2);
        return;
    }
    elsif($l=~/^SUBBLOCK END (\d+) (.*)/){
        close_scope();
        return;
    }
    elsif($l=~/^NOOP POST_MAIN/){


        while(my $f=shift @list_function_list){
            if($MyDef::compileutil::named_blocks{"lambda-$f"}){
                push @$out, "NEWLINE?";
                push @$out, "DUMP_STUB lambda-$f";
                $function_autolist{$f}="static";
            }
            elsif($functions{$f} && $functions{$f}->{autodecl}){
            }
            elsif($function_autolist{$f} eq "declare"){
                push @function_declare_list, $f;
            }
            else{
                push @$out, "NEWLINE?";
                my $codename=$f;
                my $funcname=$f;
                if($codename=~/(\w+)\((\w+)\)/){
                    $codename=$1;
                    $funcname=$2;
                }
                $funcname=~s/^@//;
                my $codelib=MyDef::compileutil::get_def_attr("codes", $codename);
                if(!$codelib){
                    print "function $codename not found!\n";
                }
                else{
                    my $params=$codelib->{params};
                    my $paramline;
                    if(defined $params){
                        $paramline=join(",", @$params);
                        if($paramline eq "main"){
                            $funcname="main";
                            $paramline="";
                        }
                    }
                    else{
                        $paramline="";
                    }

                    my $return_type = $codelib->{tail};

                    my ($func, $block)=function_block($funcname, $paramline, $return_type);
                    foreach my $l (@$block){
                        if($l eq "BLOCK"){
                            func_push($func);
                            if($func->{frame}){
                                my $t = '@'.$func->{frame}."_pre";
                                MyDef::compileutil::call_sub($t);
                            }
                            MyDef::compileutil::list_sub($codelib);
                            if($func->{frame}){
                                my $t = '@'.$func->{frame}."_post";
                                MyDef::compileutil::call_sub($t);
                            }
                            if($out->[-1]=~/^return/){
                                $func->{return}=pop @$out;
                            }
                            func_pop();
                        }
                        else{
                            push @$out, $l;
                        }
                    }
                }

            }
        }
        return;
    }
    elsif($l=~/^\s*\$(\w+)\((.*?)\)\s+(.*?)\s*$/){
        my ($func, $param1, $param2)=($1, $2, $3);
        if($func eq "plugin"){
            if($param2=~/_condition$/){
                $plugin_condition{$param1}=$param2;
            }
            else{
                $plugin_statement{$param1}=$param2;
            }
            return;
        }
        elsif($func eq "define"){
            add_define($param1, $param2);
            return;
        }
        elsif($func eq "enum"){
            if(!$enums{$param1}){
                push @enum_list, $param1;
                $enums{$param1}=$param2;
            }
            else{
                $enums{$param1}.=", $param2";
            }
            return;
        }
        elsif($func eq "list"){
            my @tlist=split /,\s*/, $param2;
            foreach my $f (@tlist){
                if(!$list_function_hash{$f}){
                    $list_function_hash{$f}=1;
                    push @list_function_list, $f;
                }
                else{
                    $list_function_hash{$f}++;
                }
                $function_autolist{$f}=$param1;
            }
            return;
        }
        elsif($func eq "set_fn_attr"){
            $cur_function->{$param1} = $param2;
            return;
        }
        elsif($func eq "get_fn_type"){
            my $type = "void";
            if($functions{$param2} and $functions{$param2}->{return_type}){
                $type=$functions{$param2}->{return_type};
            }
            MyDef::compileutil::set_current_macro($param1, $type);
            return;
        }
        elsif($func eq "get_type"){
            my $type=get_var_type($param2);
            MyDef::compileutil::set_current_macro($param1, $type);
            return;
        }
        elsif($func=~/^(global|symbol|local|my|temp|static|extern)$/){
            my ($type,$param)=($param1,$param2);
            my @vlist;
            if($param=~/[({<][^)}>]*,/){
                @vlist = ($param);
            }
            elsif($param=~/=\s*['"][^'"]*,/){
                @vlist = ($param);
            }
            else{
                @vlist = split_var_line($param);
            }
            foreach my $v (@vlist){
                if($func eq "global"){
                    global_add_var($v,$type);
                }
                elsif($func eq "local"){
                    func_add_var($v,$type);
                }
                elsif($func eq "symbol"){
                    global_add_symbol($v,$type);
                }
                elsif($func eq "my"){
                    my_add_var($v,$type);
                }
                elsif($func eq "temp"){
                    temp_add_var($v,$type);
                }
                elsif($func eq "static"){
                    my $var=global_add_var($v,$type);
                    $var->{attr}="static";
                }
                elsif($func eq "extern"){
                    my $name=global_add_symbol($v,$type);
                    my $decl=var_declare($global_hash->{$name}, 1);
                    if(!$declare_hash{"extern $decl"}){
                        push @declare_list, "extern $decl";
                        $declare_hash{"extern $decl"} = 1;
                    }
                }
                else{
                    my $curfile=MyDef::compileutil::curfile_curline();
                    print "[$curfile]\x1b[33m add_vars: \$$func not implemented.\n\x1b[0m";
                }
            }
            return;
        }
        elsif($func eq "register_prefix"){
            my @tlist=split /,\s*/, $param1;
            foreach my $t (@tlist){
                $type_prefix{$t}=$param2;
            }
            return;
        }
        elsif($func eq "register_name"){
            my @tlist=split /,\s*/, $param1;
            foreach my $t (@tlist){
                $type_name{$t}=$param2;
            }
            return;
        }
        elsif($func eq "typedef"){
            foreach my $t (split /,\s*/, $param1){
                add_typedef("$param2 $t");
            }
            return;
        }
        elsif($func eq "sumcode" or $func eq "loop" or $func eq "sum" or $func eq "for"){
            my $dimstr=$param1;
            my $param=$param2;
            if($debug){
                print "parsecode_sum: [$param]\n";
            }
            my $h={};
            my (%k_hash, @k_list);
            my %var_hash;
            my (@left_idx, @right_idx);

            $h->{style}="c";
            my ($left, $right);
            if($param=~/(.*?)\s*(?<![\+\-\*\/%&\|><=])=(?!=)\s*(.*)/){
                ($left, $right)=($1, $2);
            }
            else{
                $left=$param;
            }
            my @idxlist=('i','j','k','l');
            my @dimlist=MyDef::utils::proper_split($dimstr);
            foreach my $dim (@dimlist){
                my $idx=shift @idxlist;
                $h->{"$idx-dim"}=$dim;
                $h->{"$idx-var"}="$idx";

                if($left=~/\b$idx\b/){
                    push @left_idx, $idx;
                }
                else{
                    push @right_idx, $idx;
                }
            }
            my @segs=split /(\w+\[[ijkl,]*?\])/, $left;
            foreach my $s (@segs){
                if($s=~/^(\w+)\[([ijkl,]*?)\]$/){
                    if($var_hash{$s}){
                        $s=$var_hash{$s};
                    }
                    else{
                        my ($v, $idx_str)=($1, $2);
                        my @idxlist=split /,/, $idx_str;
                        my $t;
                        if(@idxlist==1){
                            my $idx=$idx_str;
                            $t="$v\[$idx\]";
                        }
                        else{
                            my $s;
                            foreach my $idx (@idxlist){
                                if(!$s){
                                    $s="$idx";
                                }
                                else{
                                    my $dim=$h->{"$idx-dim"};
                                    if($s=~/\+/){
                                        $s="($s)";
                                    }
                                    $s= "$s*$dim+$idx";
                                }
                            }
                            $t="$v\[$s\]";
                        }
                        $var_hash{$s}=$t;
                        $s=$t;
                    }
                }
            }
            $left=join '', @segs;
            $left=~s/\b([ijkl])\b/$1/g;
            if($right){
                my @segs=split /(\w+\[[ijkl,]*?\])/, $right;
                foreach my $s (@segs){
                    if($s=~/^(\w+)\[([ijkl,]*?)\]$/){
                        if($var_hash{$s}){
                            $s=$var_hash{$s};
                        }
                        else{
                            my ($v, $idx_str)=($1, $2);
                            my @idxlist=split /,/, $idx_str;
                            my $t;
                            if(@idxlist==1){
                                my $idx=$idx_str;
                                $t="$v\[$idx\]";
                            }
                            else{
                                my $s;
                                foreach my $idx (@idxlist){
                                    if(!$s){
                                        $s="$idx";
                                    }
                                    else{
                                        my $dim=$h->{"$idx-dim"};
                                        if($s=~/\+/){
                                            $s="($s)";
                                        }
                                        $s= "$s*$dim+$idx";
                                    }
                                }
                                $t="$v\[$s\]";
                            }
                            $var_hash{$s}=$t;
                            $s=$t;
                        }
                    }
                }
                $right=join '', @segs;
                $right=~s/\b([ijkl])\b/$1/g;
            }
            $h->{left}=$left;
            $h->{left_idx}=\@left_idx;
            $h->{right}=$right;
            $h->{right_idx}=\@right_idx;
            my $codelist=sumcode_generate($h);
            MyDef::compileutil::parseblock({source=>$codelist, name=>"sumcode"});
            return;
        }
        elsif($func eq "struct"){
            declare_struct($param1, $param2, 0);
            return;
        }
        elsif($func eq "union"){
            declare_struct($param1, $param2, 1);
            return;
        }
        elsif($func eq "get_pointer_type"){
            my $type=pointer_type(get_var_type($param2));
            MyDef::compileutil::set_current_macro($param1, $type);
            return;
        }
        elsif($func eq "register_include"){
            if($type_include{$param1}){
                $type_include{$param1}.=",$param2";
            }
            else{
                $type_include{$param1}.="$param2";
            }
            return;
        }
        elsif($func eq "register_fmt"){
            foreach my $t (split /,\s*/, $param1){
                if($param2=~/^\[(.*)\]$/){
                    my @t = split /,\s*/, $1;
                    $var_fmts{$t}=\@t;
                }
                else{
                    $var_fmts{$t}=$param2;
                }
            }
            return;
        }
        elsif($func eq "allocate"){
            allocate($param1, $param2, "malloc");
            return;
        }
        elsif($func eq "realloc"){
            allocate($param1, $param2, "realloc");
            return;
        }
        elsif($func eq "local_allocate"){
            allocate($param1, $param2, "auto");
            return;
        }
        elsif($func =~/^set_function_(prepend|append)$/){
            my $F = $functions{$param1};
            if(!$F){
                $F = {};
                $functions{$param1} = $F;
            }

            $F->{$1} = $param2;
            return;
        }
        elsif($func eq "dump"){
            debug_dump($param2, $param1, $out);
            return;
        }
    }
    elsif($l=~/^\s*\$(\w+)\s*(.*)$/){
        my ($func, $param)=($1, $2);
        if($param !~ /^=/){
            if($func eq "plugin"){
                foreach my $p (split /,\s*/, $param){
                    if($p=~/^&(.+)/){
                        if($p=~/_condition$/){
                            $plugin_condition{$1}=$p;
                        }
                        else{
                            $plugin_statement{$1}=$p;
                        }
                    }
                    else{
                        if($p=~/_condition$/){
                            $plugin_condition{$p}=$p;
                        }
                        else{
                            $plugin_statement{$p}=$p;
                        }
                    }
                }
                return;
            }
            elsif($plugin_statement{$func}){
                my $c= $plugin_statement{$func};
                if($c=~/^&(.+)/){
                    return "PARSE:\&call $1, $param";
                }
                else{
                    MyDef::compileutil::call_sub("$c, $param");
                }
                return;
            }
            if($func eq "block"){
                return single_block("$param\{", "}", "block");
            }
            elsif($func =~/^except/){
                return single_block("$except \{", "}", "else");
            }
            elsif($func =~ /^(while|switch)$/){
                my $name=$1;
                if($name eq "while" and $param=~/^(.*?);\s*(.*?);?\s*$/){
                    my @src;
                    push @src, "while ($1) {";
                    push @src, "INDENT";
                    push @src, "BLOCK";
                    push @src, "$2;";
                    push @src, "DEDENT";
                    push @src, "}";
                    MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                    return "NEWBLOCK-while";
                }
                else{
                    $param=parse_condition($param);
                    return single_block("$name ($param) {", "}");
                }
            }
            elsif($func =~ /^of$/){
                my @src;
                if($param eq "others"){
                    push @src, "default:";
                }
                else{
                    foreach my $c (split /,\s*/, $param){
                        push @src, "case $c:";
                    }
                }
                push @src, "INDENT";
                push @src, "BLOCK";
                push @src, "break;";
                push @src, "DEDENT";
                MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                return "NEWBLOCK-while";
            }
            elsif($func =~/^do(_?while)?$/){
                if($1){
                    $param=parse_condition($param);
                    return single_block("do{", "}while($param);");
                }
                else{
                    return single_block("while(1){", "break; }");
                }
            }
            elsif($func eq "include"){
                add_include($param);
                return;
            }
            elsif($func eq "declare"){
                if(!$declare_hash{$param}){
                    push @declare_list, $param;
                    $declare_hash{$param} = 1;
                }
                return;
            }
            elsif($func eq "define"){
                push @$out, "#define $param";
                return;
            }
            elsif($func eq "enum"){
                my $name="ANONYMOUS-$anonymous_count";
                $anonymous_count++;
                push @enum_list, $name;
                $enums{$name}=$param;
                return;
            }
            elsif($func eq "uselib"){
                my @flist=split /,\s*/, $param;
                foreach my $f (@flist){
                    if($f=~/^\w+$/){
                        add_object("lib$f");
                        if($lib_include{$f}){
                            add_include($lib_include{$f});
                        }
                    }
                    else{
                        add_object($f);
                    }
                }
                return;
            }
            elsif($func eq "var"){
                my @plist = MyDef::utils::proper_split($param);
                my $type;
                if($plist[0]=~/([^=]+)\s+(\*?\w+.*)/){
                    $type = $1;
                    $plist[0]=$2;
                }
                if($type){
                    foreach my $p (@plist){
                        if($p=~/^(\w+)/){
                            scope_add_symbol($1, $type);
                        }
                        elsif($p=~/^\*?(\w+)/){
                            scope_add_symbol($1, "$type *");
                        }
                    }
                    if($param!~/;\s*$/){
                        $param.=';';
                    }
                    push @$out, $param;
                    return;
                }
            }
            elsif($func eq "function"){
                my ($fname, $paramline, $return_type);
                if($param=~/(\w+)(.*)/){
                    ($fname, $paramline)=($1, $2);
                    if($paramline=~/^\s*\(\s*(.*)\)(.*)/){
                        $paramline=$1;
                        if($2=~/^\s*:\s*(.+)/){
                            $return_type = $1;
                        }
                    }
                    elsif($paramline=~/^\s*,\s*(.*)/){
                        $paramline=$1;
                    }
                }
                else{
                    my $fidx=$#function_list;
                    $fname = "fn-$fidx";
                }
                my $funcname=MyDef::utils::uniq_name($fname, \%list_function_hash);
                my ($func, $block)=function_block($funcname, $paramline, $return_type);
                func_push($func);
                unshift @$block, "OUTPUT:lambda-$funcname";
                push @$block, "PARSE:\$function_pop";

                if(!$list_function_hash{$funcname}){
                    $list_function_hash{$funcname}=1;
                    push @list_function_list, $funcname;
                }
                else{
                    $list_function_hash{$funcname}++;
                }
                MyDef::compileutil::set_current_macro("lambda", $funcname);

                MyDef::compileutil::set_named_block("NEWBLOCK", $block);
                return "NEWBLOCK";
                return;
            }
            elsif($func eq "in_function"){
                my ($fname, $paramline, $return_type);
                if($param=~/(\w+)(.*)/){
                    ($fname, $paramline)=($1, $2);
                    if($paramline=~/^\s*\(\s*(.*)\)(.*)/){
                        $paramline=$1;
                        if($2=~/^\s*:\s*(.+)/){
                            $return_type = $1;
                        }
                    }
                    elsif($paramline=~/^\s*,\s*(.*)/){
                        $paramline=$1;
                    }
                }
                else{
                    my $fidx=$#function_list;
                    $fname = "fn-$fidx";
                }
                my $func = $functions{$fname};
                if(!$func){
                    my $block;
                    ($func, $block)=function_block($fname, $paramline, $return_type);
                    my $idx = $func->{_idx};
                    $MyDef::compileutil::named_blocks{"$fname\_pre"} = $MyDef::compileutil::named_blocks{"fn$idx\_pre"};
                    $MyDef::compileutil::named_blocks{"$fname\_close"} = $MyDef::compileutil::named_blocks{"fn$idx\_close"};
                }
                $func->{skip_declare}=1;
                func_push($func);
                my $block;
                if($fname=~/^fn-/){
                    $block = ["DUMP_STUB $fname\_pre", "BLOCK", "DUMP_STUB $fname\_post", "PARSE:\$function_pop"];
                }
                else{
                    $block= ["BLOCK", "PARSE:\$function_pop"];
                }

                MyDef::compileutil::set_named_block("NEWBLOCK", $block);
                return "NEWBLOCK";
                return;
            }
            elsif($func eq "list"){
                my @tlist=split /,\s*/, $param;
                foreach my $f (@tlist){
                    if(!$list_function_hash{$f}){
                        $list_function_hash{$f}=1;
                        push @list_function_list, $f;
                    }
                    else{
                        $list_function_hash{$f}++;
                    }
                    $function_autolist{$f}="global";
                }
                return;
            }
            elsif($func eq "function_pop"){
                func_pop();
                return;
            }
            elsif($func=~/^(global|symbol|local|my|temp|static|extern)$/){
                if($param=~/(\w+)\s+(.*)$/ and $class_names{$1}){
                    my $scope=$func;
                    my ($class, $param)=($1, $2);
                    my $initname=$class."_init";
                    if($debug eq "type"){
                        print "\x1b[31m$class\x1b[0m - $param\n";
                    }
                    my $name;
                    if($param=~/^(\w+)(.*)/){
                        $name = $1;
                        $param = $2;
                    }
                    if($param=~/^(\[.*\])(.*)/){
                        $name .= $1;
                        $param = $2;
                    }
                    if($param=~/^\s*$/){
                        if($MyDef::def->{codes}->{"$initname"} or $MyDef::page->{codes}->{"$initname"}){
                            MyDef::compileutil::call_sub("$initname, $name, $scope, default");
                            return;
                        }
                    }
                    elsif($param=~/^\s*:\s*(.*)/){
                        if($MyDef::def->{codes}->{"$initname"} or $MyDef::page->{codes}->{"$initname"}){
                            MyDef::compileutil::call_sub("$initname, $name, $scope, $1");
                            return;
                        }
                    }
                    else{
                        my $curfile=MyDef::compileutil::curfile_curline();
                        print "[$curfile]\x1b[33m class syntax invalid [$param]\n\x1b[0m";
                    }
                }
                my @vlist;
                if($param=~/[({<][^)}>]*,/){
                    @vlist = ($param);
                }
                elsif($param=~/=\s*['"][^'"]*,/){
                    @vlist = ($param);
                }
                else{
                    @vlist = split_var_line($param);
                }
                foreach my $v (@vlist){
                    if($func eq "global"){
                        global_add_var($v);
                    }
                    elsif($func eq "local"){
                        func_add_var($v);
                    }
                    elsif($func eq "symbol"){
                        global_add_symbol($v);
                    }
                    elsif($func eq "my"){
                        my_add_var($v);
                    }
                    elsif($func eq "temp"){
                        temp_add_var($v);
                    }
                    elsif($func eq "static"){
                        my $var=global_add_var($v);
                        $var->{attr}="static";
                    }
                    elsif($func eq "extern"){
                        my $name=global_add_symbol($v);
                        my $decl=var_declare($global_hash->{$name}, 1);
                        if(!$declare_hash{"extern $decl"}){
                            push @declare_list, "extern $decl";
                            $declare_hash{"extern $decl"} = 1;
                        }
                    }
                    else{
                        my $curfile=MyDef::compileutil::curfile_curline();
                        print "[$curfile]\x1b[33m add_vars: \$$func not implemented.\n\x1b[0m";
                    }
                }
                return;
            }
            elsif($func eq "set_var_attr"){
                my @plist=split /,\s*/, $param;
                my $name=shift @plist;
                my $var=find_var_x($name);
                if($var){
                    foreach my $a (@plist){
                        if($a=~/(\w+)=(.*)/){
                            if($2 eq "--"){
                                delete $var->{$1};
                            }
                            else{
                                $var->{$1}=$2;
                            }
                        }
                    }
                }
                return;
            }
            elsif($func eq "get_var_attr"){
                my @plist=split /,\s*/, $param;
                my $name=shift @plist;
                my $var=find_var_x($name);
                if($var){
                    foreach my $a (@plist){
                        if($a=~/^(\w+)\((\w+)\)/){
                            MyDef::compileutil::set_current_macro($2, $var->{$1});
                        }
                        else{
                            MyDef::compileutil::set_current_macro($a, $var->{$a});
                        }
                    }
                }
                return;
            }
            elsif($func eq "protect_var"){
                my @tlist=MyDef::utils::proper_split($param);
                foreach my $t (@tlist){
                    protect_var($t);
                }
                return;
            }
            elsif($func eq "unprotect_var"){
                my @tlist=MyDef::utils::proper_split($param);
                foreach my $t (@tlist){
                    if($protected_var{$t}>0){
                        $protected_var{$t}--;
                    }
                }
                return;
            }
            elsif($func eq "typedef"){
                add_typedef($param);
                return;
            }
            elsif($func eq "sumcode" or $func eq "loop" or $func eq "sum"){
                if($debug){
                    print "parsecode_sum: [$param]\n";
                }
                my $h={};
                my (%k_hash, @k_list);
                my %var_hash;
                my (@left_idx, @right_idx);

                $h->{style}="c";
                my ($left, $right);
                if($param=~/(.*?)\s*(?<![\+\-\*\/%&\|><=])=(?!=)\s*(.*)/){
                    ($left, $right)=($1, $2);
                }
                else{
                    $left=$param;
                }
                my @segs=split /(\w+\[[ijkl,]*?\])/, $left;
                foreach my $s (@segs){
                    if($s=~/^(\w+)\[([ijkl,]*?)\]$/){
                        if($var_hash{$s}){
                            $s=$var_hash{$s};
                        }
                        else{
                            my ($v, $idx_str)=($1, $2);
                            my @idxlist=split /,/, $idx_str;
                            my $var=find_var($v);

                            my $i=0;
                            foreach my $idx (@idxlist){
                                $i++;
                                my $dim;
                                if($var->{"dim$i"}){
                                    $dim=$var->{"dim$i"};
                                }
                                elsif($var->{"dimension"} and $i==1){
                                    $dim=$var->{"dimension"};
                                }
                                else{
                                    my $curfile=MyDef::compileutil::curfile_curline();
                                    print "[$curfile]\x1b[33m sumcode: var $v missing dimension $i\n\x1b[0m";
                                }
                                if(!$h->{"$idx-dim"}){
                                    push @left_idx, $idx;
                                    $h->{"$idx-dim"}=$dim;
                                    $h->{"$idx-var"}="$idx";
                                }
                                else{
                                    if($h->{"$idx-dim"} ne $dim){
                                        my $old_dim=$h->{"$idx-dim"};
                                        print "sumcode dimesnion mismatch: $old_dim != $dim\n";
                                    }
                                }
                            }
                            my $t;
                            if(@idxlist==1){
                                my $idx=$idx_str;
                                $t="$v\[$idx\]";
                            }
                            else{
                                my $s;
                                foreach my $idx (@idxlist){
                                    if(!$s){
                                        $s="$idx";
                                    }
                                    else{
                                        my $dim=$h->{"$idx-dim"};
                                        if($s=~/\+/){
                                            $s="($s)";
                                        }
                                        $s= "$s*$dim+$idx";
                                    }
                                }
                                $t="$v\[$s\]";
                            }
                            $var_hash{$s}=$t;
                            $s=$t;
                        }
                    }
                }
                $left=join '', @segs;
                $left=~s/\b([ijkl])\b/$1/g;
                if($right){
                    my @segs=split /(\w+\[[ijkl,]*?\])/, $right;
                    foreach my $s (@segs){
                        if($s=~/^(\w+)\[([ijkl,]*?)\]$/){
                            if($var_hash{$s}){
                                $s=$var_hash{$s};
                            }
                            else{
                                my ($v, $idx_str)=($1, $2);
                                my @idxlist=split /,/, $idx_str;
                                my $var=find_var($v);

                                my $i=0;
                                foreach my $idx (@idxlist){
                                    $i++;
                                    my $dim;
                                    if($var->{"dim$i"}){
                                        $dim=$var->{"dim$i"};
                                    }
                                    elsif($var->{"dimension"} and $i==1){
                                        $dim=$var->{"dimension"};
                                    }
                                    else{
                                        my $curfile=MyDef::compileutil::curfile_curline();
                                        print "[$curfile]\x1b[33m sumcode: var $v missing dimension $i\n\x1b[0m";
                                    }
                                    if(!$h->{"$idx-dim"}){
                                        push @right_idx, $idx;
                                        $h->{"$idx-dim"}=$dim;
                                        $h->{"$idx-var"}="$idx";
                                    }
                                    else{
                                        if($h->{"$idx-dim"} ne $dim){
                                            my $old_dim=$h->{"$idx-dim"};
                                            print "sumcode dimesnion mismatch: $old_dim != $dim\n";
                                        }
                                    }
                                }
                                my $t;
                                if(@idxlist==1){
                                    my $idx=$idx_str;
                                    $t="$v\[$idx\]";
                                }
                                else{
                                    my $s;
                                    foreach my $idx (@idxlist){
                                        if(!$s){
                                            $s="$idx";
                                        }
                                        else{
                                            my $dim=$h->{"$idx-dim"};
                                            if($s=~/\+/){
                                                $s="($s)";
                                            }
                                            $s= "$s*$dim+$idx";
                                        }
                                    }
                                    $t="$v\[$s\]";
                                }
                                $var_hash{$s}=$t;
                                $s=$t;
                            }
                        }
                    }
                    $right=join '', @segs;
                    $right=~s/\b([ijkl])\b/$1/g;
                }
                $h->{left}=$left;
                $h->{left_idx}=\@left_idx;
                $h->{right}=$right;
                $h->{right_idx}=\@right_idx;
                my $codelist=sumcode_generate($h);
                MyDef::compileutil::parseblock({source=>$codelist, name=>"sumcode"});
                return;

            }
            elsif($func eq "tuple"){
                declare_tuple($param);
                return;
            }
            elsif($func eq "tuple_name"){
                get_T_name($param);
                return;
            }
            elsif($func =~/^(struct|union)$/){
                return "CALLBACK $func $param";
            }
            elsif($func eq "auto" or $func eq "Auto"){
                if($param=~/^(\w+)\s*=\s*(.*)/){
                    my ($name, $val) = ($1, $2);
                    $val=~s/\s*;\s*$//;
                    my $type=get_c_type($name);
                    if($type and $type ne "void"){
                        if($func eq "auto"){
                            push @$out, "$type $name = $val;";
                        }
                        else{
                            push @$out, "$type $name = dynamic_cast<$type>($val);";
                        }
                    }
                    elsif($val=~/(\w+)(\.|->)(find|begin|end)\b/){
                        my $t = get_c_type($1);
                        $t=~s/^const\s+//;
                        push @$out, $t."::const_iterator $name = $val;";
                    }
                    else{
                        print "$func: type for $name unknown\n";
                    }
                }
                elsif($param=~/^(\w+);?/){
                    my $name=$1;
                    my $type=get_c_type($name);
                    push @$out, "$type $name;";
                }
                return;
            }
            elsif($func eq "class"){
                my @tlist=split /,\s*/, $param;
                foreach my $t (@tlist){
                    if($t=~/^\s*(.*\S)\s*->\s*(\w+)/){
                        $class_names{$2}=1;
                        $type_class{$1}=$2;
                    }
                    else{
                        $class_names{$t}=1;
                    }
                }
                return;
            }
            elsif($func eq "fntype"){
                if($param=~/^(.*?)\((\s*\*\s*)?(\w+)\s*\)(.*)/){
                    my ($pre, $star, $name, $post)=($1, $2, $3, $4);
                    $fntype{$name}="$pre(*$name)$post";
                }
                else{
                    my $curfile=MyDef::compileutil::curfile_curline();
                    print "[$curfile]\x1b[33m fntype declaration error: [$param]\n\x1b[0m";
                }
                return;
            }
            elsif($func eq "allocate"){
                allocate("1", $param, "malloc");
                return;
            }
            elsif($func eq "for"){
                if($param=~/(.*);(.*);(.*)/){
                    my @src;
                    push @src, "for ($param) {";
                    push @src, "INDENT";
                    push @src, "BLOCK";
                    push @src, "DEDENT";
                    push @src, "}";
                    MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                    return "NEWBLOCK-for";
                }
                my $var;
                if($param=~/^(.+?)\s*=\s*(.*)/){
                    $var=$1;
                    $param=$2;
                }
                my ($i0, $i1, $step);
                if($param=~/^(.+?)\s+to\s+(.+)/){
                    my $to;
                    ($i0, $to, $step) = ($1, $2, 1);
                    if($to=~/(.+?)\s+step\s+(.+)/){
                        ($to, $step)=($1, $2);
                    }
                    $i1=" <= $to";
                }
                elsif($param=~/^(.+?)\s+downto\s+(.+)/){
                    my $to;
                    ($i0, $to, $step) = ($1, $2, 1);
                    if($to=~/(.+?)\s+step\s+(.+)/){
                        ($to, $step)=($1, $2);
                    }
                    $i1=" >= $to";
                    if($step!~/^-/){
                        $step="-$step";
                    }
                }
                else{
                    my @tlist=split /:/, $param;
                    if(@tlist==1){
                        $i0="0";
                        $i1="<$param";
                        $step="1";
                    }
                    elsif(@tlist==2){
                        if($tlist[1] eq "0"){
                            $i0="$tlist[0]-1";
                            $i1=">=$tlist[1]";
                            $step="-1";
                        }
                        elsif($tlist[1]=~/^[-0-9]+$/ && $tlist[0]=~/^[-0-9]+$/ && $tlist[0]>$tlist[1]){
                            $i0=$tlist[0];
                            $i1=">=$tlist[1]";
                            $step="-1";
                        }
                        else{
                            $i0=$tlist[0];
                            $i1="<$tlist[1]";
                            $step="1";
                        }
                    }
                    elsif(@tlist==3){
                        $i0=$tlist[0];
                        $step=$tlist[2];
                        if($step=~/^-/){
                            $i1=">=$tlist[1]";
                        }
                        else{
                            $i1="<$tlist[1]";
                        }
                    }
                }
                if(defined $i0){
                    my $T="int ";
                    if($step eq "1"){
                        $step="++";
                    }
                    elsif($step eq "-1"){
                        $step="--";
                    }
                    else{
                        $step=" += $step";
                    }

                    if(!$var){
                        $var = "i";
                        $var=MyDef::utils::uniq_name("i", \%protected_var);
                        MyDef::compileutil::set_current_macro("i", $var);
                    }
                    elsif($var=~/^(.*\S)\s+(\w+)$/){
                        $T= "$1 ";
                        $var = $2;
                    }
                    protect_var($var);

                    $param="$var = $i0; $var$i1; $var$step";
                    $param = "$T $param";
                    my @src;
                    push @src, "for ($param) {";
                    push @src, "INDENT";
                    push @src, "BLOCK";
                    push @src, "DEDENT";
                    push @src, "}";
                    push @src, "PARSE:\$unprotect_var $var";
                    MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                    return "NEWBLOCK-for";
                }
                return;
            }
            elsif($func eq "foreach"){
                if($param=~/(\w+)\s+in\s+(\w+)/){
                    my ($t, $v)=($1, $2);
                    my $var=find_var($v);
                    my $dim;

                    if(defined $var->{dimension}){
                        $dim=$var->{dimension};
                    }


                    if(defined $dim){
                        my $type=pointer_type($var->{type});
                        my $var=temp_add_var("i", $type_name{i});
                        my $i = $var->{name};
                        protect_var($i);
                        MyDef::compileutil::set_current_macro("t", "$v\[$i\]");
                        my $end="PARSE:\$unprotect_var $i";
                        my @src;
                        push @src, "for($i=0;$i<$dim;$i++){";
                        push @src, "INDENT";
                        push @src, "BLOCK";
                        push @src, "DEDENT";
                        push @src, "}";
                        push @src, $end;
                        MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                        return "NEWBLOCK-for";
                    }
                }
                elsif($param=~/^(\S+)\s*$/){
                    my ($t, $v)=("t", $1);
                    my $var=find_var($v);
                    my $dim;

                    if(defined $var->{dimension}){
                        $dim=$var->{dimension};
                    }


                    if(defined $dim){
                        my $type=pointer_type($var->{type});
                        my $var=temp_add_var("i", $type_name{i});
                        my $i = $var->{name};
                        protect_var($i);
                        MyDef::compileutil::set_current_macro("t", "$v\[$i\]");
                        my $end="PARSE:\$unprotect_var $i";
                        my @src;
                        push @src, "for($i=0;$i<$dim;$i++){";
                        push @src, "INDENT";
                        push @src, "BLOCK";
                        push @src, "DEDENT";
                        push @src, "}";
                        push @src, $end;
                        MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                        return "NEWBLOCK-for";
                    }
                }
            }
            elsif($func eq "yield"){
                $yield=$param;
                return;
            }
            elsif($func eq "fmt"){
                my ($n, $fmt)=fmt_string($param);
                MyDef::compileutil::set_current_macro("fmt_n", $n);
                MyDef::compileutil::set_current_macro("fmt", $fmt);
                return;
            }
            elsif($func eq "print"){
                add_include_direct("<stdio.h>");
                if(!$param){
                    push @$out, "puts(\"\");";
                }
                else{
                    $param=~s/^\s+//;
                    if($param=~/^usesub:\s*(\w+)/){
                        $print_type=$1;
                    }
                    else{
                        my ($n, $fmt)=fmt_string($param, 1);
                        if($print_type==1){
                            my $print_to = MyDef::compileutil::get_macro_word("print_to", 1);
                            if($print_to){
                                if($print_to =~/s_/){
                                    push @$out, "sprintf($print_to, $fmt);";
                                }
                                else{
                                    push @$out, "fprintf($print_to, $fmt);";
                                }
                            }
                            else{
                                if($n==0 and $fmt=~/^"(.*)\\n"/){
                                    push @$out, "puts(\"$1\");";
                                }
                                elsif($fmt=~/^"%s\\n", (.*)/){
                                    push @$out, "puts($1);";
                                }
                                else{
                                    push @$out, "printf($fmt);";
                                }
                            }
                        }
                        elsif($print_type){
                            MyDef::compileutil::call_sub("$print_type, $fmt");
                        }
                    }
                }
                return;
            }
            elsif($func eq "dump"){
                debug_dump($param, undef, $out);
                return;
            }
        }
    }
    elsif($l=~/^CALLBACK\s+(\w+)\s*(.*)/){
        my ($func, $param)=($1, $2);
        my $codelist=$MyDef::compileutil::named_blocks{"last_grab"};
        if($func =~/^(struct|union)$/){
            foreach my $l (@$codelist){
                if($l=~/^NOOP/){
                    $l='';
                }
                elsif($l=~/[:;]/){
                    $l = join ', ', split_var_line($l);
                }
            }
            my $t = join(', ', @$codelist);
            if($func eq "struct"){
                declare_struct($param, $t, 0);
            }
            else{
                declare_struct($param, $t, 1);
            }
            return;
        }
        return;
    }

    if(!$l or $l=~/^\s*$/){
    }
    elsif($l=~/^\s*#/){
    }
    elsif($l=~/^\s*(for|while|if|else if)\b/){
    }
    elsif($l=~/[:\(\{;,]\s*$/){
    }
    elsif($l=~/^\s*[)\]}].*$/){
    }
    else{
        if($l=~/^(\w+)\s+(.*)$/){
            if($functions{$1} or $stock_functions{$1}){
                my $fn=$1;
                my $t=$2;
                $t=~s/;\s*$//;
                $t=~s/\s+$//;
                $l="$fn($t)";
            }
        }
        $l=check_expression($l);
        if(!$l){
            return;
        }
        else{
            $l.=";";
        }
    }


    push @$out, $l;
}

sub dumpout {
    my ($f, $out)=@_;
    my $dump={out=>$out,f=>$f};
    my $mainfunc=$functions{"main"};
    if($mainfunc and !$mainfunc->{processed}){
        $has_main=1;
        $mainfunc->{skip_declare}=1;
        $mainfunc->{return_type}="int";
        $mainfunc->{param_list}=["int argc", "char** argv"];
        if(!$mainfunc->{return}){
            $mainfunc->{return}="return 0;";
        }
    }
    my $func_hook;
    if($MyDef::def->{codes}->{_FUNC_HOOK}){
        $func_hook = MyDef::compileutil::eval_sub("_FUNC_HOOK");
    }
    foreach my $func (@function_list){
        if(!$func->{processed}){
            process_function_std($func);
            my $name=$func->{name};
            if($func_hook){
                eval $func_hook;
            }
            if(!$has_main){
                if($function_autolist{$name} eq "static"){
                    $func->{declare}="static ".$func->{declare};
                }
                elsif($function_autolist{$name} eq "skip_declare"){
                    $func->{skip_declare} = 1;
                }
            }
            if($name=~/^(\w+)::/){
                my ($C) = ($1);
                $func->{skip_declare} = 1;
                my $block = MyDef::compileutil::get_named_block($C."_interface");
                my $t = $func->{declare};
                if($name eq $C."::"){
                    $t=~s/^.*::/$C/;
                    $func->{openblock}->[0]=~s/^.*::/$C\:\:$C/;
                    if($func->{inherit}){
                        $func->{openblock}->[0]=~s/({?)$/: $func->{inherit} $1/;
                    }
                }
                else{
                    $t=~s/$C\:\://;
                }
                push @$block, "$t;";
            }
        }
    }
    my $ofile=$page->{outdir}."/extern.o";
    my $otime=-M $ofile;
    my $need_update=0;
    my @externS;
    push @externS, "    .section .rodata";
    foreach my $t (@extern_binary){
        if($t=~/(.*):(.*)/){
            my ($name, $fname)=($1,$2);
            push @externS, "    .global _$name";
            push @externS, "    .align  4";
            push @externS, "_$name:";
            push @externS, "    .incbin \"$fname\"";
            if(-M $fname > $otime){
                $need_update=1;
            }
        }
    }
    if($need_update){
        print "  ---> $ofile\n";
        open Out, ">$page->{outdir}/extern.s";
        print Out join("\n", @externS), "\n";
        close Out;

        my $cmd= "as -o $ofile";
        open PIPE, "|$cmd" or die "Can't run $cmd\n";
        print PIPE join("\n", @externS), "\n";
        close PIPE;
    }
    if(-f $ofile){
        add_object("extern.o");
    }
    my @objlist;
    my @liblist;
    foreach my $i (@object_list){
        if($i=~/^lib(.*)\.a/){
            push @liblist, "-Wl,-Bstatic -l$1";
        }
        elsif($i=~/^lib(.*)/){
            push @liblist, "-l$1";
        }
        else{
            push @objlist, $i;
        }
    }
    my ($lib_list, $obj_list);
    if(@liblist){
        $lib_list=join(" ", @liblist);
        $page->{lib_list}=$lib_list;
    }
    if(@objlist){
        $obj_list=join(" ", @objlist);
        $page->{lib_list}.=" ".$obj_list;
    }

    my @t;
    if(!$page->{has_stub_frame_init}){
        push @t, "DUMP_STUB frame_init";
    }
    if(!$page->{has_stub_global_init}){
        push @t, "DUMP_STUB global_init";
    }
    if(!$page->{has_stub_meta_init}){
        push @t, "DUMP_STUB meta_init";
    }
    if(@t){
        unshift @$out, @t;
    }
    my @dump_init;

    $dump->{block_init}=\@dump_init;
    my $global_init=MyDef::compileutil::get_named_block("global_init");
    unshift @$global_init, "INCLUDE_BLOCK block_init";

    my $dump_out=\@dump_init;

    if(%objects){
        push @$dump_out, "/* link: $lib_list $obj_list */\n";
    }

    foreach my $type (keys %all_types){
        if($type=~/^(\w.*?)\s*\**$/){
            if($type_include{$1}){
                add_include($type_include{$1});
            }
        }
    }
    my @dump_h;
    my ($t_hfile, $t_dump, $t_template, $t_guard);
    $t_hfile = $page->{dump_h};
    if($t_hfile){
        if($t_hfile=~/^(\S+)\s+from\s+(.*)/){
            ($t_hfile, $t_template) = ($1, $2);
        }
        if($t_hfile=~/(\w+.h)$/){
            push @$dump_out, "#include \"$1\"\n\n";
            $t_guard = uc($1)."_INCLUDED";
            $t_guard=~s/\./_/g;
        }
        $t_dump = $dump_out;
        $dump_out = \@dump_h;
        print "dump_h ...\n";
    }
    if(@include_list){
        foreach my $k (@include_list){
            if($k=~/^(using namespace|#\w+)/){
                push @$dump_out, "$k\n";
            }
            else{
                push @$dump_out, "#include $k\n";
            }
        }
        push @$dump_out, "\n";
    }
    if($page->{use_bool} and !$page->{has_bool}){
        push @$dump_out, "typedef int bool;\n";
        push @$dump_out, "#define true 1\n";
        push @$dump_out, "#define false 0\n";
        push @$dump_out, "\n";
    }
    if(@define_list){
        foreach my $k (@define_list){
            push @$dump_out, "#define $k $defines{$k}\n";
        }
        push @$dump_out, "\n";
    }
    if(@enum_list){
        foreach my $name (@enum_list){
            my $t=$enums{$name};
            if(!$t){
                next;
            }
            if($name=~/^ANONYMOUS/){
                push @$dump_out, "enum {$t};\n";
            }
            elsif($name=~/^typedef,\s*(\w+)/){
                push @$dump_out, "typedef enum {$t} $1;\n";
            }
            elsif($name=~/^,\s*(\w+)/){
                push @$dump_out, "enum {$t} $1;\n";
            }
            else{
                push @$dump_out, "enum $name {$t};\n";
            }
        }
        push @$dump_out, "\n";
    }
    if(@typedef_list){
        foreach my $k (@typedef_list){
            my $t=$typedef_hash{$k};
            if($t=~/\(\*\s*(\w+)\)/){
                push @$dump_out, "typedef $t;\n";
            }
            else{
                push @$dump_out, "typedef $t $k;\n";
            }
        }
        push @$dump_out, "\n";
    }
    if($dump_classes){
        foreach my $l (@$dump_classes){
            push @$dump_out, $l;
        }
    }
    if(@struct_list){
        my (@S, @L, %invdep);
        foreach my $name (@struct_list){
            my $st = $structs{$name};
            my $s_list=$st->{list};
            my $s_hash=$st->{hash};
            my (@forward, @depend);
            foreach my $p (@$s_list){
                my $type = $s_hash->{$p};
                if($type=~/^(struct|union)\s+(\w+)(.*)/ && $structs{$2}){
                    if($3){
                        push @forward, "$1 $2";
                    }
                    else{
                        push @depend, $2;
                        if(!$invdep{$2}){
                            $invdep{$2}=[$name];
                        }
                        else{
                            push @{$invdep{$2}}, $name;
                        }
                    }
                }
            }
            if(@forward){
                $st->{_forward}=\@forward;
            }
            if(@depend){
                $st->{_depend}=\@depend;
            }
            if(!@depend){
                push @S, $name;
            }
        }
        if(!@S){
            die "All cyclic structures";
        }
        while(@S){
            my $name = shift @S;
            push @L, $name;
            if($invdep{$name}){
                foreach my $nm (@{$invdep{$name}}){
                    my $dep = $structs{$nm}->{_depend};
                    my $cnt=0;
                    foreach my $d (@$dep){
                        if($d eq "$name"){
                            $d = undef;
                        }
                        else{
                            $cnt++;
                        }
                    }
                    if($cnt==0){
                        unshift @S, $nm;
                    }
                }
            }
        }
        if(@L<@struct_list){
            die "There is cyclic struct dependency!\n";
        }
        my %declared;
        foreach my $name (@L){
            my $st = $structs{$name};
            my $s_list=$st->{list};
            my $s_hash=$st->{hash};
            if($st->{_forward}){
                foreach my $t (@{$st->{_forward}}){
                    if(!$declared{$t}){
                        push @$dump_out, "$t;\n";
                        $declared{$t}=1;
                    }
                }
            }
            my $T=$st->{type};
            $declared{"$T $name"}=1;
            if($st->{opaque}){
                push @$dump_out, "$T $name;\n";
            }
            else{
                if($st->{public}){
                    push @$dump_out, "$T $name { /*public*/\n";
                }
                else{
                    push @$dump_out, "$T $name {\n";
                }
                dump_struct_members($dump_out, $st, 1);
                push @$dump_out, "};\n\n";
            }
        }
    }
    foreach my $t (@function_declare_list){
        my $func=$functions{$t};
        if(!$func->{skip_declare}){
            if($func->{declare}!~/^static /){
                if($func->{declare_block}){
                    push @$dump_out, @{$func->{declare_block}};
                }
                else{
                    push @$dump_out, $func->{declare}.";\n";
                }
            }
        }
    }
    if($#$dump_out>-1 and $dump_out->[-1] ne "\n"){
        push @$dump_out, "\n";
    }

    if($t_hfile){
        if($t_hfile!~/\//){
            $t_hfile = $page->{_outdir}."/".$t_hfile;
        }
        open Out, ">$t_hfile" or die "Can't write $t_hfile.\n";
        print "  --> [$t_hfile]\n";
        if($t_template){
            open In, "$t_template" or die "Can't open $t_template.\n";
            while(<In>){
                print Out $_;
            }
            close In;
        }
        if($t_guard){
            print Out "#ifndef $t_guard\n";
            print Out "#define $t_guard\n\n";
        }
        foreach my $l (@dump_h){
            print Out $l;
        }
        if($t_guard){
            print Out "#endif /* $t_guard */\n";
        }
        close Out;
        $dump_out = $t_dump;
    }
    foreach my $t (@function_declare_list){
        my $func=$functions{$t};
        if(!$func->{skip_declare}){
            if($func->{declare}=~/^static /){
                if($func->{declare_block}){
                    push @$dump_out, @{$func->{declare_block}};
                }
                else{
                    push @$dump_out, $func->{declare}.";\n";
                }
            }
        }
    }
    if($#$dump_out>-1 and $dump_out->[-1] ne "\n"){
        push @$dump_out, "\n";
    }

    foreach my $l (@declare_list){
        if($l!~/;\s*$/){
            $l.=";";
        }
        push @$dump_out, "$l\n";
    }
    if(@declare_list){
        push @$dump_out, "\n";
    }
    if(@$global_list){
        foreach my $name (@$global_list){
            my $v=$global_hash->{$name};
            my $decl=var_declare($v);
            if($decl){
                if($decl=~/^(char\* \w+\s*=\s*)\[(\w.*)\]/){
                    my ($pre, $spec)=($1, $2);
                    my @lines;
                    if($spec=~/eval:\s*(\w+)/){
                        my $t=MyDef::compileutil::eval_sub($1);
                        @lines=split /\n/, $t;
                    }
                    elsif($spec=~/file:\s*(\S+)/){
                        if(open In, $1){
                            @lines = <In>;
                            close In;
                        }
                        else{
                            die "collect_file_str: Can't open $1\n";
                        }
                        foreach my $t (@lines){
                            $t=~s/\s*$//;
                        }
                    }
                    else{
                        die "unhandled global_static_string: [$spec]\n";
                    }

                    foreach my $t (@lines){
                        $t=~s/"/\\"/g;
                        $t.='\n';
                    }

                    my $t0=shift @lines;
                    my $tn=pop @lines;
                    push @$dump_out, "$pre\"$t0\"\n";

                    my $spc='    ';
                    foreach my $t (@lines){
                        push @$dump_out, "$spc\"$t\"\n";
                    }
                    push @$dump_out, "$spc\"$tn\";\n";
                }
                elsif($decl=~/(.*=\s*)\{DUMP_STUB\s*(\w+)\s*\}/){
                    push @$dump_out, "$1\{\n";
                    push @$dump_out, "INDENT";
                    push @$dump_out, "DUMP_STUB $2";
                    push @$dump_out, "DEDENT";
                    push @$dump_out, "};\n";
                }
                else{
                    push @$dump_out, "$decl;\n";
                }
            }
        }
        push @$dump_out, "\n";
    }

    foreach my $l (@initcodes){
        push @$dump_out, "$l\n";
    }
    if(@initcodes){
        push @$dump_out, "\n";
    }

    while($dump_out->[-1] eq "\n"){
        pop @$dump_out;
    }
    MyDef::dumpout::dumpout($dump);
}

sub single_block {
    my ($t1, $t2, $scope)=@_;
    my @src;
    push @src, "$t1";
    push @src, "INDENT";
    push @src, "BLOCK";
    push @src, "DEDENT";
    push @src, "$t2";
    MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
    if($scope){
        return "NEWBLOCK-$scope";
    }
    else{
        return "NEWBLOCK";
    }
}
sub add_typedef {
    my ($param)=@_;
    if($param=~/(.*)\s+(\w+)\s*$/){
        $typedef_hash{$2}=$1;
        push @typedef_list, $2;
    }
    elsif($param=~/\(\*\s*(\w+)\)/){
        $typedef_hash{$1}=$param;
        push @typedef_list, $1;
    }
}

1;

# ---- subroutines --------------------------------------------
sub open_scope {
    my ($blk_idx, $scope_name) = @_;
    push @scope_stack, $cur_scope;
    $cur_scope={var_list=>[], var_hash=>{}, name=>$scope_name};
}

sub close_scope {
    my ($blk, $pre, $post) = @_;
    if(!$blk){
        $blk=$cur_scope;
    }

    my $return_line;
    if($out->[-1]=~/^(return|break|continue)/){
        $return_line = pop @$out;
    }
    my ($var_hash, $var_list);
    $var_hash=$blk->{var_hash};
    $var_list=$blk->{var_list};

    if(@$var_list){
        my @exit_calls;
        if(!$pre){
            $pre=MyDef::compileutil::get_named_block("_pre");
        }
        foreach my $v (@$var_list){
            my $var=$var_hash->{$v};
            my $decl=var_declare($var, 1);
            push @$pre, $decl;

            if($global_hash->{$v}){
                my $curfile=MyDef::compileutil::curfile_curline();
                print "[$curfile]\x1b[33m In $blk->{name}: local variable $v has existing global: $decl\n\x1b[0m";
            }

            if($var->{exit}){
                push @exit_calls, "$var->{exit}, $v";
            }
        }
        if(@$var_list){
            push @$pre, "\n";
        }

        if(@exit_calls){
            if(!$post){
                $post=MyDef::compileutil::get_named_block("_post");
            }
            my $out_save=$out;
            MyDef::compileutil::set_output($post);
            foreach my $call_line (@exit_calls){
                MyDef::compileutil::call_sub($call_line);
            }
            MyDef::compileutil::set_output($out_save);
        }
    }
    if($return_line){
        if(!$post){
            $post= MyDef::compileutil::get_named_block("_post");
        }
        push @$post, $return_line;
    }

    $cur_scope=pop @scope_stack;

}

sub find_var {
    my ($name) = @_;
    if($debug eq "scope"){
        print "  cur_scope\[$cur_scope->{name}]: ";
        foreach my $v (@{$cur_scope->{var_list}}){
            print "$v, ";
        }
        print "\n";
        for (my $i = $#scope_stack; $i>=0; $i--) {
            print "  scope $i\[$scope_stack[$i]->{name}]: ";
            foreach my $v (@{$scope_stack[$i]->{var_list}}){
                print "$v, ";
            }
            print "\n";
        }
    }
    if($cur_scope->{var_hash}->{$name}){
        return $cur_scope->{var_hash}->{$name};
    }

    for (my $i = $#scope_stack; $i>=0; $i--) {
        if($scope_stack[$i]->{var_hash}->{$name}){
            return $scope_stack[$i]->{var_hash}->{$name};
        }
    }
    return undef;
}

sub func_push {
    my ($func) = @_;
    push @function_stack, $cur_function;
    $cur_function = $func;

    push @scope_stack, $cur_scope;
    $cur_scope=$cur_function;
}

sub func_pop {
    $cur_function=pop @function_stack;
    $cur_scope=pop @scope_stack;
    my $level=@function_stack;
    if($level==0){
        my $l = "\$function_pop";
        @case_stack=();
        undef $case_state;
        if($debug eq "case"){
            print "    CASE RESET\n";
        }
    }
}

sub function_block {
    my ($funcname, $paramline, $return_type) = @_;
    my $func=open_function($funcname, $paramline, $return_type);

    my @block;
    push @function_list, $func;
    my $fidx=$#function_list;
    $func->{_idx}=$fidx;

    $func->{openblock}=[];
    MyDef::compileutil::set_named_block("fn$fidx\_open", $func->{openblock});
    $func->{preblock}=[];
    MyDef::compileutil::set_named_block("fn$fidx\_pre", $func->{preblock});
    $func->{postblock}=[];
    MyDef::compileutil::set_named_block("fn$fidx\_post", $func->{postblock});
    $func->{closeblock}=[];
    MyDef::compileutil::set_named_block("fn$fidx\_close", $func->{closeblock});

    push @block, "DUMP_STUB fn$fidx\_open";
    push @block, "INDENT";
    push @block, "DUMP_STUB fn$fidx\_pre";

    push @block, "BLOCK";

    push @block, "DUMP_STUB fn$fidx\_post";
    push @block, "DEDENT";
    push @block, "DUMP_STUB fn$fidx\_close";

    MyDef::compileutil::set_current_macro("FunctionName", $funcname);
    MyDef::compileutil::set_current_macro("recurse", $funcname);
    return ($func, \@block);
}

sub open_function {
    my ($fname, $param, $return_type) = @_;
    my $func;
    if($fname eq "main"){
        $func = $main_func;
        $func->{init} = MyDef::compileutil::get_named_block("main_init");
        $func->{finish} = MyDef::compileutil::get_named_block("main_exit");
        $functions{$fname} = $func;
    }
    elsif($functions{$fname}){
        $func = $functions{$fname};
        if(!$param and $func->{parameter}){
            $param = $func->{parameter};
        }
    }
    else{
        $func = {};
        $functions{$fname} = $func;
    }

    $func->{name} = $fname;
    $func->{param_list} = [];
    $func->{var_list} = [];
    $func->{var_hash} = {};

    $func->{init} = [];
    $func->{finish} = [];
    MyDef::compileutil::set_named_block("fn_init", $func->{init});
    MyDef::compileutil::set_named_block("fn_finish", $func->{finish});

    if(!$param){
        if($fntype{$fname}=~/^override\s+(.*)/){
            my $t=$1;
            if($t=~/^(.*?)\s*(\w+)\s*\(\s*(.*)\)/){
                $func->{return_type}=$1;
                $param=$3;
            }
        }
    }
    my $api_name;
    if($param=~/^api\s+(\w+)$/){
        $api_name=$1;
    }
    elsif((!$param or $param eq "api") and ($fntype{$fname} or $fname=~/.+?_(.+)/ and $fntype{$1})){
        if($fntype{$fname}){
            $api_name = $fname;
        }
        else{
            $api_name=$1;
        }
    }
    if($api_name){
        if($fntype{$api_name}){
            my $t=$fntype{$api_name};
            if($t=~/^(.*?)\s*\(\*(\w+)\)\s*\(\s*(.*)\)/){
                $func->{return_type}=$1;
                $param=$3;
            }
        }
        else{
            die "function $fname($param): api $api_name not found\n";
        }
    }
    if($param){
        my $param_list=$func->{param_list};
        my $var_hash=$func->{var_hash};
        my @plist=split_var_line($param);
        my $i = -1;
        foreach my $p (@plist){
            $i++;
            my ($type, $name);
            $p=~s/\s+$//;
            if($p=~/^\s*(\w+)\s*:(?!:)\s*(.+)$/){
                ($type, $name)=($2, $1);
            }
            elsif($p=~/(\S.*)\s+(\S+)$/){
                ($type, $name)=($1, $2);
                if($fntype{$type}){
                    my $t = $fntype{$type};
                    $t =~s/\b$type\b/$name/;
                    push @$param_list, $t;
                    $var_hash->{$name}={name=>$name, type=>"function"};
                    next;
                }
                else{
                    if($name=~/^(\*+)(.+)/){
                        $type.=" $1";
                        $name=$2;
                    }
                    elsif($name=~/^(&)(.+)/){
                        $type.=" $1";
                        $name=$2;
                    }
                }
            }
            elsif($p eq "fmt" and $i==@plist){
                push @$param_list, "const char * fmt, ...";
                next;
            }
            elsif($p eq "..." and $i==@plist){
                push @$param_list, "...";
                next;
            }
            else{
                if($fntype{$p}){
                    push @$param_list, $fntype{$p};
                    $var_hash->{$p}={name=>$p, type=>"function"};
                    next;
                }
                else{
                    $type= get_c_type($p);
                    if(!$type){
                        my $curfile=MyDef::compileutil::curfile_curline();
                        print "[$curfile]\x1b[33m Failed get_c_type: $p [$param]\n\x1b[0m";
                    }
                    $name=$p;
                }
            }

            if($name){
                if($name=~/&(\w+)/){
                    $name="p_$1";
                    $type.=" *";
                    MyDef::compileutil::set_current_macro($1, "(*p_$1)");
                }

                if($type=~/^(\w+)\s+(.+)/ and $class_names{$1}){
                    my $class= $1;
                    my $type = $2;
                    print "class param: $class - $type\n";
                    my @plist = split /,\s*/, MyDef::compileutil::get_macro("$class\_param:$name,$type", 1);
                    my @attrs = split /,\s*/, MyDef::compileutil::get_macro("$class\_attrs:$name", 1);
                    foreach my $p (@plist){
                        if($p=~/(.+)\s+(\w+)$/){
                        }
                        push @$param_list, simple_var_declare($1, $2);
                        my $var={name=>$2, type=>$1};
                        $var_hash->{$2}=$var;
                        if($name eq $2){
                            foreach my $a (@attrs){
                                if($a=~/(\w+)=(.+)/){
                                    $var->{$1}=$2;
                                }
                            }
                        }
                    }
                    next;
                }
                push @$param_list, simple_var_declare($type, $name);
                my $var={name=>$name, type=>$type};
                $var_hash->{$name}=$var;
            }
        }
    }
    if($return_type){
        $func->{return_type}=$return_type;
    }
    if($fname){
        push @function_declare_list, $fname;
    }
    return $func;
}

sub process_function_std {
    my ($func) = @_;
    my $name=$func->{name};
    my $open = $func->{openblock};
    my $close = $func->{closeblock};
    my $pre = $func->{preblock};
    my $post = $func->{postblock};
    if(!$func->{return_type} and $func->{ret_var}){
        my $curfile=MyDef::compileutil::curfile_curline();
        print "[$curfile]\x1b[33m Failed to infer function $name return type from [$func->{ret_var}]\n\x1b[0m";
    }


    my $return_type = $func->{return_type};
    if(!$return_type){
        $return_type="void";
        $func->{return_type}=$return_type;
    }
    else{
        if($return_type eq "bool"){
            $page->{use_bool}=1;
        }
    }

    my $declare=$func->{declare};
    if(!$declare){
        my $param_list=$func->{"param_list"};
        my $param=join(', ', @$param_list);
        $declare="$return_type $name($param)";
        $func->{declare}=$declare;
    }
    push @$open, $declare;
    push @$open, "{";
    push @$close, "}";
    close_scope($func, $pre, $post);
    push @$pre, @{$func->{init}};
    push @$post, @{$func->{finish}};
    if($func->{return}){
        push @$post, $func->{return};
    }
}

sub func_return {
    my ($t) = @_;
    MyDef::compileutil::trigger_block_post();
    if($cur_function->{return_type}){
        return "return $t";
    }
    elsif(!$t and $t ne '0'){
        $cur_function->{return_type}=undef;
        return "return";
    }
    else{
        $cur_function->{ret_var} = $t;
        if($t=~/^[^(]+,/){
            $cur_function->{return_type}="void";
            my @tlist=split /,\s*/, $t;
            my $param_list=$cur_function->{param_list};
            my @rlist;
            my $i=0;
            foreach my $t (@tlist){
                $i++;
                my $type=infer_value_type($t);
                push @$param_list, "$type * T$i";
                push @rlist, "*T$i = $t";
            }
            $cur_function->{return_tuple}=$i;
            push @rlist, "return";
            return join("; ", @rlist);
        }
        else{
            $cur_function->{return_type}=infer_value_type($t);
        }

        return "return $t";
    }
}

sub split_var_line {
    my ($l) = @_;
    if($custom_split_var_line){
        return $custom_split_var_line->($l);
    }
    my @plist;
    if($l=~/;/ or $l=~/\w+\s*:[^:]/){
        my @parts=split /;\s*/, $l;
        foreach my $p (@parts){
            my @tlist = split /,\s*/, $p;
            if(@tlist==1){
                push @plist, $p;
            }
            else{
                my ($cnt, $idx);
                for (my $i = 0; $i<@tlist; $i++) {
                    if($tlist[$i]!~/^\w+\s*$/){
                        $cnt++;
                        $idx=$i;
                    }
                }
                if($tlist[0]=~/(.*\S)\s+(\w+)$/ and $cnt==1){
                    my $type = $1;
                    $tlist[0]= $2;
                    foreach my $w (@tlist){
                        push @plist, "$type $w";
                    }
                }
                elsif($tlist[-1]=~/^(\w+)\s*:(?!:)\s*(.+)$/ and $cnt==1){
                    my $type = $2;
                    $tlist[-1]= $1;
                    foreach my $w (@tlist){
                        push @plist, "$w:$type";
                    }
                }
                else{
                    push @plist, @tlist;
                }
            }
        }
    }
    else{
        my $t;
        my $angle_level=0;
        while(1){
            if($l=~/\G\s*$/gc){
                last;
            }
            elsif($angle_level==0){
                if($l=~/\G([^,<]+)/gc){
                    $t.=$1;
                }
                elsif($l=~/\G(<)/gc){
                    $angle_level++;
                    $t.=$1;
                }
                elsif($l=~/\G(,\s*)/gc){
                    if($t){
                        push @plist, $t;
                    }
                    $t="";
                }
            }
            else{
                if($l=~/\G([^<>]+)/gc){
                    $t.=$1;
                }
                elsif($l=~/\G(<)/gc){
                    $angle_level++;
                    $t.=$1;
                }
                elsif($l=~/\G(>)/gc){
                    $angle_level--;
                    $t.=$1;
                }
            }
        }
        if($t){
            push @plist, $t;
        }
    }
    return @plist;
}

sub global_add_symbol {
    my ($name, $type, $value) = @_;
    return f_add_var($global_hash, undef, $name, $type, $value);
}

sub global_add_var {
    my ($name, $type, $value) = @_;
    return f_add_var($global_hash, $global_list, $name, $type, $value);
}

sub func_add_var {
    my ($name, $type, $value) = @_;
    my $var_list=$cur_function->{var_list};
    my $var_hash=$cur_function->{var_hash};
    return f_add_var($var_hash, $var_list, $name, $type, $value);
}

sub func_add_symbol {
    my ($name, $type, $value) = @_;
    my $var_hash=$cur_function->{var_hash};
    return f_add_var($var_hash, undef, $name, $type, $value);
}

sub scope_add_var {
    my ($name, $type, $value) = @_;
    my $var_list=$cur_scope->{var_list};
    my $var_hash=$cur_scope->{var_hash};
    return f_add_var($var_hash, $var_list, $name, $type, $value);
}

sub scope_add_symbol {
    my ($name, $type, $value) = @_;
    my $var_hash=$cur_scope->{var_hash};
    return f_add_var($var_hash, undef, $name, $type, $value);
}

sub my_add_var {
    my ($name, $type, $value) = @_;
    my $var_hash=$cur_scope->{var_hash};
    my $var=parse_var($name, $type, $value);
    $name = $var->{name};
    $var_hash->{$name} = $var;
    my $decl = var_declare($var, 1);
    push @$out, $decl;
    return $var;
}

sub temp_add_var {
    my ($name, $type, $value) = @_;
    my $var=parse_var($name, $type, $value);
    $name=$var->{name};

    my $macro_name=$name;
    $name=MyDef::utils::uniq_name($name, \%protected_var);

    if($debug eq "type"){
        print "temp_var $macro_name -> $name of $var->{type}\n";
    }

    my $hash=$cur_scope->{var_hash};
    $type=$var->{type};
    if($hash->{$name}){
        my $i=2;
        if($name=~/[0-9_]/){
            $name.="_";
        }
        while($hash->{"$name$i"}){
            $i++;
        }
        $name="$name$i";
    }
    if(!$hash->{$name}){
        $var->{name}=$name;
        $var->{temptype}=$type;
        $hash->{$name}=$var;
        my $decl = var_declare($var, 1);
        push @$out, $decl;
    }

    MyDef::compileutil::set_current_macro($macro_name, $name);
    return $var;
}

sub f_add_var {
    my ($h, $l, $name, $type, $value) = @_;
    my $var=parse_var($name, $type, $value);
    $name=$var->{name};
    if($h->{$name}){
        my $exist = $h->{$name};
        if($var->{type} eq $exist->{type}){
            if($var->{array} > $exist->{array}){
                $exist->{array}=$var->{array};
                $exist->{dimension}=$var->{array};
            }
            if(defined $var->{init}){
                if(!defined $exist->{init}){
                    $exist->{init}=$var->{init};
                }
                elsif($exist->{init} ne $var->{init}){
                    my $curfile=MyDef::compileutil::curfile_curline();
                    print "[$curfile]\x1b[33m var $name has double initializations ($exist->{init} -> $var->{init})\n\x1b[0m";
                }
            }
        }
        return $exist;
    }
    else{
        if($l){
            push @$l, $name;
        }
        $h->{$name}=$var;
        return $var;
    }

}

sub find_var_x {
    my ($name) = @_;
    if($name=~/(.*)(\.|->)(\w+)$/){
        my ($vdot, $mem)=("$1$2", $3);
        my $t = get_var_type($1);
        my $var= get_struct_element($t, $mem);
        $var->{struct}=$vdot;
        return $var;
    }
    elsif($name=~/^\w+$/){
        my $scope=MyDef::compileutil::get_current_macro("scope");
        if($scope=~/struct\((\w+)\)/){
            return get_struct_element("struct $1", $name);
        }
        else{
            return find_var($name);
        }
    }
}

sub get_var_type_direct {
    my ($name) = @_;
    my $var=find_var($name);

    if($var){
        return $var->{type};
    }
    else{
        return get_type_name($name);
    }
}

sub protect_var {
    my ($v) = @_;
    if($protected_var{$v}){
        my $curfile=MyDef::compileutil::curfile_curline();
        print "[$curfile]\x1b[33m Variable $v protected: [$protected_var{$v}]\n\x1b[0m";
        $protected_var{$v}++;
    }
    else{
        $protected_var{$v}=1;

    }
}

sub get_type_name {
    my ($name, $no_prefix) = @_;
    if($type_name{$name}){
        return $type_name{$name};
    }
    elsif($type_prefix{$name}){
        return $type_prefix{$name};
    }
    elsif($name=~/^([a-zA-Z]+)\d+$/ and ($type_name{$1} or $type_prefix{$1})){
        return get_type_name($1);
    }
    elsif(!$no_prefix and $name=~/^([tp]+)_(.+)$/){
        my $type = get_type_name($2, 1);
        if($type){
            return get_type_word_prefix($1, $type);
        }
    }

    if(!$no_prefix and $name=~/^([tp]+)(.)(_.+)?$/ and $type_prefix{$2}){
        return get_type_word_prefix($1, $type_prefix{$2});
    }
    elsif($name=~/^([^_]+)/ && $type_prefix{$1}){
        return $type_prefix{$1};
    }
    elsif($name=~/^([^_0-9]+)/ && $type_prefix{$1}){
        return $type_prefix{$1};
    }
    elsif($name=~/_([^_]+)$/ && length{$1}>1 && $type_name{$1}){
        return $type_name{$1};
    }
    return undef;
}

sub get_type_word_prefix {
    my ($prefix, $type) = @_;
    foreach my $c (reverse(split //, $prefix)){
        if($c eq "t"){
        }
        elsif($c eq "p"){
            $type.= "*";
        }
        else{
            return undef;
        }
    }
    return $type;
}

sub parse_condition {
    my ($param) = @_;
    $param=~s/;\s*$//;
    if($param=~/^\$(\w+)\s+(.*)/){
        my ($func, $param)=($1, $2);
        if($plugin_condition{$func}){
            my $condition;
            my $codename=$plugin_condition{$func};
            my $t=MyDef::compileutil::eval_sub($codename);
            eval $t;
            if($@ and !$MyDef::compileutil::eval_sub_error{$codename}){
                $MyDef::compileutil::eval_sub_error{$codename}=1;
                print "evalsub - $codename\n";
                print "[$t]\n";
                print "eval error: [$@] package [", __PACKAGE__, "]\n";
            }
            return $condition;
        }
    }
    elsif($param=~/^\/(.*)\/(i?)\s*(.*)$/){
        return translate_regex($1, $2, $3);
    }
    elsif($param=~/^(\S+)\s+in\s+(.+)/){
        my ($v, $t) = ($1, $2);
        my @tlist = split /,\s*/, $t;
        foreach my $t (@tlist){
            $t="$v==$t";
        }
        return join(" || ", @tlist);
    }
    return check_expression($param, "condition");
}

sub get_T_name {
    my ($param) = @_;
    my $name;
    if($tuple_hash{$param}){
        $name = $tuple_hash{$param};
    }
    else{
        $name=MyDef::utils::uniq_name("T", \%structs);
        $tuple_hash{$param}=$name;
    }

    MyDef::compileutil::set_current_macro("T", $name);
    return $name;
}

sub declare_tuple {
    my ($param) = @_;
    my $name=get_T_name($param);

    my $s_list=[];
    my $s_hash={};
    $structs{$name}={list=>$s_list, hash=>$s_hash, type=>"struct"};
    push @struct_list, $name;
    my @plist=split /,\s*/, $param;
    my $i=0;
    foreach my $p (@plist){
        $i++;
        my $m_name="a$i";
        push @$s_list, $m_name;
        $s_hash->{$m_name}=$p;
    }
    return $name;
}

sub declare_union {
    my ($name, $param) = @_;
    declare_struct($name, $param, 1);
}

sub declare_struct {
    my ($name, $param, $is_union) = @_;
    my ($s_list, $s_hash);
    my ($s_init, $s_exit);
    my $st;
    if($name and $structs{$name}){
        $st = $structs{$name};
        $s_list=$st->{list};
        $s_hash=$st->{hash};
    }
    else{
        $s_list=[];
        $s_hash={};
        $st={list=>$s_list,hash=>$s_hash};
        if($name){
            $structs{$name}= $st;
            push @struct_list, $name;
        }
    }
    my $T="struct";
    if($is_union){
        $T="union";
    }
    $st->{type}=$T;
    if($name){
        $type_prefix{"st$name"}="$T $name";
        if(length($name)>4 and !$type_name{$name}){
            $type_name{$name} = "$T $name";
        }
    }
    if($param=~/(\w+)\s+(.*)$/ and $class_names{$1}){
        my $scope="struct($name)";
        my ($class, $param)=($1, $2);
        my $initname=$class."_init";
        if($debug eq "type"){
            print "\x1b[31m$class\x1b[0m - $param\n";
        }
        my $name;
        if($param=~/^(\w+)(.*)/){
            $name = $1;
            $param = $2;
        }
        if($param=~/^(\[.*\])(.*)/){
            $name .= $1;
            $param = $2;
        }
        if($param=~/^\s*$/){
            if($MyDef::def->{codes}->{"$initname"} or $MyDef::page->{codes}->{"$initname"}){
                MyDef::compileutil::call_sub("$initname, $name, $scope, default");
                return;
            }
        }
        elsif($param=~/^\s*:\s*(.*)/){
            if($MyDef::def->{codes}->{"$initname"} or $MyDef::page->{codes}->{"$initname"}){
                MyDef::compileutil::call_sub("$initname, $name, $scope, $1");
                return;
            }
        }
        else{
            my $curfile=MyDef::compileutil::curfile_curline();
            print "[$curfile]\x1b[33m class syntax invalid [$param]\n\x1b[0m";
        }
    }
    my @plist=MyDef::utils::proper_split($param);
    my $i=0;
    my $anon_union;
    foreach my $p (@plist){
        my ($m_name, $type, $needfree);
        if($p=~/^@/){
            $needfree=1;
            $p=$';
        }
        elsif($p=~/^\s*$/){
            next;
        }
        elsif($p=~/^-(\w+)=>(.*)/){
            $st->{$1}=$2;
            next;
        }
        elsif($p=~/class (\w+)/){
            my $o=$structs{$1};
            if($o){
                my $h=$o->{hash};
                my $l=$o->{list};
                foreach my $m (@$l){
                    if(!$s_hash->{$m}){
                        $s_hash->{$m}=$h->{$m};
                        push @$s_list, $m;
                    }
                }
            }
            next;
        }
        $i++;
        if($p=~/(.*?)(\S+)\s*=\s*(.*)/){
            $p="$1$2";
            push @$s_init, "$2=$3";
        }
        if($p=~/^(\w+)\s*:\s*(.+)/){
            ($m_name, $type)=($1,$2);
        }
        elsif($p=~/^(.*?)\{(.*)\}\s*$/){
            my ($t1, $t2) = ($1, $2);
            $type = "nest";
            my $is_union=0;
            if($t1=~/^(union\s*)(.*)/){
                $t1 = $2;
                $is_union=1;
            }
            if($t1=~/^(\w+)/){
                $m_name = $1;
            }
            else{
                $m_name = $i;
            }
            $st->{"nest-$m_name"}=declare_struct(undef, $t2, $is_union);
        }
        elsif($basic_types{$p} or $p=~/\*$/){
            $m_name="a$i";
            $type=$p;
        }
        elsif($p=~/^\w+$/){
            $m_name=$p;
            if($p=~/^(next|prev|left|right)$/){
                $type="struct $name *";
            }
            elsif($fntype{$p}){
                $type="function";
            }
            else{
                $type=get_c_type($p);
            }
        }
        else{
            my $v = parse_var($p);
            $m_name=$v->{name};
            $type=$v->{type};
            if($v->{array}){
                $type=~s/\s*\*$//;
                $type.=$v->{array};
            }
        }
        if($type eq "bool"){
            $page->{use_bool}=1;
        }
        if(!$s_hash->{$m_name}){
            push @$s_list, $m_name;
            $s_hash->{$m_name}=$type;
        }
        if($needfree){
            $st->{"needfree-$m_name"}=1;
        }
    }
    return $st;
}

sub get_struct_element {
    my ($stype, $name) = @_;
    if($stype=~/(\w+)(.*)/){
        if($typedef_hash{$1}){
            $stype=$typedef_hash{$1}.$2;
        }
    }
    if($stype=~/struct\s+(\w+)/){
        my $st=$structs{$1};
        my $s_hash=$st->{hash};
        if($s_hash->{$name}){
            return {name=>$name, type=>$s_hash->{$name}};
        }
        else{
            foreach my $k (keys(%$s_hash)){
                if($k=~/^$name\[/){
                    return {name=>$name, type=>$s_hash->{$k}.'*'};
                }
            }
        }
        if($debug eq "type"){
            while(my ($k, $v)=each %$s_hash){
                print "  :|$k: $v\n";
            }
            print "$name not defined in struct $1\n";
        }
    }
}

sub get_struct_element_type {
    my ($stype, $name) = @_;
    my $var=get_struct_element($stype, $name);
    if($var and $var->{type}){
        return $var->{type};
    }
    return "void";
}

sub parse_var {
    my ($name, $type, $value) = @_;
    my $init;
    my $explicit_type;
    my @attrs;
    my $array;
    my $type_given=$type;
    $name=~s/\s*;?\s*$//;
    if($name=~/^(.*\S+?)\s*=\s*(.*)/){
        ($name, $init)=($1, $2);
        if($init=~/^=\[binary_from_file:(\S+)\]/){
            $global_hash->{"_$name"}="extern char _$name";
            push @$global_list, "_$name";
            $init="=&_$name";
            push @extern_binary, "$name:$1";
        }
        if(!$value){
            $value=$init;
        }
    }
    if(!$type){
        if($name=~/^\s*(\w+)\s*:(?!:)\s*(.+)/){
            ($type, $name)=($2, $1);
            $explicit_type=1;
        }
        elsif($name=~/^\s*(.*\S)\s+(\S+)$/){
            ($type, $name)=($1, $2);
            $explicit_type=1;
            if($name=~/^(\*+)(.*)/){
                $type.=$1;
                $name=$2;
            }
        }
        if($explicit_type){
            if($name=~/^(\*+)(.+)/){
                $type.=" $1";
                $name=$2;
            }
            elsif($name=~/^(&)(.+)/){
                $type.=" $1";
                $name=$2;
            }
        }
    }
    if(!$type and $value){
        if($value =~/^\(([)]+)\)(\w+.*)/){
            $type = $1;
        }
        elsif($value =~/^new\s+([^({]+)/){
            $type = $1;
            if($type=~/\[.*\]$/){
                if($page->{_pageext} eq "java"){
                    $type=~s/\[(.*?)\]/[]/g;
                }
                else{
                    $type=~s/\[(.*?)\]/\*/g;
                }
            }
        }
    }
    if($type){
        while($type=~/^\s*(extern|static|const|register)\s*(.*)/){
            push @attrs, $1;
            $type=$2;
        }
    }
    if($name=~/(\w+)(\[.*\])/){
        $name=$1;
        $array=$2;
    }
    if(!$type){
        if($fntype{$name}){
            $type="function";
        }
        else{
            $type=get_c_type($name);
            if($type and $type eq "void"){
                undef $type;
            }
        }
        if(defined $value){
            my $val_type=infer_value_type($value);
            if($val_type){
                if(!$type){
                    $type= $val_type;
                }
                elsif($val_type =~/\*$/ and $type eq "void*"){
                    $type = $val_type;
                }
                else{
                    $val_type=~s/\s+(\*+)$/\1/;
                    if($type ne $val_type){
                        if($val_type eq "void"){
                        }
                        elsif($val_type=~/float|double/ and $type=~/float|double/){
                        }
                        elsif($val_type=~/char/ and $type=~/unsigned|int/){
                        }
                        elsif($val_type eq "int" and $type=~/(double|float|bool|int|char)/){
                        }
                        elsif($val_type eq "bool" and $type=~/boolean/){
                        }
                        elsif($val_type eq "void*" and $type=~/\*$/){
                        }
                        else{
                            my $curfile=MyDef::compileutil::curfile_curline();
                            print "[$curfile]\x1b[33m var $name set to type $type, different from value type $val_type\n\x1b[0m";
                        }
                    }
                }
            }
        }
    }
    if($type=~/(.*)(\[.+\])$/){
        $type =$1;
        $array=$2;
    }
    if($array){
        if($type!~/\*$/){
            $type.=" *";
        }
        elsif($type_given or $explicit_type){
            $type.="*";
        }
    }
    if($type=~/struct\s+(\w+)/ and !$structs{$1}){
        if($structure_autolist{$1}){
            my $s_list=[];
            my $s_hash={};
            my $st ={list=>$s_list, hash=>$s_hash};
            $structs{$1}=$st;
            push @struct_list, $1;
            if(ref($structure_autolist{$1}) eq "ARRAY"){
                foreach my $t (@{$structure_autolist{$1}}){
                    if($t=~/^\s*(.*\S)\s+(\w+);/){
                        push @$s_list, $2;
                        $s_hash->{$2}=$1;
                    }
                }
            }
            else{
                $s_hash->{opaque}=1;
            }
        }
    }

    $all_types{$type}=1;

    my $var={};
    $var->{name}=$name;
    $var->{type}=$type;
    $var->{init}=$init;
    if(@attrs){
        $var->{attr}=join(" ", @attrs);
    }
    if(defined $array){
        $var->{array}=$array;
        if($array=~/\[(.+)\]/){
        }
        $var->{dimension}=$1;
    }

    if($debug eq "type"){
        my $curfile=MyDef::compileutil::curfile_curline();
        print "[$curfile]\x1b[33m add_var: type:[$type] - $name ($array) - $init ($value)\n\x1b[0m";

    }
    return $var;

}

sub name_type_authortative {
    my ($name, $type) = @_;
    if(!$type or $type eq "void"){
        return 0;
    }
    if($type_name{$name}){
        return 0;
    }
    if($name=~/^(t_?)*(p_?)*([a-zA-Z][a-zA-Z0-9]*)\_/){
        my $prefix=$3;
        if($debug eq "type"){
            print "name_with_prefix: $prefix - $type_prefix{$prefix}\n";
        }
        if($prefix =~ /^[fn]$/){
            return 1;
        }
    }
    return 0;
}

sub simple_var_declare {
    my ($type, $name) = @_;
    if($type=~/^(.+?)([* ]+)$/){
        my ($T, $stars) = ($1, $2);
        $stars=~s/ //g;
        return "$T $stars$name";
    }
    else{
        return "$type $name";
    }
}

sub var_declare {
    my ($var, $need_semi) = @_;
    my $t;
    if($var->{type} eq "function"){
        $t =  $fntype{$var->{name}};
    }
    else{
        my $name=$var->{name};
        my $type=$var->{type};
        if(defined $var->{array}){
            $t=pointer_type($type)." $name"."$var->{array}";
        }
        else{
            $t = simple_var_declare($type, $name);
        }

        if(defined $var->{init}){
            if($var->{init} =~/^[(](.*)[)]\s*$/ && is_paren_balanced($1)){
                $t.="$var->{init}";
            }
            else{
                $t.=" = $var->{init}";
            }
        }
        if(defined $var->{attr}){
            $t = $var->{attr} . " $t";
        }
    }

    if($need_semi){
        $t .= ';';
    }
    return  $t;
}

sub is_paren_balanced {
    my ($t) = @_;
    my $i=0;
    foreach my $c (split //, $t){
        if($c eq '('){
            $i++;
        }
        elsif($c eq ')'){
            $i--;
            if($i<0){
                return 0;
            }
        }
    }
    return $i==0;
}

sub get_var_type {
    my ($name, $nowarn) = @_;
    if($name=~/^(\w+)(.*)/){
        my ($name,$tail)=($1,$2);
        my $base_type=get_var_type_direct($name);
        my $var = find_var($name);
        $base_type=~s/\s*&$//;
        return get_sub_type($base_type, $tail, $nowarn);
    }
    else{
        return "void";
    }
}

sub get_sub_type {
    my ($type0, $tail, $nowarn) = @_;
    if(!$type0){
        return "void";
    }

    if($tail=~/^(\.|->)(\w+)(.*)/){
        $tail=$3;
        my $type=get_struct_element_type($type0, $2);
        return get_sub_type($type, $tail, $nowarn);
    }
    elsif($tail=~/^\[.*?\](.*)/){
        my $new_tail=$1;
        if($type0=~/\*$/){
            return get_sub_type(pointer_type($type0), $new_tail, $nowarn);
        }
        else{
            if(!$nowarn){
                my $curfile=MyDef::compileutil::curfile_curline();
                print "[$curfile]\x1b[33m error in dereferencing pointer type $type0 ($tail)\n\x1b[0m";
            }
            return "void";
        }
    }
    else{
        return $type0;
    }
}

sub infer_value_type {
    my ($val) = @_;
    $val=~s/^[+-]//;
    if($val=~/^\((float|int|char|unsigned .*|.+\*)\)/){
        return $1;
    }
    elsif($val=~/^\((\w+)\)\w/){
        return $1;
    }
    elsif($val=~/^\((.*)/){
        return infer_value_type($1);
    }
    elsif($val=~/^\d+\./){
        return "float";
    }
    elsif($val=~/^\d+[eE]/){
        return "float";
    }
    elsif($val=~/^\d/){
        return "int";
    }
    elsif($val=~/^"/){
        return "char*";
    }
    elsif($val=~/^'/){
        return "char";
    }
    elsif($val=~/^(true|false)/){
        if($page->{has_bool}){
            return $page->{has_bool};
        }
        else{
            $page->{use_bool}=1;
            return "bool";
        }
    }
    elsif($val=~/(\w+)\(.*\)/){
        my $func=$functions{$1};
        if($debug){
            print "infer_value_type: function $1 [$func]\n";
        }
        if($func and $func->{return_type}){
            return $func->{return_type};
        }
    }
    elsif($val=~/^NULL$/){
        return "void*";
    }
    elsif($val=~/(\w+)(.*)/){
        my $type=get_var_type($val, 1);
        return $type;
    }
    elsif($val=~/^\((.+)\)$/){
        my @vlist=split /,\s*/, $1;
        my @plist;
        foreach my $v (@vlist){
            push @plist, infer_value_type($v);
        }
        my $tuple_name=declare_tuple(join(", ", @plist));
        return "struct $tuple_name";
    }
    return undef;
}

sub type_default {
    my ($type) = @_;
    if($type=~/\*$/){
        return "NULL";
    }
    elsif($type=~/float|double/){
        return "0.0";
    }
    elsif($type=~/char|signed|int/){
        return "0";
    }
    else{
        return undef;
    }
}

sub get_c_type {
    my ($name) = @_;
    my $type = get_type_name($name);
    if(!$type and $name=~/t?(p+)_(.*)/){
        my $count = length($1);
        return "void".('*'x$count);
    }

    if($type eq "bool"){
        $page->{use_bool}=1;
    }
    $type=~s/\s+(\*+)$/\1/;
    while($name=~/\[.*?\]/g){
        $type=pointer_type($type);
    }
    if($debug eq "type"){
        print "    get_c_type:   $name: $type\n";
    }
    return $type;
}

sub pointer_type {
    my ($t) = @_;
    $t=~s/\s*\*\s*$//;
    return $t;
}

sub get_var_fmt {
    my ($v, $warn) = @_;
    my $type=get_var_type($v, 1);
    if(!$type or $type eq "void"){
        $type=get_c_type($v);
    }

    if($var_fmts{$type}){
        my $t = $var_fmts{$type};
        if(ref($t) eq "ARRAY"){
            my @fmt = @$t;
            foreach (@fmt){
                s/\$1/$v/g;
            }
            return @fmt;
        }
        else{
            return $t;
        }
    }
    elsif($type=~/^char\s*\*/){
        return "\%s";
    }
    elsif($type=~/\*\s*$/){
        return "\%p";
    }
    elsif($type =~ /^(u?)int64_t/){
        add_include("<inttypes.h>");
        if($1){
            return '%" PRIu64 "';
        }
        else{
            return '%" PRId64 "';
        }
    }
    elsif($type=~/(int|long|u?int\d+_t)\s*$/){
        return "\%d";
    }
    elsif($var_fmts{default}){
        my $t = $var_fmts{default};
        if(ref($t) eq "ARRAY"){
            my @fmt = @$t;
            foreach (@fmt){
                s/\$1/$v/g;
            }
            return @fmt;
        }
        else{
            return $t;
        }
    }
    else{
        if($warn){
            my $curfile=MyDef::compileutil::curfile_curline();
            print "[$curfile]\x1b[33m get_var_fmt: unhandled $v - $type, default to \%d\n\x1b[0m";
        }
        return '%d';
    }
}

sub add_object {
    my ($l) = @_;
    if(!$objects{$l}){
        $objects{$l}=1;
        push @object_list, $l;
    }
}

sub add_include {
    my ($l) = @_;
    my @flist=split /,\s*/, $l;
    foreach my $f (@flist){
        if($f=~/^define\s+(.*)/){
            push @include_list, "#define $1";
            next;
        }

        my $key;
        if($f=~/\.\w+$/){
            $key="\"$f\"";
        }
        elsif($f=~/^[A-Z_]+/){
            $key=$f;
        }
        elsif($f=~/^".*"$/){
            $key=$f;
        }
        elsif($f=~/^<.*>$/){
            $key=$f;
        }
        elsif($f=~/^\S+$/){
            $key="<$f.h>";
        }
        else{
            $key=$f;
        }
        add_include_direct($key);
    }
}

sub add_include_direct {
    my ($key) = @_;
    if(!$includes{$key}){
        $includes{$key}=1;
        push @include_list, $key;
    }
}

sub add_define {
    my ($name, $definition) = @_;
    if(!defined $defines{$name}){
        push @define_list, $name;
    }
    else{
        warn "Duplicate define $name: [$defines{$name}] -> [$definition]\n";
    }
    $defines{$name}=$definition;
}

sub dump_struct_members {
    my ($dump_out, $st, $indent) = @_;
    my $s_list=$st->{list};
    my $s_hash=$st->{hash};
    my $sp = '    ' x $indent;
    foreach my $p (@$s_list){
        my $type=$s_hash->{$p};
        if($type eq "function"){
            push @$dump_out, "$sp".$fntype{$p}.";\n";
        }
        elsif($type eq "nest"){
            my $t=$st->{"nest-$p"};
            my $T = $t->{type};
            push @$dump_out, "$sp$T {\n";
            dump_struct_members($dump_out, $t, $indent+1);
            if($p=~/^\d/){
                push @$dump_out, "$sp};\n";
            }
            else{
                push @$dump_out, "$sp} $p;\n";
            }
        }
        elsif($type=~/(.*)(\[.*\])/){
            push @$dump_out, "$sp$1 $p$2;\n";
        }
        else{
            push @$dump_out, "$sp$type $p;\n";
        }
    }
}

sub inject_function {
    my ($name, $params, $source) = @_;
    my $t_code={'type'=>"fn", name=>$name, 'source'=>$source, params=>$params};
    $MyDef::def->{codes}->{$name}=$t_code;

    if(!$list_function_hash{$name}){
        $list_function_hash{$name}=1;
        push @list_function_list, $name;
    }
    else{
        $list_function_hash{$name}++;

    }
}

sub regex_char_condition {
    my ($c, $pat) = @_;
    my @tlist;
    if($pat=~/^\[(.*)\]$/){
        $pat = $1;
    }

    while(1){
        if($pat=~/\G$/gc){
            last;
        }
        elsif($pat=~/\G(\\[abtfnr])/gc){
            push @tlist, "$c=='$1'";
        }
        elsif($pat=~/\G\\(.)/gc){
            push @tlist, "$c=='$1'";
        }
        elsif($pat=~/\G(.)-(.)/gc){
            push @tlist, "($c>='$1'&&$c<='$2')";
        }
        elsif($pat=~/\G(.)/gc){
            if($1 eq "'"){
                push @tlist, "$c=='\\''";
            }
            else{
                push @tlist, "$c=='$1'";
            }
        }
        else{
            last;
        }
    }

    if(!@tlist){
        die "empty char regex $pat\n";
    }
    elsif(@tlist==1){
        return $tlist[0];
    }
    else{
        return '('.join(' || ', @tlist).')';

    }
}

sub regex_s_condition {
    my ($s, $pat, $option) = @_;
    my @or_list;
    my @and_list;
    my $i=0;
    while(1){
        if($pat=~/\G$/gc){
            last;
        }
        elsif($pat=~/\G(\[.*?\])/gc){
            push @and_list, regex_char_condition("${s}[$i]", $1);
            $i++;
        }
        elsif($pat=~/\G(\\.)/gc){
            push @and_list, regex_char_condition("${s}[$i]", $1);
            $i++;
        }
        elsif($pat=~/\G\|/gc){
            push @or_list, '('.join(' && ', @and_list).')';
            $i=0;
            @and_list=();
        }
        elsif($pat=~/\G(.)/gc){
            push @and_list, regex_char_condition("${s}[$i]", $1);
            $i++;
        }
    }
    if(@and_list){
        if(!@or_list){
            return join(' && ', @and_list);
        }
        push @or_list, '('.join(' && ', @and_list).')';
    }
    return join(' || ', @or_list);
}

sub allocate {
    my ($dim, $param2, $alloc_type) = @_;
    my $auto_free;
    if($alloc_type eq "auto"){
        $auto_free = 1;
    }
    my $post;
    if($auto_free){
        $post=MyDef::compileutil::get_named_block("_post");
    }
    add_include("stdlib, string");
    my $init_value;
    if($dim=~/(.*),\s*(.*)/){
        $dim=$1;
        $init_value=$2;
    }
    if($dim=~/[+-]/){
        $dim="($dim)";
    }
    if(defined $init_value and $init_value eq '0'){
        $alloc_type = "calloc";
        undef $init_value;
    }
    my @plist=split /,\s*/, $param2;
    foreach my $p (@plist){
        if($p){
            if($p=~/^(\w+)$/){
                my $var=find_var($p);
                if(!$var){
                    func_add_var($p);
                    $var=find_var($p);
                }
                if(!$var->{class}){
                    $var->{dimension}=$dim;
                }
                if($dim=~/\*/){
                    my @parts=split /\s*\*\s*/, $dim;
                    my $i=0;
                    foreach my $d (@parts){
                        $i++;
                        $var->{"dim$i"}=$d;
                    }
                    if($i==2 and !$var->{class}){
                        if($debug){
                            print "setting matrix class: $p\n";
                        }
                        $var->{"class"}="matrix";
                    }
                }
            }
            my $type=pointer_type(get_var_type($p));

            my $size="sizeof($type)";
            my $tsize = $size;
            if($type =~ /\bchar$/){
                $tsize=$dim;
            }
            elsif($dim ne "1"){
                $tsize = "$dim*$size";
            }

            if($alloc_type eq "realloc"){
                push @$out, "$p=($type*)realloc($p, $tsize);";
            }
            elsif($alloc_type eq "calloc"){
                push @$out, "$p=($type*)calloc($dim, $size);";
            }
            else{
                push @$out, "$p=($type*)malloc($tsize);";
            }

            if($auto_free){
                push @$post, "free($p);";
            }
            if(defined $init_value and $init_value ne ""){
                if($init_value eq "0"){
                    if($type eq "void"){
                        push @$out, "memset($p, 0, $dim);";
                    }
                    else{
                        push @$out, "memset($p, 0, $dim*sizeof($type));";
                    }
                }
                else{
                    push @$out, "for(int i=0;i<$dim;i++){";
                    push @$out, "    $p\[i]=$init_value;";
                    push @$out, "}";
                }
            }
        }
        else{
            my $curfile=MyDef::compileutil::curfile_curline();
            print "[$curfile]\x1b[33m allocate [empty]\n\x1b[0m";
        }
    }

}

sub check_expression {
    my ($l, $context) = @_;
    if($l=~/^return\b\s*(.*)/){
        if(length($1)<=0){
            return func_return();
        }
        else{
            my $t=check_expression($1);
            return func_return($t);
        }
    }
    elsif($l=~/^\s*(if|for|while|switch)\b/){
        return $l;
    }

    my ($assign, $left, $right);
    my %cache;
    my (@stack, @types);
    while(1){
        my ($token, $type);
        if($l=~/\G$/gc){
            last;
        }
        elsif($l=~/\G(L?"([^"\\]|\\.)*")/gc){
            $token=$1;
            $type="atom-string";
        }
        elsif($l=~/\G(L?'([^'\\]|\\.)*')/gc){
            $token=$1;
            $type="atom-char";
        }
        elsif($l=~/\G((\.\d+(?:[eE]-?\d+)?|\d+\.\d*(?:[eE]-?\d+)?|\d+(?:[eE]-?\d+))f?)/gc){
            $token=$1;
            $type="atom-number-float";
            if(@types>0 && $types[-1] =~/^atom/ and $token=~/^\.(\d+)/){
                $token=$1;
                my $primary=pop @stack;
                pop @types;
                $token="$primary.a$token";
                $type="atom-exp";
            }
        }
        elsif($l=~/\G(\d[0-9a-zA-Z]*)/gc){
            $token=$1;
            $type="atom-number";
            if(@stack>0 && $stack[-1] eq "^" and $token<10 and $token>1){
                pop @stack;
                pop @types;
                my $primary=pop @stack;
                pop @types;
                $token=$primary. (" * $primary" x ($token-1));
                $type="atom-exp";
            }
        }
        elsif($l=~/\G(\w+)/gc){
            $token=$1;
            $type="atom-identifier";
            if(@types>0 && $types[-1] =~/^op/ && ($stack[-1] eq "." or $stack[-1] eq "->")){
                if(@types>1 && $types[-2] !~/^atom/){
                    #error;
                }
                $token=join("", splice(@stack, -2)).$token;
                $type="atom-exp";
                splice(@types, -2);
            }
        }
        elsif($l=~/\G\$(\w+)/gc){
            my $method=$1;
            if($method=~/^(eq|ne|le|ge|lt|gt)$/i){
                $token=$1;
                $type="operator";
            }
            else{
                if($stack[-1] eq "." and $stack[-2]){
                    my $varname=$stack[-2];
                    my $arg=$';
                    if($l=~/\G\((.*)\)/gc){
                        $arg=$1;
                    }
                    my $var=find_var_x($varname);
                    my $call_line;
                    if(!$var){
                        if($class_names{$varname}){
                            $call_line = $varname."_".$method;
                        }
                        else{
                            my $curfile=MyDef::compileutil::curfile_curline();
                            print "[$curfile]\x1b[33m Variable $varname not found\n\x1b[0m";
                        }
                    }
                    elsif($var->{class}){
                        my $subname=$var->{class}."_".$method;
                        $call_line="$subname, $varname";
                    }

                    if($call_line){
                        $arg=~s/^,?\s+//;
                        if(length($arg)>0){
                            $call_line .= ", $arg";
                        }
                        undef $yield;
                        MyDef::compileutil::call_sub($call_line);
                        if($yield){
                            pop @stack;
                            pop @types;
                            pop @stack;
                            pop @types;
                            if(@stack or $left or $context eq "condition"){
                                push @stack, $yield;
                                push @types, "atom";
                            }
                            last;
                        }
                        else{
                            return;
                        }
                    }
                }

                elsif(@stack==1 and $method eq "call"){
                    my $call_line= $';
                    $call_line=~s/^\s*//;
                    undef $yield;
                    MyDef::compileutil::call_sub($call_line);
                    if($yield){
                        pop @stack;
                        pop @types;
                        pop @stack;
                        pop @types;
                        if(@stack or $left or $context eq "condition"){
                            push @stack, $yield;
                            push @types, "atom";
                        }
                        last;
                    }
                    else{
                        return;
                    }
                }

                my $curfile=MyDef::compileutil::curfile_curline();
                print "[$curfile]\x1b[33m Method $method not defined [$l]\n\x1b[0m";
                push @stack, "\$$method";
                push @types, "atom-unknown";
            }
        }
        elsif($l=~/\G([\(\[\{])/gc){
            push @stack, $1;
            push @types, $1;
            next;
        }
        elsif($l=~/\G([\)\]\}])/gc){
            my $close=$1;
            my $open;
            if($close eq ')'){
                $open='(';
            }
            if($close eq ']'){
                $open='[';
            }
            if($close eq '}'){
                $open='{';
            }

            my $n=@stack;
            my $i_open;
            for (my $i = $n-1; $i>=0; $i--) {
                if($stack[$i] eq $open){
                    $i_open=$i;
                    last;
                }
            }
            if(defined $i_open and $stack[$i_open] eq $open){
                my $exp=join("", splice(@stack, $i_open+1));
                pop @stack;
                splice(@types, $i_open);
                if(@types>0 && $types[-1] =~/^atom/ and $stack[-1]!~/^[0-9'"]/ and $stack[-1]=~/(\w+)$/){
                    my $identifier=$1;
                    my $primary=pop @stack;
                    pop @types;
                    my $processed;
                    $type="atom-exp";
                    if($open eq '('){
                        if($identifier=~/^(sin|cos|tan|asin|acos|atan|atan2|exp|log|log10|pow|sqrt|ceil|floor|fabs)$/){
                            add_include("math");
                            add_object("libm");
                        }
                        elsif($identifier=~/^(mem|str)[a-z]+$/){
                            add_include("string");
                        }
                        elsif($identifier=~/^(malloc|free)$/){
                            add_include("stdlib");
                        }
                        else{
                            if($function_autolist{$identifier}){
                                if(!$list_function_hash{$identifier}){
                                    $list_function_hash{$identifier}=1;
                                    push @list_function_list, $identifier;
                                }
                                else{
                                    $list_function_hash{$identifier}++;
                                }
                            }

                            my $F = $functions{$identifier};
                            if($F and $F->{prepend}){
                                if($exp eq ""){
                                    $exp=$F->{prepend};
                                }
                                else{
                                    $exp=$F->{prepend}.",".$exp;
                                }
                            }
                            elsif($F and $F->{append}){
                                if($exp eq ""){
                                    $exp=$F->{append};
                                }
                                else{
                                    $exp=$exp.",".$F->{append};
                                }
                            }
                        }
                    }
                    elsif($open eq '['){
                        if($exp=~/^-/){
                            my $var=find_var($identifier);
                            if($var and $var->{dimension}){
                                $token=$identifier.'['.$var->{dimension}."$exp".']';
                                $type="atom";
                                pop @stack;
                                pop @types;
                                pop @stack;
                                pop @types;
                                $processed=1;

                            }
                        }
                    }
                    elsif($open eq '{'){
                        $processed=1;
                        $token=$primary.$open.$exp.$close;
                        $cache{$token}=1;
                        if($debug){
                            print "add dict cache {$token}\n";
                        }
                    }
                    if(!$processed){
                        if($open eq '['){
                            $exp=~s/ +//g;
                        }
                        $token=$primary.$open.$exp.$close;
                    }
                }
                else{
                    if($exp=~/^(.+?)([*]+)$/){
                        $exp = "$1 $2";
                    }
                    $token=$open.$exp.$close;
                    $type="atom-$open";
                }
            }
            else{
                my $curfile=MyDef::compileutil::curfile_curline();
                print "[$curfile]\x1b[33m Error checking expression $l, unbalanced brackets\n\x1b[0m";
                print join(" -- ", @stack), "\n";
                $token=join("", @stack);
                $type="atom-broken";
            }

        }
        elsif($l=~/\G(\s+)/gc){
            next;
        }
        elsif($l=~/\G(=[~=]?)/gc){
            if($1 eq '=~'){
                if(@types>0 && $types[-1] =~/^atom/){
                    my $atom=pop @stack;
                    pop @types;
                    if($stack[-1] eq "*"){
                        pop @stack;
                        pop @types;
                        $atom = "*$atom";
                    }
                    my $func="regex";
                    my $pat;
                    if($l=~/\G\s*(\/(?:[^\/\\]|\\.)*\/\w*)/gc){
                        $pat=$1;
                    }
                    elsif($l=~/\G\s*(s\/(?:[^\/\\]|\\.)*\/(?:[^\/\\]|\\.)*\/\w*)/gc){
                        $pat=$1;
                    }
                    elsif($l=~/\G\s*(\[.*\])/gc){
                        $pat=$1;
                    }
                    else{
                        my $curfile=MyDef::compileutil::curfile_curline();
                        print "[$curfile]\x1b[33m =~ missing regex pattern\n\x1b[0m";
                    }
                    my $regex_plugin=$plugin_condition{regex};
                    if(!$regex_plugin){
                        my $curfile=MyDef::compileutil::curfile_curline();
                        print "[$curfile]\x1b[33m =~ missing regex plugin\n\x1b[0m";
                    }
                    my $param="$atom=~$pat";
                    my $condition;
                    my $codename=$regex_plugin;
                    my $t=MyDef::compileutil::eval_sub($codename);
                    eval $t;
                    if($@ and !$MyDef::compileutil::eval_sub_error{$codename}){
                        $MyDef::compileutil::eval_sub_error{$codename}=1;
                        print "evalsub - $codename\n";
                        print "[$t]\n";
                        print "eval error: [$@] package [", __PACKAGE__, "]\n";
                    }
                    $token=$condition;
                    $type="atom-regex";
                }
                else{
                    my $curfile=MyDef::compileutil::curfile_curline();
                    print "[$curfile]\x1b[33m =~ missing string variable\n\x1b[0m";
                }
            }
            else{
                $token="$1";
                $type="operator";
            }
        }
        elsif($l=~/\G([=+\-\*\/%\^\&\|><\?,\.!~:]+)/gc){
            $token=$1;
            $type="operator";
        }
        elsif($l=~/\G;/){
            return $l;
        }
        else{
            last;
        }
        check_exp_precedence:
        if(!@stack){
            push @stack, $token;
            push @types, $type;
        }
        elsif($type=~/^op/){
            if($token eq "++" or $token eq "--"){
                my $exp=pop @stack;
                pop @types;
                push @stack, "$exp$token";
                push @types, "atom-postfix";
            }
            elsif($token eq ":"){
                my $exp=pop @stack;
                pop @types;
                push @stack, "$exp$token ";
                push @types, "atom-label";
            }
            elsif($token=~/^(.*)=$/ and $1!~/^[!><=]$/){
                if($left and $assign ne '='){
                    die, "only simple chained assignment is supported";
                }
                if($left){
                    if($assign ne "=" || $token ne "="){
                    }
                    my $t;
                    $t = join("", @stack);
                    $left .= " = $t";
                }
                elsif($token eq '=' and @stack==1 and $types[0] eq "atom-("){
                    $left=substr($stack[0], 1, -1);
                }
                else{
                    $left = join("", @stack);
                }

                @stack=();
                @types=();
                $assign=$token;

                if($assign eq '='){
                    if(%cache){
                        foreach my $t (keys %cache){
                            if($debug){
                                print "check dict cache {$t}\n";
                            }
                            if($t=~/(\w+)\{(.*)\}/){
                                my ($t1, $t2)=($1, $2);
                                my $var=find_var_x($t1);
                                if($var and $var->{class}){
                                    my $call_line=$var->{class}."_lookup_left, $t1, $t2";
                                    undef $yield;
                                    MyDef::compileutil::call_sub($call_line);
                                    my $pos=-1;
                                    my $len=length $t;
                                    while(($pos=index($left, $t, $pos))>-1){
                                        substr($left, $pos, $len)=$yield;
                                    }
                                }
                            }
                        }
                    }
                }
            }
            else{
                push @stack, $token;
                push @types, $type;
            }
        }
        elsif($type=~/^atom/){
            if(@types>0 && $types[-1] =~/^op/){
                if(@types>1 && $types[-2] !~/^atom/ or ($stack[-1] eq '&' and $stack[-2]=~/\*\)$/)){
                    my $op=pop @stack;
                    pop @types;
                    $token=$op.$token;
                    $type="atom-unary";
                    goto check_exp_precedence;
                }
                else{
                    if($stack[-1] eq ","){
                        $stack[-1]="$stack[-1] ";
                    }
                    elsif($stack[-1]=~/^([<>])\.$/){
                        my $op=pop @stack;
                        pop @types;
                        my $exp=pop @stack;
                        pop @types;
                        $token = "$exp $1 $token? $exp : $token";
                    }
                    elsif($stack[-1]=~/^(eq|ne|lt|le|gt|ge)$/i){
                        add_include("<string.h>");
                        my $op=pop @stack;
                        pop @types;
                        my $exp=pop @stack;
                        pop @types;
                        my %str_op=(eq=>"==", ne=>"!=", lt=>"<", gt=>">", le=>"<=", ge=>">=");
                        my $sop=$str_op{lc($op)}.' 0';

                        my $n1;
                        if($exp=~/^"(.*)"/){
                            $n1 = length($1);
                        }
                        elsif($exp=~/^\w+$/){
                            my $var = find_var($exp);
                            if($var && $var->{strlen}){
                                $n1 = $var->{strlen};

                            }
                        }
                        my $n2;
                        if($token=~/^"(.*)"/){
                            $n2 = length($1);
                        }
                        elsif($token=~/^\w+$/){
                            my $var = find_var($token);
                            if($var && $var->{strlen}){
                                $n2 = $var->{strlen};

                            }
                        }

                        if(ord($op) < 91 or !($n1 || $n2)){
                            $token= "strcmp($exp, $token) $sop";
                        }
                        elsif($op=~/.[A-Z]$/ && $n2>0 && $exp=~/^\w+$/){
                            if(!$n1){
                                $n1 = "strlen($exp)";
                            }
                            $token = "$n1>=$n2 && strcmp($exp + $n1 - $n2, $token) $sop";
                        }
                        else{
                            if($n1 and $n2 and ($op eq "eq")){
                                $token= "$n1==$n2 && strncmp($exp, $token, $n2)==0";
                            }
                            else{
                                if(!$n2){
                                    $n2 = $n1;
                                }
                                $token= "strncmp($exp, $token, $n2) $sop";
                            }
                        }
                        $type = "atom";
                    }
                    elsif($stack[-1]=~/^\S+$/ && $stack[-1] ne "::"){
                        if(@stack>1 and $stack[-2]!~/^[\(\[\{]$/){
                            $stack[-1]=" $stack[-1] ";
                        }
                    }
                    push @stack, $token;
                    push @types, $type;
                }
            }
            elsif(@types>0 && $types[-1] =~/^atom/){
                if($stack[-1]=~/\w$/){
                    $stack[-1].=" $token";
                }
                else{
                    if(@types>0 && $types[-1] eq "atom-("){
                        $types[-1] = "atom";
                        $stack[-1].=" $token";
                    }
                    else{
                        $stack[-1].=$token;
                    }
                }
            }
            else{
                push @stack, $token;
                push @types, $type;
            }
        }
    }
    if(@stack==1 and $types[0] eq "atom-("){
        $right=substr($stack[0], 1, -1);
    }
    else{
        $right = join("", @stack);
    }

    if(%cache){
        foreach my $t (keys %cache){
            if($debug){
                print "check dict cache {$t}\n";
            }
            if($t=~/(\w+)\{(.*)\}/){
                my ($t1, $t2)=($1, $2);
                my $var=find_var_x($t1);
                if($var and $var->{class}){
                    my $call_line=$var->{class}."_lookup, $t1, $t2";
                    undef $yield;
                    MyDef::compileutil::call_sub($call_line);
                    my $pos=-1;
                    my $len=length $t;
                    while(($pos=index($right, $t, $pos))>-1){
                        substr($right, $pos, $len)=$yield;
                    }
                }
            }
        }
    }
    if($assign){
        if($assign eq "="){
            if($context && $context eq "condition"){
                if($right!~/^\w+\(.*\)$/){
                    my $curfile=MyDef::compileutil::curfile_curline();
                    print "[$curfile]\x1b[33m Assignment in [$left = $right], possible bug?\n\x1b[0m";
                }
                return "$left = $right";
            }
            else{
                do_assignment($left, $right);
                return;
            }
        }
        elsif($assign eq ":="){
            if($context eq "condition"){
                return "($left = $right)";
            }
            else{
                return "$left = $right";
            }
        }
        else{
            if($assign =~/^([<>])\.=$/){
                return "if($right $1 $left){$left = $right;}";
            }
            $right= "$left $assign $right";
        }
    }
    return $right;
}

sub debug_dump {
    my ($param, $prefix, $out) = @_;
    my %colors=(red=>31,green=>32,yellow=>33,blue=>34,magenta=>35,cyan=>36);
    my @vlist=split /,\s*/, $param;
    my @a1;
    my @a2;
    foreach my $v (@vlist){
        if($v=~/^(%.*):(.*)/){
            push @a2, $2;
            push @a1, "$2=$1";
        }
        elsif($v=~/^(\w+):(.*)/){
            my ($color,$v)=($1,$2);
            push @a2, $v;
            push @a1, "\\x1b[$colors{$color}m" . "$v=".get_var_fmt($v, 1) . "\\x1b[0m";
        }
        else{
            my $fmt=get_var_fmt($v);
            if(!defined $fmt){
                push @a1, $v;
            }
            else{
                push @a2, $v;
                push @a1, "$v=".get_var_fmt($v, 1);
            }
        }
    }
    my $s_a1 = join(", ", @a1);
    my $s_a2 = join(", ", @a2);
    if($prefix){
        if($prefix=~/^(red|green|yellow|blue|magenta|cyan)$/){
            $s_a1 = "\\x1b[$colors{$1}m$s_a1\\x1b[0m";
        }
        else{
            $s_a1 = "[$prefix] $s_a1";
        }
    }
    push @$out, "fprintf(stdout, \"    :$s_a1\\n\", $s_a2);";
    add_include("stdio");
}

sub do_assignment {
    my ($left, $right) = @_;
    if(!defined $right){
        my $type=get_var_type($left);
        if($type and $type ne "void"){
            $right=type_default($type);
            push @$out, "$left = $right;";
            return;
        }
        return;
    }
    if(!defined $left or $left eq "_"){
        return;
    }

    if($debug eq "type"){
        print "\x1b[36m do_assignment: $left = $right\n\x1b[0m";
    }

    my @left_list = split /\s+=\s+/, $left;
    if(@left_list>1){
        foreach my $var (@left_list){
            if($var=~/^\w+$/){
                auto_add_var($var, undef, $right);
            }
        }
        push @$out, "$left = $right;";
        return;
    }
    my @left_list=MyDef::utils::proper_split($left);
    my @right_list=MyDef::utils::proper_split($right);
    if($debug eq "type"){
        printf "check_tuple_assignment: left $left:%d, right $right:%d\n", $#left_list+1, $#right_list+1;
    }
    if(@left_list>1 or @right_list>1){
        if(@left_list==1){
            my $type=get_var_type($left);
            if($type=~/^struct (\w+)$/){
                my $s_list=$structs{$1}->{list};
                my $i=0;
                foreach my $p (@$s_list){
                    if($right_list[$i] ne "-"){
                        do_assignment("$left.$p", $right_list[$i]);
                    }
                    $i++;
                    if(!defined $right_list[$i]){
                        last;
                    }
                }
            }
            elsif($type=~/^struct (\w+)\s*\*$/){
                my $s_list=$structs{$1}->{list};
                my $i=0;
                foreach my $p (@$s_list){
                    if($right_list[$i] ne "-"){
                        do_assignment("$left->$p", $right_list[$i]);
                    }
                    $i++;
                    if(!defined $right_list[$i]){
                        last;
                    }
                }
            }
            elsif($type=~/^(.*?)\s*\*$/){
                for (my $i = 0; $i<@right_list; $i++) {
                    do_assignment("$left\[$i\]", $right_list[$i]);
                }
            }
            else{
                my $curfile=MyDef::compileutil::curfile_curline();
                print "[$curfile]\x1b[33m tuple assigned to scalar\n\x1b[0m";
                do_assignment($left, $right_list[0]);
            }
        }
        elsif(@right_list==1){
            if($right=~/^(\w+)\((.*)\)/){
                my ($f, $p)=($1, $2);
                foreach my $t (@left_list){
                    $p.=", \&$t";
                }
                push @$out, "$f($p);";
            }
            else{
                my $type=get_var_type($right);
                if($type=~/^struct (\w+)$/){
                    if(!$structs{$1}){
                        my $curfile=MyDef::compileutil::curfile_curline();
                        print "[$curfile]\x1b[33m structure $1 not defined yet\n\x1b[0m";
                    }
                    else{
                        my $s_list=$structs{$1}->{list};
                        my $i=0;
                        foreach my $p (@$s_list){
                            if($left_list[$i] ne "-"){
                                do_assignment($left_list[$i], "$right.$p");
                            }
                            $i++;
                        }
                    }
                }
                elsif($type=~/^struct (\w+)\s*\*$/){
                    if(!$structs{$1}){
                        my $curfile=MyDef::compileutil::curfile_curline();
                        print "[$curfile]\x1b[33m structure $1 not defined yet\n\x1b[0m";
                    }
                    else{
                        my $s_list=$structs{$1}->{list};
                        my $i=0;
                        foreach my $p (@$s_list){
                            if($left_list[$i] ne "-"){
                                do_assignment($left_list[$i], "$right->$p");
                            }
                            $i++;
                        }
                    }
                }
                elsif($type=~/^(.*?)\s*\*$/){
                    for (my $i = 0; $i<@right_list; $i++) {
                        do_assignment($left_list[$i], "$right\[$i\]");
                    }
                }
                else{
                    my $curfile=MyDef::compileutil::curfile_curline();
                    print "[$curfile]\x1b[33m scalar assigned to tuple\n\x1b[0m";
                    for (my $i = 0; $i<@right_list; $i++) {
                        do_assignment($left_list[$i], $right);
                    }
                }
            }
        }
        else{
            for (my $i = 0; $i<@left_list; $i++) {
                do_assignment($left_list[$i], $right_list[$i]);
            }
        }
        return;
    }


    my $type;
    if($left=~/^(\w.*)\s+(\w+)$/){
        $type=$1;
        $left=$2;
    }

    if($left=~/^(\w+)/){
        if($protected_var{$1}){
            my $curfile=MyDef::compileutil::curfile_curline();
            print "[$curfile]\x1b[33m Variable $1 protected (unmutable)\n\x1b[0m";
        }
        auto_add_var($left, $type, $right);
    }
    else{
    }

    push @$out, "$left = $right;";
    return;

}

sub auto_add_var {
    my ($name, $type, $value) = @_;
    my $var;
    if($name=~/^(\w+)$/){
        $var=find_var($1);
        if(!$var){
            if($debug eq "type"){
                my $curfile=MyDef::compileutil::curfile_curline();
                print "[$curfile]\x1b[33m auto_add_var: $name - $type - $value\n\x1b[0m";
            }
            func_add_var($name, $type, $value);
        }
    }
    else{
        return;

    }
}

sub translate_regex {
    my ($re, $option, $tail) = @_;
    my $pat="/$re/$option";
    if($re_hash{$pat}){
        return $re_hash{$pat};
    }
    $re_index++;
    my $name="match_re_$re_index";

    if($tail=~/->\s*(\w+)/){
        $name = "match_$1";
    }
    $re_hash{$pat}="$name(input)";
    my $opt={group_idx=>0};
    my $r=MyDef::utils::parse_regex($re);
    if($debug){
        print "translate_regex: [$re]\n";
        MyDef::utils::debug_regex($r);
    }
    if($option=~/i/){
        $opt->{i}=1;
    }
    if($option=~/s/){
        $opt->{s}=1;
    }
    if($option=~/m/){
        $opt->{m}=1;
    }
    my @output;
    my $t_code={'type'=>"fn", 'source'=>\@output};
    $t_code->{params}=["input"];
    $t_code->{name}=$name;
    $page->{codes}->{$name}=$t_code;
    if(!$list_function_hash{$name}){
        $list_function_hash{$name}=1;
        push @list_function_list, $name;
    }
    else{
        $list_function_hash{$name}++;
    }

    push @output, "\$: // $pat ";
    push @$out, "// $pat";
    push @output, "\$return_type bool";
    if($r->{has_Any}>0){
        if($r->{has_Any}>1){
            die "Lex Regex: too many '.*'\n";
        }
        else{
            if($r->{type}=~/^(group|seq)/){
                my $rlist=$r->{list};
                my $n=$r->{n};
                my $i=0;
                while($i<$n){
                    my $t=$rlist->[$i];
                    if($t->{type} eq "Any" or $t->{type} eq "group" && $t->{n}==1 && $t->{list}->[0]->{type} eq "Any"){
                        last;
                    }
                    $i++;
                }
                my ($pre, $any, $post);
                if($i==1){
                    $pre=$rlist->[0];
                }
                elsif($i>1){
                    my @t1=@$rlist[0..($i-1)];
                    $pre={type=>"seq", n=>$i, list=>\@t1};
                }
                if($rlist->[$i]->{type} eq "group"){
                    $any=$rlist->[$i]->{list}->[0];
                    $any->{capture}=1;
                }
                else{
                    $any=$rlist->[$i];
                }
                if($n-($i+1)==1){
                    $post=$rlist->[$i+1];
                }
                elsif($n-($i+1)>1){
                    my @t1=@$rlist[($i+1)..($n-1)];
                    $post={type=>"seq", n=>($n-$i-1), list=>\@t1};
                }
                if(!$post){
                    die "Lex Regex: trailing .* not supported\n";
                }

                my ($sub_pre, $sub_post);
                my $gid0;
                if($r->{type} eq "group"){
                    $opt->{group_idx}++;
                    $gid0=$opt->{group_idx};
                }
                push @output, "\$if level==0";
                push @output, "SOURCE_INDENT";
                push @output, "input->s[0]=input->n_pos";
                if($gid0>0){
                    push @output, "input->s[$gid0]=input->n_pos";
                }
                push @output, "SOURCE_DEDENT";
                if($pre){
                    $pre->{0}="return false";
                    $pre->{1}="";
                    $sub_pre=translate_regex_atom($pre, $opt, 1);
                }

                my $gid;
                if($any->{capture}){
                    $opt->{group_idx}++;
                    $gid=$opt->{group_idx};
                }
                if($post){
                    $post->{0}="";
                    $post->{1}="return true";
                    my $r = "input->e[0]=input->n_pos;";
                    if($gid0>0){
                        $r.="input->e[$gid0]=input->n_pos;";
                    }
                    $post->{1}="if(level==0){$r} return true;";
                    $sub_post=translate_regex_atom($post, $opt, 1);
                }

                $re_hash{$pat}="$name(input, 0)";
                push @{$t_code->{params}}, "int level";
                push @output, "tn_pos_0 = input->n_pos";
                if(!$pre){
                    if($gid>0){
                        push @output, "\$if level==0";
                        push @output, "SOURCE_INDENT";
                        push @output, "input->s[$gid]=input->n_pos";
                        push @output, "SOURCE_DEDENT";
                    }
                    push @output, "\$while 1";
                    push @output, "SOURCE_INDENT";
                    if($gid>0){
                        push @output, "\$if level==0";
                        push @output, "SOURCE_INDENT";
                        push @output, "input->e[$gid]=input->n_pos";
                        push @output, "SOURCE_DEDENT";
                    }
                    push @output, @$sub_post;
                    push @output, "\$call input_get_c, tn_c";
                    push @output, "\$if tn_c==0";
                    push @output, "SOURCE_INDENT";
                    push @output, "input->n_pos=tn_pos_0";
                    push @output, "return false";
                    push @output, "SOURCE_DEDENT";
                    push @output, "SOURCE_DEDENT";
                    push @output, "return false";
                }
                else{
                    push @output, @$sub_pre;
                    if($gid>0){
                        push @output, "\$if level==0";
                        push @output, "SOURCE_INDENT";
                        push @output, "input->s[$gid]=input->n_pos";
                        push @output, "SOURCE_DEDENT";
                    }
                    push @output, "\$while 1";
                    push @output, "SOURCE_INDENT";
                    if($gid>0){
                        push @output, "\$if level==0";
                        push @output, "SOURCE_INDENT";
                        push @output, "input->e[$gid]=input->n_pos";
                        push @output, "SOURCE_DEDENT";
                    }
                    push @output, @$sub_post;
                    push @output, "\$if !$name(input, level+1)";
                    push @output, "SOURCE_INDENT";
                    push @output, "\$call input_get_c, tn_c";
                    push @output, "\$if tn_c==0";
                    push @output, "SOURCE_INDENT";
                    push @output, "input->n_pos=tn_pos_0";
                    push @output, "return false";
                    push @output, "SOURCE_DEDENT";
                    push @output, "SOURCE_DEDENT";
                    push @output, "SOURCE_DEDENT";
                    push @output, "return false";
                }

            }
            else{
                die "Lex Regex .* not supported\n";
            }
        }
    }
    else{
        $r->{0}="return false;";
        $r->{1}="return true;";
        $r->{1}="input->e[0]=input->n_pos;return true;";
        my $subout=translate_regex_atom($r, $opt, 1);
        push @output, "input->s[0]=input->n_pos";
        push @output, @$subout;
    }
    return $re_hash{$pat};

}

sub translate_regex_atom {
    my ($r, $opt, $level) = @_;
    my ($condition, @output);
    my $v_res="tb_res_$level";
    my $v_pos="tn_pos_$level";
    if($r->{type} =~/^(group|seq|alt|\?!|\?=)/){
        my $gid;
        if($r->{type} eq "group"){
            $opt->{group_idx}++;
            $gid=$opt->{group_idx};
        }
        push @output, "\$do";
        push @output, "SOURCE_INDENT";
        if($gid and $gid<10){
            push @output, "input->s[$gid]=input->n_pos";
        }
        push @output, "$v_pos = input->n_pos";
        push @output, "$v_res = false";
        foreach my $t (@{$r->{list}}){
            if($r->{type} eq "alt"){
                $t->{1}="break;";
                $t->{0}="";
            }
            else{
                $t->{1}="";
                $t->{0}="break;";
            }
            my $subout=translate_regex_atom($t, $opt, $level+1);
            push @output, @$subout;
        }
        if($gid and $gid<10){
            push @output, "input->e[$gid]=input->n_pos";
        }
        push @output, "$v_res = true";
        push @output, "SOURCE_DEDENT";
        if($r->{type} eq "alt"){
            if($r->{1}){
                push @output, "if(!$v_res){";
                push @output, "    $r->{1}";
                push @output, "}";
                push @output, "else{";
            }
            else{
                push @output, "if($v_res){";
            }
            push @output, "INDENT";
            push @output, "NOOP";
            if($r->{0}){
                push @output, "$r->{0}";
            }
            push @output, "DEDENT";
            push @output, "}";
        }
        elsif($r->{type} eq "?="){
            push @output, "input->n_pos = $v_pos";
            if($r->{1}){
                push @output, "if($v_res){";
                push @output, "    $r->{1}";
                push @output, "}";
                push @output, "else{";
            }
            else{
                push @output, "if(!$v_res){";
            }
            push @output, "INDENT";
            push @output, "NOOP";
            if($r->{0}){
                push @output, "$r->{0}";
            }
            push @output, "DEDENT";
            push @output, "}";
        }
        elsif($r->{type} eq "?!"){
            push @output, "input->n_pos = $v_pos";
            if($r->{1}){
                push @output, "if(!$v_res){";
                push @output, "    $r->{1}";
                push @output, "}";
                push @output, "else{";
            }
            else{
                push @output, "if($v_res){";
            }
            push @output, "INDENT";
            push @output, "NOOP";
            if($r->{0}){
                push @output, "$r->{0}";
            }
            push @output, "DEDENT";
            push @output, "}";
        }
        else{
            if($r->{1}){
                push @output, "if($v_res){";
                push @output, "    $r->{1}";
                push @output, "}";
                push @output, "else{";
            }
            else{
                push @output, "if(!$v_res){";
            }
            push @output, "INDENT";
            push @output, "input->n_pos = $v_pos";
            if($r->{0}){
                push @output, "$r->{0}";
            }
            push @output, "DEDENT";
            push @output, "}";
        }
    }

    elsif($r->{type} eq "*"){
        my $t=$r->{atom};
        $t->{1}="";
        $t->{0}="break;";
        my $subout=translate_regex_atom($t, $opt, $level+1);
        push @output, "\$while 1";
        push @output, "SOURCE_INDENT";
        push @output, @$subout;
        push @output, "SOURCE_DEDENT";
        if($r->{1}){
            push @output, $r->{1};
        }
    }

    elsif($r->{type} eq "?"){
        my $t=$r->{atom};
        $t->{1}=$r->{1};
        $t->{0}="";
        my $subout=translate_regex_atom($t, $opt, $level+1);
        push @output, @$subout;
        if($r->{1}){
            push @output, "    ".$r->{1};
        }
    }

    elsif($r->{type} eq "+"){
        my $t=$r->{atom};
        my $v_cnt="tn_cnt_$level";
        $t->{1}="$v_cnt++;";
        $t->{0}="break;";
        my $subout=translate_regex_atom($t, $opt, $level+1);
        push @output, "\$my $v_cnt=0;";
        push @output, "\$while 1";
        push @output, "SOURCE_INDENT";
        push @output, @$subout;
        push @output, "SOURCE_DEDENT";
        if($r->{0} or $r->{1}){
            push @output, "if($v_cnt>0){$r->{1}}else{$r->{0}}";
        }
    }
    else{
        push @output, "\$call input_get_c, tn_c";
        my $cond;

        if($r->{type} eq "AnyChar"){
            if($opt->{s}){
                $cond = "tn_c>0";
            }
            else{
                $cond = "tn_c>0 && tn_c!='\\n'";
            }
        }
        elsif($r->{type} eq "class"){
            if($r->{list}){
                if($opt->{i}){
                    push @output, "tn_c = toupper(tn_c)";
                    foreach my $c (@{$r->{list}}){
                        $c=uc($c);
                    }
                }
                $cond=translate_class($r->{list});
            }
            elsif($r->{char} eq "s"){
                $cond="isspace(tn_c)";
            }
            elsif($r->{char} eq "S"){
                $cond="!isspace(tn_c)";
            }
            elsif($r->{char} eq "d"){
                $cond="isdigit(tn_c)";
            }
            elsif($r->{char} eq "D"){
                $cond="!isdigit(tn_c)";
            }
            elsif($r->{char} eq "w"){
                $cond="isalnum(tn_c) || tn_c=='_'";
            }
            elsif($r->{char} eq "W"){
                $cond="!isalnum(tn_c) && tn_c!='_'";
            }
        }
        else{
            if($opt->{i} and $r->{char} ne uc($r->{char})){
                push @output, "tn_c = toupper(tn_c)";
                $r->{char}=uc($r->{char});
            }
            if($r->{char} eq "\\"){
                $cond= "tn_c=='\\\\'";
            }
            else{
                $cond= "tn_c=='$r->{char}'";
            }
        }

        if($r->{1}){
            push @output, "if($cond){";
            push @output, "    $r->{1}";
            push @output, "}";
            push @output, "else{";
        }
        else{
            push @output, "if(!($cond)){";
        }
        push @output, "INDENT";
        push @output, "\$call input_back_c";
        if($r->{0}){
            push @output, "$r->{0}";
        }
        push @output, "DEDENT";
        push @output, "}";
    }

    return \@output;
}

sub translate_class {
    my ($r) = @_;
    my @tlist;
    my $negate;
    if($r->[0] eq '^'){
        $negate=shift @$r;
    }

    foreach my $c (@$r){
        if($c=~/(\w+)-(\w+)/){
            push @tlist, "(tn_c>='$1' && tn_c<='$2')";
        }
        elsif($c eq "\\s"){
            push @tlist, "isspace(tn_c)";
        }
        elsif($c eq "\\S"){
            push @tlist, "!isspace(tn_c)";
        }
        elsif($c eq "\\d"){
            push @tlist, "isdigit(tn_c)";
        }
        elsif($c eq "\\D"){
            push @tlist, "!isdigit(tn_c)";
        }
        elsif($c eq "\\w"){
            push @tlist, "(isalnum(tn_c) || tn_c=='_')";
        }
        elsif($c eq "\\W"){
            push @tlist, "(!isalnum(tn_c) && tn_c!='_')";
        }
        else{
            push @tlist, "tn_c=='$c'";
        }
    }

    if(@tlist==1 and $tlist[0]=~/^\((.*)\)$/){
        $tlist[0]=$1;
    }

    if($negate){
        return "!(". join(' || ', @tlist). ")";
    }
    else{
        return join(' || ', @tlist);
    }
}

sub sumcode_generate {
    my ($h) = @_;
    my $left = $h->{left};
    my $right = $h->{right};
    my $left_idx = $h->{left_idx};
    my $right_idx = $h->{right_idx};
    my $klist = $h->{klist};

    my @code;
    my %loop_i_hash;
    if($debug){
        print "left indexs: ", join(", ", @$left_idx), "\n";
        print "right indexs: ", join(", ", @$right_idx), "\n";
    }

    foreach my $i (@$left_idx){
        $loop_i_hash{$i}=1;
        my $dim=$h->{"$i-dim"};
        my $var=$h->{"$i-var"};
        push @code, "\$for $var=0:$dim";
        push @code, "SOURCE_INDENT";
    }
    if(@$right_idx){
        push @code, "$left = 0";
        foreach my $i (@$right_idx){
            $loop_i_hash{$i}=1;
            my $dim=$h->{"$i-dim"};
            my $var=$h->{"$i-var"};
            push @code, "\$for $var=0:$dim";
            push @code, "SOURCE_INDENT";
        }
        push @code, "$left += $right";
        foreach my $i (reverse @$right_idx){
            push @code, "SOURCE_DEDENT";
        }
    }
    elsif(defined $right){
        push @code, "$left = $right";
    }
    else{
        push @code, $left;
    }
    foreach my $i (reverse @$left_idx){
        push @code, "SOURCE_DEDENT";
    }
    return \@code;
}

sub fmt_string {
    my ($str, $add_newline) = @_;
    if(!$str){
        if($add_newline){
            return (0, '"\n"');
        }
        else{
            return (0, '""');
        }
    }
    $str=~s/\s*$//;
    my @pre_list;
    if($str=~/^\s*\"(.*)\"\s*,\s*(.*)$/){
        $str=$1;
        @pre_list=MyDef::utils::proper_split($2);
        foreach my $a (@pre_list){
            $a=check_expression($a);
        }
    }
    elsif($str=~/^\s*\"(.*)\"\s*$/){
        $str=$1;
    }

    if($add_newline and $str=~/(.*)-$/){
        $add_newline=0;
        $str=$1;
    }

    my %colors=(red=>31,green=>32,yellow=>33,blue=>34,magenta=>35,cyan=>36);

    my @fmt_list;
    my @arg_list;
    my $missing = 0;
    my @group;
    my $flag_hyphen=0;
    while(1){
        if($str=~/\G$/sgc){
            last;
        }
        elsif($str=~/\G%/sgc){
            if($str=~/\G%/sgc){
                push @fmt_list, '%%';
            }
            elsif($str=~/\G[-+ #]*[0-9]*(\.\d+)?[hlLzjt]*[diufFeEgGxXoscpaAn]/sgc){
                if(!@pre_list){
                    $missing++;
                }
                push @arg_list, shift @pre_list;
                push @fmt_list, "%$&";
            }
            else{
                push @fmt_list, '%%';
            }
        }
        elsif($str=~/\G\$/sgc){
            if($str=~/\G(red|green|yellow|blue|magenta|cyan)/sgc){
                push @fmt_list, "\\x1b[$colors{$1}m";
                if($str=~/\G\{/sgc){
                    push @group, $1;
                }
            }
            elsif($str=~/\Greset/sgc){
                push @fmt_list, "\\x1b[0m";
            }
            elsif($str=~/\Gclear/sgc){
                push @fmt_list, "\\x1b[H\\x1b[J";
            }
            elsif($str=~/\G(\w+)/sgc){
                my $v=$1;
                if($str=~/\G(\[.*?\])/sgc){
                    $v.=$1;
                }
                elsif($str=~/\G(\{.*?\})/sgc){
                    $v.=$1;
                    $v=check_expression($v);
                }
                my $var=find_var($v);
                if($var->{direct}){
                    push @fmt_list, $var->{direct};
                }
                elsif($var->{strlen}){
                    push @fmt_list, "%.*s";
                    push @arg_list, $var->{strlen};
                    push @arg_list, $v;
                }
                else{
                    my @t=get_var_fmt($v, 1);
                    push @fmt_list, shift @t;
                    if(@t){
                        push @arg_list, @t;
                    }
                    else{
                        push @arg_list, $v;
                    }
                }
                if($str=~/\G-/sgc){
                }
            }
            elsif($str=~/\G\{(.*?)\}/sgc){
                my $v=$1;
                my $var=find_var($v);
                if($var->{direct}){
                    push @fmt_list, $var->{direct};
                }
                elsif($var->{strlen}){
                    push @fmt_list, "%.*s";
                    push @arg_list, $var->{strlen};
                    push @arg_list, $v;
                }
                else{
                    my @t=get_var_fmt($v, 1);
                    push @fmt_list, shift @t;
                    if(@t){
                        push @arg_list, @t;
                    }
                    else{
                        push @arg_list, $v;
                    }
                }
            }
            else{
                push @fmt_list, '$';
            }
        }
        elsif($str=~/\G\\\$/sgc){
            push @fmt_list, '$';
        }
        elsif($str=~/\G\}/sgc){
            if(@group){
                pop @group;
                if(!@group){
                    push @fmt_list, "\\x1b[0m";
                }
                else{
                    my $c=$group[-1];
                    push @fmt_list, "\\x1b[$colors{$c}m";
                }
            }
            else{
                push @fmt_list, '}';
            }
        }
        elsif($str=~/\G[^%\$\}]+/sgc){
            push @fmt_list, $&;
        }
        else{
            die "parse_loop: nothing matches! [$str]\n";
        }
    }

    if(@pre_list){
        my $s = join(', ', @pre_list);
        my $curfile=MyDef::compileutil::curfile_curline();
        print "[$curfile]\x1b[33m Extra fmt arg list: $s\n\x1b[0m";
    }
    elsif($missing>0){
        my $curfile=MyDef::compileutil::curfile_curline();
        print "[$curfile]\x1b[33m Missing $missing fmt arguments\n\x1b[0m";
    }

    if($add_newline){
        my $tail=$fmt_list[-1];
        if($tail=~/(.*)-$/){
            $fmt_list[-1]=$1;
        }
        elsif($tail!~/\\n$/){
            push @fmt_list, "\\n";
        }
    }

    if(!@arg_list){
        return (0, '"'.join('',@fmt_list).'"');
    }
    else{
        my $vcnt=@arg_list;
        my $f = join('', @fmt_list);
        my $a = join(', ', @arg_list);
        return ($vcnt, "\"$f\", $a");
    }

}

1;
