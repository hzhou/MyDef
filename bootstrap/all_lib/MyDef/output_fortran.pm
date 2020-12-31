use strict;
package MyDef::output_fortran;

our @function_stack;
our %list_function_hash;
our @list_function_list;
our @scope_stack;
our $cur_scope;
our %type_name;
our %type_prefix;
our $debug=0;
our $out;
our $mode;
our $page;
our $global_hash;
our $global_list;
our $main_func;
our %functions;
our $cur_function;
our @function_list;
our $label_index;
our $default_float = "REAL";
our %function_autolist;
our $in_template;
our $case_if="IF";
our $case_elif="ELSEIF";
our @case_stack;
our $case_state;
our %plugin_statement;
our %plugin_condition;
our %objects;
our %op=("=="=>"EQ","<="=>"LE",">="=>"GE","<"=>"LT",">"=>"GT","/="=>"NE","!="=>"NE","&&"=>"AND", "||"=>"OR");
our $custom_split_var_line;
our %protected_var;
$cur_scope={var_list=>[], var_hash=>{}, name=>"default"};
%type_name=(
    c=>"CHARACTER",
    d=>"DOUBLE PRECISION",
    f=>"REAL",
    i=>"INTEGER",
    j=>"INTEGER",
    k=>"INTEGER",
    l=>"INTEGER",
    m=>"INTEGER",
    n=>"INTEGER",
    count=>"INTEGER",
    size=>"INTEGER",
);
%type_prefix=(
    i=>"INTEGER",
    n=>"INTEGER",
    n1=>"INTEGER(kind=1)",
    n2=>"INTEGER(kind=2)",
    n4=>"INTEGER(kind=4)",
    n8=>"INTEGER(kind=8)",
    n16=>"INTEGER(kind=16)",
    b=>"LOGICAL",
    s=>"CHARACTER",
    f=>"REAL",
    d=>"DOUBLE PRECISION",
    c=>"COMPLEX",
    z=>"DOUBLE COMPLEX",
    "has"=>"LOGICAL",
    "is"=>"LOGICAL",
    "do"=>"LOGICAL",
);

sub get_interface {
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout);
}

sub init_page {
    my ($t_page)=@_;
    $page=$t_page;
    MyDef::set_page_extension("f");
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
    $label_index=0;
    if($MyDef::def->{macros}->{use_double} or $page->{use_double}){
        $default_float="DOUBLE PRECISION";
    }
    $type_prefix{f}=$default_float;
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
            }

            if($func->{autolist} eq "skip"){
                $function_autolist{$name}="add";
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
                $function_autolist{$name}="add";
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
    if($mode eq "template"){
        if(!$in_template){
            $in_template=1;
            push @$out, "TEMPLATE START";
        }
    }
    else{
        if($in_template){
            $in_template=0;
            push @$out, "TEMPLATE STOP";
        }
    }
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
        my @src;
        if($case eq $case_if){
            push @src, "IF ($cond) THEN";
            push @src, "INDENT";
            push @src, "BLOCK";
            push @src, "DEDENT";
            push @src, "END IF";
        }
        else{
            if($out->[-1] ne "END IF"){
                my $curfile=MyDef::compileutil::curfile_curline();
                print "[$curfile]\x1b[33m case: else missing END IF - [$out->[-1]]\n\x1b[0m";
            }
            pop @$out;
            push @src, "ELSE IF ($cond) THEN";
            push @src, "INDENT";
            push @src, "BLOCK";
            push @src, "DEDENT";
            push @src, "END IF";
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
        if($out->[-1] ne "END IF"){
            my $curfile=MyDef::compileutil::curfile_curline();
            print "[$curfile]\x1b[33m case: else missing END IF - [$out->[-1]]\n\x1b[0m";
        }
        pop @$out;
        push @src, "ELSE";
        push @src, "INDENT";
        push @src, "BLOCK";
        push @src, "DEDENT";
        push @src, "END IF";
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
    elsif($l=~/^NOOP POST_MAIN/){
        if($out->[0] !~ /^TEMPLATE/){
            unshift @$out, "PROGRAM $page->{_pagename}", "DUMP_STUB global_init";
            push @$out, "END";
        }
        push @$out, "NEWLINE";
        while(my $f=shift @list_function_list){
            push @$out, "NEWLINE";
            if($MyDef::compileutil::named_blocks{"lambda-$f"}){
                push @$out, "DUMP_STUB lambda-$f";
            }
            else{
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
    elsif($l=~/^SUBBLOCK BEGIN (\d+) (.*)/){
        open_scope($1, $2);
        return;
    }
    elsif($l=~/^SUBBLOCK END (\d+) (.*)/){
        close_scope();
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
        elsif($func=~/^(global|local)$/){
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
        elsif($func eq "print"){
            fortran_write($param1, $param2, 1);
            return;
        }
        elsif($func eq "dump"){
            my $t = dump_param($param2);
            fortran_write(undef, "'[$param1] ',".$t);
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
            if($func eq "uselib"){
                my @tlist = split /,\s*/, $param;
                foreach my $f (@tlist){
                    if($f=~/^\w+$/){
                        $objects{"lib$f"}=1;
                    }
                    else{
                        $objects{$f}=1;
                    }
                }
                return;
            }
            elsif($func eq "getlabel"){
                my $s = get_label();
                if(!$param){
                    $param="label";
                }
                MyDef::compileutil::set_current_macro($param, $s);
                return;
            }
            elsif($func eq "loop"){
                return single_block("DO", "END DO");
            }
            elsif($func eq "while"){
                if(!$param or $param eq "1"){
                    return single_block("DO", "END DO");
                }
                else{
                    $param=~s/(&&|\|\||!=)/.$op{$1}./g;
                    return single_block("DO WHILE ($param)", "END DO");
                }
            }
            elsif($func eq "for"){
                if($param =~/(\w+)\s*=\s*(.*)/){
                    my ($v, $t) = ($1, $2);
                    func_add_var($v, "INTEGER");
                    if($t=~/^\s*0\b/){
                        my $curfile=MyDef::compileutil::curfile_curline();
                        print "[$curfile]\x1b[33m for loop start at 0? (FORTRAN often start at 1)\n\x1b[0m";
                    }
                    if($t=~/^\d+$/){
                        $t="1, $t";
                    }
                    else{
                        $t =~ s/:/, /g;
                    }
                    $param = "$v = $t";
                }
                return single_block("DO $param", "END DO");
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
            elsif($func=~/^(global|local)$/){
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
            elsif($func =~/^(return_type|return|result|recursive|parameter|lexical)$/){
                if($1 eq "return" or $1 eq "result"){
                    my $var = parse_var($param);
                    $cur_function->{ret_var}= $var;
                    $cur_function->{ret_type}=$var->{type};
                }
                elsif($1 eq "recursive"){
                    $cur_function->{recursive}=1;
                }
                elsif($1 eq "return_type"){
                    $cur_function->{ret_type}=$param;
                }
                elsif($1 eq "parameter"){
                    my $param_list=$cur_function->{param_list};
                    my $var_hash=$cur_function->{var_hash};
                    my @plist=split_var_line($param);
                    my $i = -1;
                    foreach my $p (@plist){
                        $i++;
                        my $var=parse_var($p);
                        my $name = $var->{name};
                        $var_hash->{$name}=$var;
                        push @$param_list, $name;
                    }
                }
                return;
            }
            elsif($func =~/^(global|local)$/){
                if($1 eq "global"){
                    global_add_var($param);
                }
                else{
                    local_add_var($param);
                }
                return;
            }
            elsif($func eq "print"){
                if($param=~/^"(.*)",\s*(.*)/){
                    fortran_write($1, $2);
                }
                else{
                    fortran_write($param);
                }
                return;
            }
            elsif($func eq "dump"){
                my $t = dump_param($param);
                fortran_write(undef, $t);
                return;
            }
        }
    }
    elsif($l=~/^CALLBACK\s+(\w+)\s*(.*)/){
        my ($func, $param)=($1, $2);
        my $codelist=$MyDef::compileutil::named_blocks{"last_grab"};
        return;
    }

    if($l=~/^(.+?)\s*([+\-\*\/])=\s*(.+)/){
        $l = "$1 = $1 $2 $3";
    }
    elsif($l=~/^call\s+(\w+)/){
        if(!$list_function_hash{$1}){
            $list_function_hash{$1}=1;
            push @list_function_list, $1;
        }
        else{
            $list_function_hash{$1}++;
        }
    }

    push @$out, $l;
}

sub dumpout {
    my ($f, $out)=@_;
    my $dump={out=>$out,f=>$f};
    foreach my $func (@function_list){
        process_function_std($func);
    }
    my @objlist;
    my @liblist;
    foreach my $i (keys %objects){
        if($i=~/^lib(.*)/){
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

    my @out2;
    $dump->{f}=\@out2;

    my $global_init=MyDef::compileutil::get_named_block("global_init");
    my $last_type;
    foreach my $p (@$global_list){
        my $var = $global_hash->{$p};
        if(!$var){
            $var={};
        }
        my $type = $var->{type};
        if($var->{parameter}){
            $type.=", PARAMETER";
        }
        if($var->{dim}=~/:/){
            $type.=", ALLOCATABLE";
        }
        my $l = $p;
        if($var->{dim}){
            $l.= "($var->{dim})";
        }
        if($var->{init}){
            $l.= " = $var->{init}";
        }
        if($type ne $last_type){
            push @$global_init, "$type :: $l";
            $last_type = $type;
        }
        else{
            $global_init->[-1] .= ", $l";
        }
    }
    if($last_type){
        push @$global_init, "\n";
    }
    my $main_list = $main_func->{var_list};
    my $main_hash = $main_func->{var_hash};
    my $last_type;
    foreach my $p (@$main_list){
        my $var = $main_hash->{$p};
        if(!$var){
            $var={};
        }
        my $type = $var->{type};
        if($var->{parameter}){
            $type.=", PARAMETER";
        }
        if($var->{dim}=~/:/){
            $type.=", ALLOCATABLE";
        }
        my $l = $p;
        if($var->{dim}){
            $l.= "($var->{dim})";
        }
        if($var->{init}){
            $l.= " = $var->{init}";
        }
        if($type ne $last_type){
            push @$global_init, "$type :: $l";
            $last_type = $type;
        }
        else{
            $global_init->[-1] .= ", $l";
        }
    }
    if($last_type){
        push @$global_init, "\n";
    }
    MyDef::dumpout::dumpout($dump);

    my ($label, $is_template);
    foreach my $l (@out2){
        if($l=~/^\s*LABEL\s+(\d+)/){
            $label=sprintf("%5d ", $1);
            next;
        }
        elsif($l=~/^\s*TEMPLATE\s+(START|STOP)/){
            if($1 eq "START"){
                $is_template = 1;
            }
            else{
                $is_template = undef;
            }
            next;
        }
        elsif($is_template){
            push @$f, $l;
            next;
        }

        chomp $l;
        my $prefix;
        if($label){
            $prefix=$label;
            undef $label;
        }
        else{
            $prefix=' ' x 6;
        }

        push @$f, "$prefix$l\n";
    }
    return;
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

1;

# ---- subroutines --------------------------------------------
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

    if($param){
        my $param_list=$func->{param_list};
        my $var_hash=$func->{var_hash};
        my @plist=split_var_line($param);
        my $i = -1;
        foreach my $p (@plist){
            $i++;
            my $var=parse_var($p);
            my $name = $var->{name};
            $var_hash->{$name}=$var;
            push @$param_list, $name;
        }
    }
    if($return_type){
        $func->{return_type}=$return_type;
    }
    if($fname){
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


    my $ret_type = $func->{ret_type};
    my $ret_var = $func->{ret_var};
    my $param_list = $func->{param_list};
    my $param = join(', ', @$param_list);
    if(!($ret_type or $ret_var)){
        push @$open, "SUBROUTINE $name($param)";
    }
    elsif($ret_var){
        my $l="FUNCTION $name($param)";
        $l.= " RESULT($ret_var->{name})";
        if($func->{recursive}){
            $l = "RECURSIVE $l";
        }
        push @$open, $l;
        push @$pre, "$ret_var->{type} :: $ret_var->{name}";
    }
    else{
        push @$open, "$ret_type FUNCTION $name($param)";
    }
    my $var_list = $func->{var_list};
    my $var_hash = $func->{var_hash};
    my $last_type;
    foreach my $p (@$param_list){
        my $var = $var_hash->{$p};
        if(!$var){
            $var={};
        }
        my $type = $var->{type};
        if($var->{parameter}){
            $type.=", PARAMETER";
        }
        if($var->{dim}=~/:/){
            $type.=", ALLOCATABLE";
        }
        my $l = $p;
        if($var->{dim}){
            $l.= "($var->{dim})";
        }
        if($var->{init}){
            $l.= " = $var->{init}";
        }
        if($type ne $last_type){
            push @$pre, "$type :: $l";
            $last_type = $type;
        }
        else{
            $pre->[-1] .= ", $l";
        }
    }
    if($last_type){
        push @$pre, "\n";
    }
    my $last_type;
    foreach my $p (@$var_list){
        my $var = $var_hash->{$p};
        if(!$var){
            $var={};
        }
        my $type = $var->{type};
        if($var->{parameter}){
            $type.=", PARAMETER";
        }
        if($var->{dim}=~/:/){
            $type.=", ALLOCATABLE";
        }
        my $l = $p;
        if($var->{dim}){
            $l.= "($var->{dim})";
        }
        if($var->{init}){
            $l.= " = $var->{init}";
        }
        if($type ne $last_type){
            push @$pre, "$type :: $l";
            $last_type = $type;
        }
        else{
            $pre->[-1] .= ", $l";
        }
    }
    if($last_type){
        push @$pre, "\n";
    }
    @$var_list=();
    push @$close, "END";
    push @$close, "NEWLINE";
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
        return "return $t";
    }
}

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
    return find_var($name);
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
    elsif(!$no_prefix and $name=~/^([t]+)_(.+)$/){
        my $type = get_type_name($2, 1);
        if($type){
            return get_type_word_prefix($1, $type);
        }
    }

    if(!$no_prefix and $name=~/^([t]+)(.)(_.+)?$/ and $type_prefix{$2}){
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
        else{
            return undef;
        }
    }
    return $type;
}

sub get_label {
    $label_index++;
    return sprintf("%d", $label_index*10);
}

sub get_fortran_type {
    my ($p) = @_;
    if($p=~/^s(\d+)/){
        return "CHARACTER (len=$1)";
    }
    my $type = get_type_name($p);
    if(!$type){
        $type = $default_float;
    }
    return $type;
}

sub parse_var {
    my ($name, $type, $value) = @_;
    if(!$value){
        if($name=~/\s*=\s*(\S.*)/){
            $value = $1;
            $name=$`;
        }
    }
    my $dim;
    if($name=~/\((.*)\)\s*$/){
        $dim=$1;
        $name=$`;
    }
    if(!$type){
        if($name =~ /(\S.*?)\s+(\w+)/){
            $type = $1;
            $name = $2;
        }
        else{
            $type = get_fortran_type($name);
        }
    }
    my $var={name=>$name, type=>$type};
    if($dim){
        if($type =~/CHARACTER/){
            $var->{type}.=" (len=$dim)";
        }
        else{
            $var->{dim}=$dim;
        }
    }
    if($value){
        $var->{init}=$value;
    }
    return $var;
}

sub var_declare {
    my ($var) = @_;
    return undef;
}

sub fortran_write {
    my ($fmt, $vlist, $use_format) = @_;
    my $format='*';
    if($fmt){
        if($use_format){
            my $label = get_label();
            $format = $label;
        }
        else{
            ($format, $vlist) = parse_fmt_2($fmt, $vlist);
        }
    }

    my $print_to = MyDef::compileutil::get_macro_word("print_to", 1);
    if(!$print_to){
        $print_to = '*';
    }
    if($print_to eq '*'){
        push @$out, "PRINT $format, $vlist";
    }
    else{
        push @$out, "WRITE($print_to, $format) $vlist";
    }

    if($use_format){
        push @$out, "LABEL $format";
        push @$out, "Format ($fmt)";
    }
}

sub dump_param {
    my ($param) = @_;
    my @plist=split /,\s*/, $param;
    my @segs;
    if(@plist < 10){
        push @segs, "'$param: '";
        push @segs, $param;
    }
    else{
        foreach my $p (@plist){
            push @segs, "' $p='";
            push @segs, $p;
        }
    }
    return join(", ", @segs);
}

sub parse_fmt_2 {
    my ($s_fmt, $s_vlist) = @_;
    my @fmt_list;
    my @vlist = split /,\s*/, $s_vlist;
    my @segs = split /(%[0-9\.]*[fgd])/, $s_fmt;
    my @out_vlist;
    foreach my $s (@segs){
        if($s=~/^%(.*)([fgd])/){
            my ($w, $f)=($1, $2);
            if(!$w){
                $w = 6;
            }
            if($f eq "f"){
                push @fmt_list, "F$w";
            }
            elsif($f eq "g"){
                push @fmt_list, "E$w";
            }
            elsif($f eq "d"){
                push @fmt_list, "I$w";
            }
            push @out_vlist, shift @vlist;
        }
        elsif($s=~/^\$(\w+)/){
            my $type = get_var_type_direct($1);
            if($type=~/^INTEGER/){
                push @fmt_list, "I6";
            }
            elsif($type=~/^(REAL|DOUBLE)/){
                push @fmt_list, "F10.4";
            }
            push @out_vlist, $1;
        }
        else{
            push @fmt_list, "'$s'";
        }
    }
    if(!@out_vlist){
        return ('*', join(", ", @fmt_list));
    }
    else{
        return (join(",", @fmt_list), join(", ", @out_vlist));
    }
}

1;
