use strict;
package MyDef::output_go;

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
our %function_autolist;
our $case_if="if";
our $case_elif="else if";
our @case_stack;
our $case_state;
our %plugin_statement;
our %plugin_condition;
our %objects;
our $custom_split_var_line;
our %protected_var;
my %auto_imports=(
    fmt => "fmt",
    os => "os",
    bufio => "bufio",
    io => "io",
    math => "math",
    strings => "strings",
    ioutil=>"io/ioutil",
    rand=>"math/rand",
    );
$cur_scope={var_list=>[], var_hash=>{}, name=>"default"};
%type_name=(
    c=>"uint8",
    d=>"float64",
    f=>"float32",
    i=>"int",
    j=>"int",
    k=>"int",
    l=>"int64",
    m=>"int",
    n=>"int",
    s=>"string",
    count=>"int",
    size=>"int",
    In=>"io.Reader",
    Out=>"io.Writer",
);
%type_prefix=(
    i=>"int",
    n=>"int",
    n1=>"int8",
    n2=>"int16",
    n4=>"int32",
    n8=>"int64",
    ui=>"uint",
    u=>"uint",
    u1=>"uint8",
    u2=>"uint16",
    u4=>"uint32",
    u8=>"uint64",
    c=>"int8",
    uc=>"uint8",
    b=>"bool",
    s=>"string",
    f=>"float32",
    d=>"float64",
    z=>"complex128",
    "buf"=>"[]byte",
    "has"=>"bool",
    "is"=>"bool",
    "do"=>"bool",
);

sub get_interface {
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout);
}

sub init_page {
    my ($t_page)=@_;
    $page=$t_page;
    MyDef::set_page_extension("go");
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
            push @src, "$case $cond {";
            push @src, "INDENT";
            push @src, "BLOCK";
            push @src, "DEDENT";
            push @src, "}";
        }
        else{
            push @src, "$case $cond {";
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
        push @src, "else {";
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
    elsif($l=~/^NOOP POST_MAIN/){
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
        if($func eq "dump"){
            return;
        }
        elsif($func eq "get_type"){
            my $type=get_var_type($param2);
            MyDef::compileutil::set_current_macro($param1, $type);
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
            if($func eq "import"){
                my @tlist = split /,\s*/, $param;
                foreach my $f (@tlist){
                    $objects{$f}=1;
                }
                return;
            }
            elsif($func eq "while"){
                my ($init, $cond, $next);

                my @clause = split /\s*;\s*/, $param;
                my $n = @clause;
                if($n>1 && !$clause[-1]){
                    $n--;
                }

                if($n>3){
                    my $curfile=MyDef::compileutil::curfile_curline();
                    print "[$curfile]\x1b[33m error: [\$while $param]\n\x1b[0m";
                }
                elsif($n==3){
                    ($init, $cond, $next) = @clause;
                }
                elsif($n==2){
                    ($cond, $next) = @clause;
                }
                elsif($n==1){
                    $cond = $param;
                }
                else{
                    $cond = 1;
                }

                my @src;
                if($init){
                    $cond = "$init; $cond; $next";
                }
                elsif($next){
                    $cond = "$cond; $next";
                }
                elsif($cond==1){
                    $cond = "";
                }
                push @src, "for $cond {";
                push @src, "INDENT";
                push @src, "BLOCK";
                push @src, "DEDENT";
                push @src, "}";
                MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                return "NEWBLOCK-while";
            }
            elsif($func eq "for"){
                if($param=~/(.*);(.*);(.*)/){
                    my @src;
                    return single_block("for $param {", "}");
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
                    if($step eq "1"){
                        $step="++";
                    }
                    elsif($step eq "-1"){
                        $step="--";
                    }
                    else{
                        $step= "+=$step";
                    }

                    $param="$var:=$i0; $var$i1; $var$step";
                    my @src;
                    return single_block("for $param {", "}");
                    MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                    return "NEWBLOCK-for";
                }
                return;
            }
            elsif($func eq "foreach"){
                if($param=~/^(.+)\s+in\s+(\w+)/){
                    my ($t, $v)=($1, $2);
                    if($t=~/(.+),\s*(.+)/){
                        return single_block("for $1, $2 := range $v {", "}", "for");
                    }
                    else{
                        return single_block("for _, $t := range $v {", "}", "for");
                    }
                }
                elsif($param=~/^(\S+)\s*$/){
                    my ($t, $v)=("t", $1);
                    if($t=~/(.+),\s*(.+)/){
                        return single_block("for $1, $2 := range $v {", "}", "for");
                    }
                    else{
                        return single_block("for _, $t := range $v {", "}", "for");
                    }
                }
                return;
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
            elsif($func eq "print"){
                $objects{fmt}=1;
                $param=~s/^\s+//;
                my ($n, $fmt)=fmt_string($param, 1);
                my $print_to = MyDef::compileutil::get_macro_word("print_to", 1);
                if($n==0){
                    if(!$print_to){
                        push @$out, "fmt.Print($fmt)";
                    }
                    elsif($print_to=~/^s_/){
                        push @$out, "fmt.Sprint($print_to, $fmt)";
                    }
                    else{
                        push @$out, "fmt.Fprint($print_to, $fmt)";
                    }
                }
                else{
                    if(!$print_to){
                        push @$out, "fmt.Printf($fmt)";
                    }
                    elsif($print_to=~/^s_/){
                        push @$out, "fmt.Sprintf($print_to, $fmt)";
                    }
                    else{
                        push @$out, "fmt.Fprintf($print_to, $fmt)";
                    }
                }
                return;
            }
            elsif($func eq "dump"){
                my @tlist=MyDef::utils::proper_split($param);
                foreach my $t (@tlist){
                    push @$out, "fmt.Println($t)";
                }
                return;
            }
        }
    }
    elsif($l=~/^CALLBACK\s+(\w+)\s*(.*)/){
        my ($func, $param)=($1, $2);
        my $codelist=$MyDef::compileutil::named_blocks{"last_grab"};
        return;
    }

    while($l=~/\b(\w+)([\.\(])/g){
        if($2 eq '.' and $auto_imports{$1}){
            $objects{$auto_imports{$1}}=1;
        }
        elsif($2 eq '(' and $function_autolist{$1}){
            if(!$list_function_hash{$1}){
                $list_function_hash{$1}=1;
                push @list_function_list, $1;
            }
            else{
                $list_function_hash{$1}++;
            }
        }
    }
    if($l=~/^return\s*(.*)/){
        func_return($1);
    }

    push @$out, $l;
}

sub dumpout {
    my ($f, $out)=@_;
    my $dump={out=>$out,f=>$f};
    foreach my $func (@function_list){
        if(!$func->{processed}){
            process_function_std($func);
        }
    }
    my $package="main";
    if($page->{package}){
        $package=$page->{package};
    }
    push @$f, "package $package\n\n";
    my @pkgs = sort keys %objects;
    if(@pkgs>1){
        push @$f, "import (\n";
        foreach my $t (@pkgs){
            push @$f, "    \"$t\"\n";
        }
        push @$f, ")\n\n";
    }
    elsif(@pkgs==1){
        push @$f, "import \"$pkgs[0]\"\n\n";
    }
    if(@$global_list){
        foreach my $name (@$global_list){
            my $v = $global_hash->{$name};
            my $decl=var_declare($v);
            push @$f, "$decl\n";
        }
        push @$f, "\n";
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

1;

# ---- subroutines --------------------------------------------
sub parse_condition {
    my ($param) = @_;
    return $param;
}

sub var_declare {
    my ($v) = @_;
    my $t = "var $v->{name} $v->{type}";
    if($v->{init}){
        $t.="=$v->{init}";
    }
    return $t;
}

sub parse_var {
    my ($name, $type, $value) = @_;
    if(!$value && $name=~/(.*?)\s*=\s*(.*)/){
        $name = $1;
        $value = $2;
    }

    my $explicit_type;
    if(!$type){
        if($name=~/^\s*(\S[^=]*)\s+([^= \t].*)/){
            ($name, $type)=($1, $2);
            $explicit_type=1;
        }
    }

    if(!$type){
        $type=get_c_type($name);
    }

    my $var={};
    $var->{name}=$name;
    $var->{type}=$type;
    $var->{init}=$value;
    return $var;
}

sub get_var_type {
    my ($name) = @_;
    return get_var_type_direct($name);
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

    if($param){
        my $param_list=$func->{param_list};
        my $var_hash=$func->{var_hash};
        my @plist=split_var_line($param);
        my $i = -1;
        foreach my $p (@plist){
            $i++;
            my ($type, $name);
            if($p=~/(\S.*)\s+(\S+)\s*$/){
                ($type, $name)=($2, $1);
            }
            else{
                $type= get_c_type($p);
                $name=$p;
            }
            push @$param_list, "$name $type";
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


    my $declare=$func->{declare};
    if(!$declare){
        my $param_list=$func->{"param_list"};
        my $param=join(', ', @$param_list);
        $declare="func $name($param)";
        if($func->{ret_type}){
            if($func->{ret_type}=~/,/){
                $declare.=" ($func->{ret_type}) ";
            }
            else{
                $declare.=" $func->{ret_type}";
            }
        }
        $func->{declare}=$declare;
    }
    push @$open, $declare."{";
    push @$close, "}";
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
        if($t=~/^[^(]+,/){
            my @tlist=MyDef::utils::proper_split($t);
            my @rlist;
            push @rlist, '(';
            foreach my $t (@tlist){
                my $type=infer_value_type($t);
                push @rlist, $type;
            }
            push @rlist, ')';
            $cur_function->{ret_type}=join(', ', @rlist);
        }
        else{
            print "infer_value_type [$t]\n";
            $cur_function->{ret_type}=infer_value_type($t);
        }
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
    if($out->[-1]=~/^(return|break)/){
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
        elsif($c eq "p"){
            return "*$type";
        }
        elsif($c eq "a"){
            return "[]$type";
        }
        else{
            return undef;
        }
    }
    return $type;
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
            elsif($str=~/\G[-+ #]*[0-9]*(\.\d+)?[hlLzjt]*[vTtbcdoqxXUeEfFgGsqp]/sgc){
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

sub infer_value_type {
    my ($val) = @_;
    $val=~s/^[+-]//;
    if($val=~/^\d+[\.eE]/){
        return "float64";
    }
    elsif($val=~/^\d/){
        return "int";
    }
    elsif($val=~/^"/){
        return "string";
    }
    elsif($val=~/^'/){
        return "int8";
    }
    elsif($val=~/^(true|false)/){
        $page->{use_bool}=1;
        return "bool";
    }
    elsif($val=~/(\w+)\(.*\)/){
        my $func=$functions{$1};
        if($debug){
            print "infer_value_type: function $1 [$func]\n";
        }
        if($func and $func->{ret_type}){
            return $func->{ret_type};
        }
        elsif($1=~/^(u?int\d*|float\d+|complex\d+|bool)/){
            return $1;
        }
    }
    elsif($val=~/(\w+)(.*)/){
        my $type=get_var_type($val, 1);
        return $type;
    }
    elsif($val=~/^\((.*)\)/){
        return infer_value_type($1);
    }
    return undef;
}

sub get_c_type {
    my ($name) = @_;
    my $type =  get_type_name($name);
    return $type;
}

sub get_var_fmt {
    my ($v, $warn) = @_;
    return '%v';
}

1;
