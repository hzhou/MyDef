use strict;
package MyDef::output_rust;
our @scope_stack;
our $cur_scope;
our $global_scope;
our %type_name;
our %type_prefix;
our $defalut_int_type = "i64";
our $debug=0;
our $out;
our $mode;
our $page;
our @function_stack;
our %list_function_hash;
our @list_function_list;
our $global_hash;
our $global_list;
our %functions;
our $cur_function;
our %function_autolist;
our %function_defaults;
our $case_if="if";
our $case_elif="else if";
our @case_stack;
our $case_state;
our $case_wrap;
our %plugin_statement;
our %plugin_condition;
our %use_hash;
our @use_list;
our @function_list;
our $main_func={param_list=>[], var_list=>[], var_hash=>{}};
our %protected_var;
our $time_start = time();

sub var_declare {
    my ($v) = @_;
    my $value = $v->{init};
    if(!defined $value){
        $value = get_default_value($v->{type});
    }
    my $attr;
    if($v->{mut}){
        $attr = "mut ";
    }
    if($v->type eq "String"){
        return "let $attr$v->{name} = String::from($value);";
    }
    else{
        return "let $attr$v->{name}: $v->{type} = $value;";
    }
}

sub parse_var {
    my ($name, $type, $value) = @_;
    if(!$value && $name=~/(.*?)\s*=\s*(.*)/){
        $name = $1;
        $value = $2;
    }
    my $explicit_type;
    if(!$type){
        if($name=~/^(\S+):\s*(.*)/){
            ($name, $type) = ($1, $2);
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
        if($case_wrap){
            if($debug eq "case"){
                my $level=@case_stack;
                print "   $level:[case_unwrap]$l\n";
            }
            push @$out, @$case_wrap;
            undef $case_wrap;
        }
    }
}

sub function_block {
    my ($funcname, $paramline) = @_;
    my $func=open_function($funcname, $paramline);
    my @block;
    push @function_list, $func;
    my $fidx=$#function_list;
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
    my ($fname, $param) = @_;
    my $func;
    if($fname eq "main"){
        $func = $main_func;
        $func->{init} = MyDef::compileutil::get_named_block("main_init");
        $func->{finish} = MyDef::compileutil::get_named_block("main_exit");
    }
    else{
        $func= {param_list=>[], var_list=>[], var_hash=>{}, init=>[], finish=>[]};
    }
    MyDef::compileutil::set_named_block("fn_init", $func->{init});
    MyDef::compileutil::set_named_block("fn_finish", $func->{finish});
    $func->{name}=$fname;
    if($param){
        my $param_list=$func->{param_list};
        my $var_hash=$func->{var_hash};
        my @plist=split /,\s*/, $param;
        my $i=0;
        foreach my $p (@plist){
            $i++;
            my ($type, $name);
            if($p=~/(\w+):\s*(.*)/){
                ($type, $name)=($2, $1);
            }
            else{
                $type = infer_c_type($p);
                $name = $p;
            }
            push @$param_list, "$name: $type";
            if($name){
                $var_hash->{$name}={name=>$name, type=>$type};
            }
        }
    }
    if($func->{name}){
        my $name=$func->{name};
        $functions{$name}=$func;
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
    if(!$func->{ret_type} and $func->{ret_var}){
        my $curfile=MyDef::compileutil::curfile_curline();
        print "[$curfile]\x1b[33m Failed to infer function $name return type from [$func->{ret_var}]\n\x1b[0m";
    }
    my $param_list = $func->{param_list};
    my $param = join(', ', @$param_list);
    my $ret_type;
    if($func->{ret_type}){
        $ret_type = " -> $func->{ret_type}";
    }
    push @$open, "fn $name($param)$ret_type {";
    push @$close, "}";
    push @$close, "NEWLINE";
    close_scope($func, $pre, $post);
    if(@{$func->{var_list}}){
        push @$pre, "NEWLINE";
    }
    push @$pre, @{$func->{init}};
    push @$post, @{$func->{finish}};
    if($func->{return}){
        push @$post, $func->{return};
    }
}

sub func_return {
    my ($t) = @_;
    MyDef::compileutil::trigger_block_post();
    if($cur_function->{ret_type}){
        return "return $t";
    }
    elsif(!$t and $t ne '0'){
        $cur_function->{ret_type}=undef;
        return "return";
    }
    else{
        $cur_function->{ret_var} = $t;
        $cur_function->{ret_type} = infer_c_type($t);
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
            my $decl=var_declare($var);
            push @$pre, "$decl;";
            if($global_hash->{$v}){
                my $curfile=MyDef::compileutil::curfile_curline();
                print "[$curfile]\x1b[33m In $blk->{name}: local variable $v has existing global: $decl\n\x1b[0m";
            }
            if($var->{exit}){
                push @exit_calls, "$var->{exit}, $v";
            }
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
    if($debug eq "type"){
        print "  cur_scope\[$cur_scope->{name}]: ";
        foreach my $v (@{$cur_scope->{var_list}}){
            print "$v, ";
        }
        print "\n";
        for(my $i=$#scope_stack; $i>=0; $i--){
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
    for(my $i=$#scope_stack; $i>=0; $i--){
        if($scope_stack[$i]->{var_hash}->{$name}){
            return $scope_stack[$i]->{var_hash}->{$name};
        }
    }
    return undef;
}

sub global_add_symbol {
    my ($name, $type, $value) = @_;
    my $var=parse_var($name, $type, $value);
    $name=$var->{name};
    if($global_hash->{$name}){
        my $exist=$global_hash->{$name};
        if($var->{type} eq $exist->{type}){
            if($var->{array} > $exist->{array}){
                $exist->{array}=$var->{array};
                $exist->{dimension}=$var->{array};
            }
        }
        return $name;
    }
    else{
        $global_hash->{$name}=$var;
        return $name;
    }
}

sub global_add_var {
    my ($name, $type, $value) = @_;
    my $var=parse_var($name, $type, $value);
    $name=$var->{name};
    if($global_hash->{$name}){
        my $exist=$global_hash->{$name};
        if($var->{type} eq $exist->{type}){
            if($var->{array} > $exist->{array}){
                $exist->{array}=$var->{array};
                $exist->{dimension}=$var->{array};
            }
        }
        return $name;
    }
    else{
        push @$global_list, $name;
        $global_hash->{$name}=$var;
        return $name;
    }
}

sub func_add_var {
    my ($name, $type, $value) = @_;
    my ($var_list, $var_hash);
    if(!$cur_function){
        $var_list=$main_func->{var_list};
        $var_hash=$main_func->{var_hash};
    }
    else{
        $var_list=$cur_function->{var_list};
        $var_hash=$cur_function->{var_hash};
    }
    my $var=parse_var($name, $type, $value);
    $name=$var->{name};
    if($var_hash->{$name}){
        my $exist=$var_hash->{$name};
        if($var->{type} eq $exist->{type}){
            if($var->{array} > $exist->{array}){
                $exist->{array}=$var->{array};
                $exist->{dimension}=$var->{array};
            }
        }
        return $name;
    }
    else{
        push @$var_list, $name;
        $var_hash->{$name}=$var;
        return $name;
    }
}

sub my_add_var {
    my ($name, $type, $value) = @_;
    my $var_list=$cur_scope->{var_list};
    my $var_hash=$cur_scope->{var_hash};
    if($var_hash != $global_hash){
        my $var=parse_var($name, $type, $value);
        $name=$var->{name};
        if($var_hash->{$name}){
            my $exist=$var_hash->{$name};
            if($var->{type} eq $exist->{type}){
                if($var->{array} > $exist->{array}){
                    $exist->{array}=$var->{array};
                    $exist->{dimension}=$var->{array};
                }
            }
            return $name;
        }
        else{
            push @$var_list, $name;
            $var_hash->{$name}=$var;
            return $name;
        }
    }
    else{
        return $name;
    }
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
    if($hash->{$name} and $hash->{$name}->{temptype} ne $type){
        my $i=2;
        if($name=~/[0-9_]/){
            $name.="_";
        }
        while($hash->{"$name$i"} and $hash->{"$name$i"}->{temptype} ne $type){
            $i++;
        }
        $name="$name$i";
    }
    if(!$hash->{$name}){
        $var->{name}=$name;
        $var->{temptype}=$type;
        $hash->{$name}=$var;
        my $var_list=$cur_scope->{var_list};
        push @$var_list, $name;
    }
    MyDef::compileutil::set_current_macro($macro_name, $name);
    return $name;
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

sub get_default_value {
    my ($type) = @_;
    my $type = $v->{type};
    if($type eq "bool"){
        return "false";
    }
    elsif($type=~/^[iu]\d+$/){
        return 0;
    }
    elsif($type=~/^[iu]size$/){
        return 0;
    }
    elsif($type=~/^f\d+$/){
        return 0.0;
    }
    elsif($type eq "char"){
        return ' ';
    }
    elsif($type =~/^\[(\S+);\s*(\d+)\]/){
        return "[".get_default_value($1)."; $2]";
    }
    elsif($type =~/^\((.*)\)$/){
        my @tlist = split /,\s*/, $1;
        foreach my $t (@tlist){
            $t = get_default_value($t);
        }
        return '('. join(', ', @tlist).')';
    }
    else{
        my $curfile=MyDef::compileutil::curfile_curline();
        print "[$curfile]\x1b[33m default value for $type not supported\n\x1b[0m";
    }
}

sub infer_value_type {
    my ($val) = @_;
    $val=~s/^[+-]//;
    if($val=~/^\d+[\.eE]/){
        return "f64";
    }
    elsif($val=~/^\d/){
        return $defalut_int_type;
    }
    elsif($val=~/^"/){
        return "String";
    }
    elsif($val=~/^'/){
        return "char";
    }
    elsif($val=~/^(true|false)/){
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
        else{
            return undef;
        }
    }
    elsif($val=~/(\w+)/){
        my $type=get_var_type($val, 1);
        return $type;
    }
    elsif($val=~/^\[(.+)\]$/){
        my @vlist=split /,\s*/, $1;
        my $n = @vlist;
        my $type = infer_value_type($vlist[0]);
        return "[$type: $n]";
    }
    elsif($val=~/^\((.+)\)$/){
        my @vlist=split /,\s*/, $1;
        my @plist;
        foreach my $v (@vlist){
            push @plist, infer_value_type($v);
        }
        return '('.join(", ", @plist)).')';
    }
    elsif($val=~/^\((.*)\)/){
        return infer_value_type($1);
    }
    return undef;
}

sub get_c_type {
    my ($name) = @_;
    my $type = get_type_name($name);
    return $type;
}

sub fmt_string {
    my ($param) = @_;
    $str=~s/\s*$//;
    my @pre_list;
    if($str=~/^\s*\"(.*)\"\s*,\s*(.*)$/){
        $str=$1;
        @pre_list=MyDef::utils::proper_split($2);
    }
    elsif($str=~/^\s*\"(.*)\"\s*$/){
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
        elsif($str=~/\G\{\}/sgc){
            if(!@pre_list){
                $missing++;
            }
            push @arg_list, shift @pre_list;
            push @fmt_list, "{}";
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
                push @arg_list, $v;
                push @fmt_list, "{}";
                if($str=~/\G-/sgc){
                }
            }
            elsif($str=~/\G\{(.*?)\}/sgc){
                push @fmt_list, "{}";
                push @arg_list, $1;
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
    if(!@arg_list){
        return (0, '"'.join('',@fmt_list).'"');
    }
    else{
        my $vcnt=@arg_list;
        return ($vcnt, '"'.join('',@fmt_list).'", '.join(', ', @arg_list));
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

$global_scope={var_list=>[], var_hash=>{}, name=>"global"};
$cur_scope={var_list=>[], var_hash=>{}, name=>"default"};
push @scope_stack, $global_scope;
%type_name=(
    c=>"u32",
    d=>"f64",
    f=>"f32",
    i=>$defalut_int_type,
    j=>$defalut_int_type,
    k.l=>$defalut_int_type,
    m=>$defalut_int_type,
    n=>$defalut_int_type,
    s=>"String",
    count=>"usize",
    size=>"usize",
);
%type_prefix=(
    i=>$defalut_int_type,
    n=>$defalut_int_type,
    n1=>"i8",
    n2=>"i16",
    n4=>"i32",
    n8=>"i64",
    ui=>"u64",
    u=>"u64",
    u1=>"u8",
    u2=>"u16",
    u4=>"u32",
    u8=>"u64",
    c=>"u8",
    b=>"bool",
    s=>"String",
    f=>"f32",
    d=>"f64",
    i8=>"i8",
    i16=>"i16",
    i32=>"i32",
    i64=>"i64",
    u8=>"u8",
    u16=>"u16",
    u32=>"u32",
    u64=>"u64",
    f32=>"f32",
    f64=>"f64",
    "char"=>"char",
    "size"=>"usize",
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
    MyDef::set_page_extension("rs");
    my $init_mode="sub";
    @function_stack=();
    %list_function_hash=();
    @list_function_list=();
    @scope_stack=();
    $global_hash={};
    $global_list=[];
    $cur_scope={var_list=>$global_list, var_hash=>$global_hash, name=>"global"};
    %functions=();
    undef $cur_function;
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
            my ($return_type);
            my $source=$code->{source};
            foreach my $l (@$source){
                if($l=~/^SOURCE/){
                }
                elsif($l=~/^(lexical|parameter|return):\s*(.+?)\s*$/){
                    if($1 eq "lexical"){
                        my @tlist=split /,\s*/, $2;
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
                        $function_defaults{$name}="append:".join(', ', @segs);
                        $l="\$parameter ". join(", ", @params);
                    }
                    elsif($1 eq "parameter"){
                        $l="\$parameter $2";
                    }
                    elsif($1 eq "return"){
                        $l="\$return_type $2";
                        $return_type=$2;
                    }
                }
                elsif($l=~/^\$return_type\s+(.+)/){
                    $return_type = $1;
                }
                else{
                    last;
                }
            }
            if($return_type){
                $functions{$name}={ret_type=>$return_type};
            }
            $function_autolist{$name}="fn";
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
    elsif($l=~/^\$template\s+(.*)/){
        my $file = $1;
        if($file !~ /^\.*\//){
            my $dir = MyDef::compileutil::get_macro_word("TemplateDir", 1);
            if($dir){
                $file = "$dir/$file";
            }
        }
        open In, $file or die "Can't open template $file\n";
        my @all=<In>;
        close In;
        foreach my $a (@all){
            push @$out, $a;
        }
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
    my $check_unwrap;
    if($l=~/^\x24(if|elif|elsif|elseif|case)\s+(.*)$/){
        my $cond=$2;
        my $case=$case_if;
        if($1 eq "if"){
            if($case_wrap){
                if($debug eq "case"){
                    my $level=@case_stack;
                    print "   $level:[case_unwrap]$l\n";
                }
                push @$out, @$case_wrap;
                undef $case_wrap;
            }
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
        push @src, "$case $cond {";
        push @src, "INDENT";
        push @src, "BLOCK";
        push @src, "DEDENT";
        push @src, "}";
        push @src, "PARSE:CASEPOP";
        push @case_stack, {state=>"if", wrap=>$case_wrap};
        undef $case_state;
        undef $case_wrap;
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
        push @case_stack, {state=>undef, wrap=>$case_wrap};
        undef $case_state;
        undef $case_wrap;
        if($debug eq "case"){
            my $level=@case_stack;
            print "Entering case [$level]: $l\n";
        }
        MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
        return "NEWBLOCK-else";
    }
    elsif($l!~/^SUBBLOCK/){
        undef $case_state;
        if($case_wrap){
            if($debug eq "case"){
                my $level=@case_stack;
                print "   $level:[case_unwrap]$l\n";
            }
            push @$out, @$case_wrap;
            undef $case_wrap;
        }
        if($l eq "CASEPOP"){
            if($debug eq "case"){
                my $level=@case_stack;
                print "    Exit case [$level][wrap:$case_wrap]\n";
            }
            my $t_case=pop @case_stack;
            if($t_case){
                $case_state=$t_case->{state};
                $case_wrap=$t_case->{wrap};
            }
            return 0;
        }
    }
    if($MyDef::compileutil::cur_mode eq "PRINT"){
        push @$out, $l;
        return 0;
    }
    elsif($l=~/^NOOP POST_MAIN/){
        while(my $f=shift @list_function_list){
            if($MyDef::compileutil::named_blocks{"lambda-$f"}){
                my $blk = $MyDef::compileutil::named_blocks{"lambda-$f"};
                push @$out, @$blk;
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
                        }
                    }
                    else{
                        $paramline="";
                    }
                    if(defined $paramline){
                        my ($func, $block)=function_block($funcname, $paramline);
                        foreach my $l (@$block){
                            if($l eq "BLOCK"){
                                func_push($func);
                                MyDef::compileutil::list_sub($codelib);
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
    }
    elsif($l=~/^\s*\$(\w+)\s*(.*)$/){
        my ($func, $param)=($1, $2);
        if($param !~ /^=/){
            if($plugin_statement{$func}){
                my $codename=$plugin_statement{$func};
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
                    push @src, "$init;";
                }
                if($cond){
                    if($cond==1){
                        push @src, "loop {";
                    }
                    else{
                        push @src, "while $cond {";
                    }
                    push @src, "INDENT";
                    push @src, "BLOCK";
                }
                if($next){
                    push @src, "$next;";
                }
                push @src, "DEDENT";
                push @src, "}";
                MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                return "NEWBLOCK-while";
            }
            elsif($func eq "for"){
                if($param =~/(.*)\s+in\s+(.*)/){
                    return single_block("for $1 in $2 {", "}", "for");
                }
                else{
                    if($param=~/(.*);(.*);(.*)/){
                        my @src;
                        push @src, "$1;";
                        push @src, "while $2 {";
                        push @src, "INDENT";
                        push @src, "BLOCK";
                        push @src, "$3;";
                        push @src, "DEDENT";
                        push @src, "}";
                        MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                        return "NEWBLOCK-for";
                    }
                    else{
                        my $var;
                        if($param=~/^(\S+)\s*=\s*(.*)/){
                            $var=$1;
                            $param=$2;
                        }
                        my @tlist=split /:/, $param;
                        my ($i0, $i1, $step);
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
                        if($step eq "1"){
                            $step="++";
                        }
                        elsif($step eq "-1"){
                            $step="--";
                        }
                        else{
                            $step="+=$step";
                        }
                        my $my="";
                        if(!$var){
                            $var = "i";
                        }
                        $param="$my$var=$i0; $var$i1; $var$step";
                        my @src;
                        if($step==1 && $i1=~/^<(.*)/){
                            push @src, "for $var in $i0..$1 {";
                            push @src, "INDENT";
                            push @src, "BLOCK";
                            push @src, "DEDENT";
                            push @src, "}";
                        }
                        else{
                            push @src, "let mut $var = $i0;";
                            push @src, "while $var$i1 {";
                            push @src, "INDENT";
                            push @src, "BLOCK";
                            push @src, "$var += $step;";
                            push @src, "DEDENT";
                            push @src, "}";
                        }
                        MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                        return "NEWBLOCK-for";
                    }
                }
            }
            elsif($func eq "foreach" and $param =~/(.*)\s+in\s+(.*)/){
                return single_block("for (_i, $1) in ($2).enumerate() {", "}", "foreach");
            }
            elsif($func eq "print"){
                my ($n, $fmt) = fmt_string($param);
                push @$out, "println!($fmt);";
            }
        }
    }
    push @$out, $l;
}
sub dumpout {
    my ($f, $out, $pagetype)=@_;
    my $dump={out=>$out,f=>$f, module=>"output_rust"};
    foreach my $func (@function_list){
        if(!$func->{processed}){
            process_function_std($func);
        }
    }
    if(@use_list){
        foreach my $l (@use_list){
            push @$f, "use $l;\n";
        }
        push @$f, "\n";
    }
    if(@$global_list){
        foreach my $name (@$global_list){
            my $v = $global_hash->{$name};
            my $decl = var_declare($v);
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
