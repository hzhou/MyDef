use strict;
package MyDef::output_pascal;
our @fn_block;
our @directives;
our @uses;
our %uses;
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
our $default_float = "real";
our $default_int = "longint";
our $global_hash;
our $global_list;
our $main_func;
our %functions;
our $cur_function;
our @function_list;
our %function_autolist;
our %function_defaults;
our $case_if="if";
our $case_elif="else if";
our @case_stack;
our $case_state;
our $case_wrap;
our %global_records;
our %plugin_statement;
our %plugin_condition;
our @forward_list;
our $global_types=[];

sub parse_condition {
    my ($cond) = @_;
    if($cond =~/^(and|or):\s*(.+)/){
        my ($and, $t) = ($1, $2);
        my @tlist = split /,\s*/, $t;
        foreach my $t (@tlist){
            if($t=~/^\(.*\)$/){
            }
            elsif($t=~/[\+\-*\/ <>=]/){
                $t = "($t)";
            }
        }
        return join(" $and ", @tlist);
    }
    else{
        return $cond;
    }
}

sub begin_block {
    my ($t) = @_;
    my @src;
    push @src, "$t begin";
    push @src, "INDENT";
    push @src, "BLOCK";
    push @src, "DEDENT";
    push @src, "end";
    MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
    return "NEWBLOCK";
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
    my ($fname, $param, $ret_type) = @_;
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
        my @vars = parse_var_line($param);
        foreach my $var (@vars){
            my $name = $var->{name};
            $var_hash->{$name}=$var;
            push @$param_list, $name;
        }
    }
    if($ret_type){
        $func->{ret_type}=$ret_type;
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

sub process_function {
    my ($func) = @_;
    my $name=$func->{name};
    my $open = $func->{openblock};
    my $close = $func->{closeblock};
    my $pre = $func->{preblock};
    my $post = $func->{postblock};
    my $var_list = $func->{var_list};
    my $var_hash = $func->{var_hash};
    my $ret_type = $func->{ret_type};
    my $param_list = $func->{param_list};
    my $param = pascal_param($param_list, $func->{var_hash});
    if($param){
        $name.="($param)";
    }
    my $decl;
    if(!$ret_type){
        $decl= "procedure $name;";
    }
    else{
        $decl="function $name:$ret_type;";
    }
    $func->{declare}=$decl;
    push @$open, $decl;
    if($func->{labels} and @{$func->{labels}}){
        foreach my $t (@{$func->{labels}}){
            if($t=~/[+]/){
                $t=eval($t);
            }
        }
        push @$open, "label ".join(', ', @{$func->{labels}}). ";\n";
    }
    if($func->{consts} and @{$func->{consts}}){
        push @$open, "const\n";
        foreach my $p (@{$func->{consts}}){
            push @$open, "    $p;\n";
        }
    }
    if(@$var_list){
        push @$open, "var\n";
        foreach my $p (@$var_list){
            my $var = $var_hash->{$p};
            my $t="$p: $var->{type}";
            if(defined $var->{init}){
                $t.=" = $var->{init}";
            }
            push @$open, "    $t;\n";
        }
    }
    push @$open, "begin";
    push @$close, "end;";
    push @$close, "NEWLINE";
    push @$pre, @{$func->{init}};
    push @$post, @{$func->{finish}};
    if($func->{return}){
        push @$post, $func->{return};
    }
}

sub pascal_param {
    my ($plist, $vhash) = @_;
    my @l;
    foreach my $p (@$plist){
        my $v = $vhash->{$p};
        if($v->{attr} eq "var"){
            push @l, "var $v->{name}: $v->{type}";
        }
        else{
            push @l, "$v->{name}: $v->{type}";
        }
    }
    return join('; ', @l);
}

sub parse_var_line {
    my ($l) = @_;
    $l=~s/^\s+//;
    $l=~s/;\s*$//;
    my @vars;
    if($l=~/\s*=\s*\(\s*\w+\s*:/){
        push @vars, parse_var($l);
    }
    elsif($l=~/[:;]/){
        my @alist = split /;\s*/, $l;
        foreach my $a (@alist){
            if(!$a){
            }
            elsif($a=~/^(.*?)\s*:\s*(.+)$/){
                my $type = $2;
                my @blist = split /,\s*/, $1;
                my $value;
                if($type=~/^(.*?)\s*=\s*(.*)/){
                    ($type, $value) = ($1, $2);
                }
                foreach my $b (@blist){
                    push @vars, parse_var($b, $type, $value);
                }
            }
            else{
                my @blist = split /,\s*/, $1;
                foreach my $b (@blist){
                    push @vars, parse_var($b);
                }
            }
        }
    }
    else{
        my @alist = split /,\s*/, $l;
        foreach my $a (@alist){
            push @vars, parse_var($a);
        }
    }
    return @vars;
}

sub parse_var {
    my ($name, $type, $value) = @_;
    if($name=~/^\d+$/){
        print "parse_var: [$name] [$type] [$value] ?\n";
    }
    if(!defined $value){
        if($name=~/\s*=\s*(\S.*)/){
            $value = $1;
            $name=$`;
        }
    }
    my $attr;
    if($name=~/^(var)\s+(.+)/){
        $attr = $1;
        $name = $2;
    }
    if(!$type){
        if($name =~/^(\w+)\s*:\s*(.+)/){
            ($type, $name)=($2, $1);
        }
        elsif($name =~ /(\S.*?)\s+(\w+)/){
            ($type, $name)=($1, $2);
        }
        else{
            $type = get_type_name($name);
        }
    }
    my $var={name=>$name, type=>$type};
    if(defined $value){
        $var->{init}=$value;
    }
    if($attr){
        $var->{attr}=$attr;
    }
    return $var;
}

sub func_add_var {
    my ($name, $type, $value) = @_;
    my $var = parse_var($name, $type, $value);
    my $l = $cur_function->{var_list};
    my $h = $cur_function->{var_hash};
    my $name = $var->{name};
    if(!$h->{$name}){
        push @$l, $name;
        $h->{$name} = $var;
    }
}

sub var_declare {
    my ($var) = @_;
    return undef;
}

sub fmt_string {
    my ($str) = @_;
    if(!$str){
        return (1, '');
    }
    elsif($str=~/,\s*$/){
        return (1, $`);
    }
    elsif($str=~/,\s*-\s*$/){
        return (0, $`);
    }
    elsif($str=~/,\s*=\s*$/){
        return (2, $`);
    }
    elsif($str=~/'/){
        if($str=~/-'\s*$/){
            return (0, "$`'");
        }
        else{
            return (1, $str);
        }
    }
    $str=~s/\s*$//;
    my @pre_list;
    if($str=~/^\s*\"(.*)\"$/){
        $str = $1;
    }
    my $newline=1;
    my %colors=(red=>31,green=>32,yellow=>33,blue=>34,magenta=>35,cyan=>36);
    my %escs=(t=>9, n=>10, r=>13);
    my @parts;
    my @segs;
    my @group;
    while(1){
        if($str=~/\G$/sgc){
            last;
        }
        elsif($str=~/\G\$/sgc){
            if($str=~/\G(red|green|yellow|blue|magenta|cyan)/sgc){
                if(@segs){
                    push @parts, "'".join('', @segs)."'";
                    @segs=();
                }
                push @parts, "#27+'[$colors{$1}m'";
                if($str=~/\G\{/sgc){
                    push @group, $1;
                }
            }
            elsif($str=~/\Greset/sgc){
                if(@segs){
                    push @parts, "'".join('', @segs)."'";
                    @segs=();
                }
                push @parts, "#27+'[0m'";
            }
            elsif($str=~/\Gclear/sgc){
                if(@segs){
                    push @parts, "'".join('', @segs)."'";
                    @segs=();
                }
                push @parts, "#27+'[H'+#27+'[J'";
            }
            elsif($str=~/\G\{([^}]*)\}/sgc){
                if(@segs){
                    push @parts, "'".join('', @segs)."'";
                    @segs=();
                }
                push @parts, $1;
            }
            elsif($str=~/\G(\w+(\s*:\s*\d+)*)/sgc){
                if(@segs){
                    push @parts, "'".join('', @segs)."'";
                    @segs=();
                }
                push @parts, $1;
                if($str=~/\G-/sgc){
                }
            }
            else{
                push @segs, '$';
            }
        }
        elsif($str=~/\G\\(.)/sgc){
            if($escs{$1}){
                if(@segs){
                    push @parts, "'".join('', @segs)."'";
                    @segs=();
                }
                push @parts, "#$escs{$1}";
            }
            else{
                push @segs, $1;
            }
        }
        elsif($str=~/\G\}/sgc){
            if(@group){
                pop @group;
                if(!@group){
                    if(@segs){
                        push @parts, "'".join('', @segs)."'";
                        @segs=();
                    }
                    push @parts, "#27+'[0m'";
                }
                else{
                    my $c=$group[-1];
                    if(@segs){
                        push @parts, "'".join('', @segs)."'";
                        @segs=();
                    }
                    push @parts, "#27+'[$colors{$c}m'";
                }
            }
            else{
                push @segs, '}';
            }
        }
        elsif($str=~/\G[^\$\}]+/sgc){
            push @segs, $&;
        }
        else{
            die "parse_loop: nothing matches! [$str]\n";
        }
    }
    if(@segs){
        push @parts, "'".join('', @segs)."'";
        @segs=();
    }
    if($parts[-1]=~/^'(.*)-'$/){
        $newline = 0;
        if($1){
            $parts[-1]="'$1'";
        }
        else{
            pop @parts;
        }
    }
    elsif($parts[-1] eq "#10"){
        pop @parts;
    }
    return ($newline, join(', ', @parts));
}

sub dump_param {
    my ($param) = @_;
    my @plist=split /,\s*/, $param;
    my @segs;
    foreach my $p (@plist){
        push @segs, "' $p='";
        push @segs, $p;
    }
    return join(", ", @segs);
}

@function_stack=();
%list_function_hash=();
@list_function_list=();
$cur_scope={var_list=>[], var_hash=>{}, name=>"default"};
sub get_interface {
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout);
}
sub init_page {
    my ($t_page)=@_;
    $page=$t_page;
    MyDef::set_page_extension("pas");
    my $init_mode="sub";
    if($MyDef::def->{macros}->{use_double} or $page->{use_double}){
        $default_float="double";
    }
    elsif($MyDef::def->{macros}->{use_single} or $page->{use_single}){
        $default_float="single";
    }
    if($MyDef::def->{macros}->{default_int}){
        $default_int = $MyDef::def->{macros}->{default_int};
    }
    if($page->{default_int}){
        $default_int = $page->{default_int};
    }
    if($MyDef::def->{macros}->{default_float}){
        $default_float = $MyDef::def->{macros}->{default_float};
    }
    if($page->{default_float}){
        $default_float = $page->{default_float};
    }
    $MyDef::def->{macros}->{default_float}=$default_float;
    $MyDef::def->{macros}->{default_int}  =$default_int;
    %type_name=(
        c=>"byte",
        d=>"double",
        f=>$default_float,
        i=>$default_int,
        j=>$default_int,
        k=>$default_int,
        l=>$default_int,
        m=>$default_int,
        n=>$default_int,
        count=>$default_int,
        size=>$default_int,
    );
    %type_prefix=(
        i=>$default_int,
        n=>$default_int,
        n1=>"shortint",
        n2=>"smallint",
        n4=>"longint",
        n8=>"int64",
        u1=>"byte",
        u2=>"word",
        u4=>"longword",
        u8=>"qword",
        b=>"boolean",
        s=>"string",
        f=>"real",
        d=>"double",
        "has"=>"boolean",
        "is"=>"boolean",
        "do"=>"boolean",
    );
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
            my ($return_type, $autolist);
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
                elsif($l=~/^\$autolist\s+(\w+)/){
                    $autolist = $1;
                    $l="NOOP";
                }
                else{
                    last;
                }
            }
            if($return_type){
                $functions{$name}={ret_type=>$return_type};
            }
            if($autolist ne "skip" and ($page->{autolist} eq "global" || $autolist)){
                $function_autolist{$name}=$autolist;
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
    $global_hash=$main_func->{var_hash};
    $global_list=$main_func->{var_list};
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
        $cond=parse_condition($cond);
        my @src;
        push @src, "$case $cond then begin";
        push @src, "INDENT";
        push @src, "BLOCK";
        push @src, "DEDENT";
        push @src, "end";
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
        push @src, "else begin";
        push @src, "INDENT";
        push @src, "BLOCK";
        push @src, "DEDENT";
        push @src, "end";
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
    if($l=~/^DUMP_STUB\s/){
        push @$out, $l;
    }
    elsif($l=~/^NOOP POST_MAIN/){
        my $old_out=MyDef::compileutil::set_output(\@fn_block);
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
        MyDef::compileutil::set_output($old_out);
        return;
    }
    elsif($l=~/^CALLBACK (\w+)\s*(.*)/){
        my ($func, $param) = ($1, $2);
        my $codelist=$MyDef::compileutil::named_blocks{"last_grab"};
        if($func=~/^(record|object)$/){
            if($param=~/(\w+)/){
                my $name = $1;
                my @tlist="$name = record";
                foreach my $t (@$codelist){
                    if($t=~/^((bit)?packed)$/){
                        $tlist[0] = "$name = $1 record";
                    }
                    elsif($t=~/.*;/){
                        push @tlist, "    $t";
                    }
                    elsif($t=~/case.*of/){
                        push @tlist, "    $t";
                    }
                    elsif($t=~/(\w+):\s*([^;]+)/){
                        push @tlist, "    $1: $2;";
                    }
                    else{
                        push @tlist, "    $t;";
                    }
                }
                push @tlist, "end;";
                $global_records{$name} = \@tlist;
                push @$global_types, "record $name";
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
            if($func eq "directive"){
                if($param=~/^\{(.*)\}/){
                    push @directives, $1;
                }
                else{
                    push @directives, $param;
                }
                return;
            }
            elsif($func =~ /^uses?$/){
                my @tlist = split /,\s*/, $param;
                foreach my $t (@tlist){
                    if(!$uses{$t}){
                        $uses{$t}=1;
                        push @uses, $t;
                    }
                }
                return;
            }
            elsif($func eq "while"){
                if(!$param or $param eq "1"){
                    return begin_block("while true do");
                }
                else{
                    return begin_block("while $param do");
                }
            }
            elsif($func eq "for"){
                if($param =~/(\w+)\s*=\s*(.*)/){
                    my ($v, $t) = ($1, $2);
                    func_add_var($v, $default_int);
                    if($t=~/^\d+$/){
                        $t="1 to $t";
                    }
                    else{
                        $t =~ s/:/ to /g;
                    }
                    $param = "$v:=$t";
                }
                else{
                }
                return begin_block("for $param do");
            }
            elsif($func =~/^repeat(_until)?$/){
                $param=~s/;\s*$//;
                my @src;
                push @src, "repeat";
                push @src, "INDENT";
                push @src, "BLOCK";
                push @src, "DEDENT";
                push @src, "until $param;";
                MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                return "NEWBLOCK";
            }
            elsif($func eq "case_of"){
                my @src;
                push @src, "case $param of";
                push @src, "INDENT";
                push @src, "BLOCK";
                push @src, "DEDENT";
                push @src, "end";
                MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                return "NEWBLOCK";
            }
            elsif($func eq "of"){
                return begin_block("$param:");
            }
            elsif($func =~/^(return_type|parameter|lexical)/){
                if($1 eq "return_type"){
                    $cur_function->{ret_type}=$param;
                }
                elsif($1 eq "parameter"){
                    my $param_list=$cur_function->{param_list};
                    my $var_hash=$cur_function->{var_hash};
                    my @vars = parse_var_line($param);
                    foreach my $var (@vars){
                        my $name = $var->{name};
                        $var_hash->{$name}=$var;
                        push @$param_list, $name;
                    }
                }
                return 1;
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
                my ($func, $block)=function_block($funcname, $paramline);
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
                    ($func, $block)=function_block($fname, $paramline);
                    my $idx = $func->{_idx};
                    $MyDef::compileutil::named_blocks{"$fname\_pre"} = $MyDef::compileutil::named_blocks{"fn$idx\_pre"};
                    $MyDef::compileutil::named_blocks{"$fname\_close"} = $MyDef::compileutil::named_blocks{"fn$idx\_close"};
                }
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
            elsif($func eq "forward"){
                push @forward_list, split /,\s*/, $param;
                return;
            }
            elsif($func =~/^(return_type|return|result|recursive|parameter|lexical)$/){
                if($1 eq "return" or $1 eq "result"){
                    my $var = parse_var($param);
                    $cur_function->{ret_var}= $var;
                    $cur_function->{ret_type}=$var->{type};
                }
                elsif($1 eq "return_type"){
                    $cur_function->{ret_type}=$param;
                }
                elsif($1 eq "parameter"){
                    my $param_list=$cur_function->{param_list};
                    my $var_hash=$cur_function->{var_hash};
                    my @vars = parse_var_line($param);
                    foreach my $var (@vars){
                        my $name = $var->{name};
                        $var_hash->{$name}=$var;
                        push @$param_list, $name;
                    }
                }
                return;
            }
            elsif($func =~/^(global|local|var)$/){
                my @vars = parse_var_line($param);
                if($1 eq "global"){
                    foreach my $v (@vars){
                        my $name = $v->{name};
                        if(!$global_hash->{$name}){
                            push @$global_list, $name;
                            $global_hash->{$name}=$v;
                        }
                    }
                }
                else{
                    my $l = $cur_function->{var_list};
                    my $h = $cur_function->{var_hash};
                    foreach my $v (@vars){
                        my $name = $v->{name};
                        if(!$h->{$name}){
                            push @$l, $name;
                            $h->{$name}=$v;
                        }
                    }
                }
                return;
            }
            elsif($func eq "label"){
                if($param=~/(\S+)\s*:\s*$/){
                    $param=$1;
                    push @$out, "$1:";
                }
                $param=~s/\s*;\s*$//;
                my @t = split /,\s*/, $param;
                if(!$cur_function->{labels}){
                    $cur_function->{labels}=[];
                }
                push @{$cur_function->{labels}}, @t;
                return;
            }
            elsif($func eq "const"){
                $param=~s/\s*;\s*$//;
                my @t = split /,\s*/, $param;
                if(!$cur_function->{consts}){
                    $cur_function->{consts}=[];
                }
                push @{$cur_function->{consts}}, @t;
                return;
            }
            elsif($func eq "type"){
                $param=~s/\s*;\s*$//;
                my @t = split /,\s*/, $param;
                push @$global_types, @t;
                return;
            }
            elsif($func =~/^(record|object)$/){
                return "CALLBACK $1 $param";
            }
            elsif($func eq "print"){
                my ($newline, $fmt)=fmt_string($param);
                my $print_to = MyDef::compileutil::get_macro_word("print_to", 1);
                my $l = "write";
                if($newline==1){
                    $l = "writeln";
                }
                if(length($fmt)==0){
                    if($print_to){
                        $l.="($print_to)";
                    }
                    else{
                        $l.="()";
                    }
                }
                else{
                    if($print_to){
                        $l.="($print_to, $fmt)";
                    }
                    else{
                        $l.="($fmt)";
                    }
                }
                push @$out, "$l;";
                if($newline==2){
                    if($print_to){
                        push @$out, "flush($print_to);";
                    }
                    else{
                        push @$out, "flush(output);";
                    }
                }
                return 0;
            }
            elsif($func eq "dump"){
                my $t = dump_param($param);
                push @$out, "writeln($t);";
                return 0;
            }
        }
    }
    elsif($l=~/^CALLBACK\s+(\w+)\s*(.*)/){
        my ($func, $param)=($1, $2);
        my $codelist=$MyDef::compileutil::named_blocks{"last_grab"};
        return;
    }
    if($l=~/^(\w+)\s*:=\s*(.*)/){
        if($cur_function->{name} ne $1){
            if(!$global_hash->{$1} and !$cur_function->{var_hash}->{$1}){
                func_add_var($1);
            }
        }
    }
    elsif($l=~/^(.+?)\s*([+\-\*\/])=\s*(.+)/){
        $l = "$1 := $1 $2 $3";
    }
    elsif($l=~/^([^ '\$\(:<>]+)\s*=(.*)/){
        $l = "$1 := $2";
    }
    elsif($l=~/(.*)(\+\+|--)\s*$/){
        if($2 eq '++'){
            $l = "$1 := $1 + 1;";
        }
        else{
            $l = "$1 := $1 - 1;";
        }
    }
    elsif($l=~/^return\b\s*(.*)/){
        if($1){
            my $t = $1;
            $t=~s/;\s*$//;
            $l = "exit ($t);";
        }
        else{
            $l = "exit;";
        }
    }
    if($l!~/;\s*$/){
        if($l=~/^(else)/){
            if($out->[-1] =~/DEDENT/){
                $out->[-2]=~s/;$//;
            }
            else{
                $out->[-1]=~s/;$//;
            }
        }
        elsif($l=~/^others:\s*(.*)/){
            $l="else $1";
        }
        elsif($l eq "end" and $out->[-1]=~/^DEDENT/){
            my $i = @$out - 1;
            my $cnt=0;
            for(my $j=0; $j<10; $j++){
                $i--;
                if($out->[$i]=~/DUMP_STUB .*_pre/){
                    next;
                }
                elsif($out->[$i]=~/INDENT/){
                    last;
                }
                else{
                    $cnt++;
                }
            }
            if($cnt==1){
                $out->[$i-1]=~s/\s*begin$//;
            }
            else{
                $out->[-2]=~s/;$//;
                push @$out, "end;";
            }
            return;
        }
        elsif($l=~/^(label|const|type|var|repeat)\s*$/){
        }
        elsif($l=~/=.*\b(record)\s*$/){
        }
        elsif($l=~/\b(begin)\s*$/){
        }
        elsif($l=~/\b(case|if|while|for)\b.*\b(of|then|do)\s*$/){
        }
        elsif($l!~/[,:\(\[\{\};]\s*$/){
            $l.=";";
        }
    }
    push @$out, $l;
}
sub dumpout {
    my ($f, $out)=@_;
    my $dump={out=>$out,f=>$f};
    foreach my $l (@directives){
        push @$f, "{$l}\n";
    }
    push @$f, "PROGRAM $page->{_pagename};\n";
    push @$out, "DUMP_STUB _main_exit\n";
    if(@uses){
        push @$f, "uses ".join(', ', @uses).";\n";
    }
    my $l = $main_func->{labels};
    if($l and @{$l}){
        foreach my $t (@{$l}){
            if($t=~/[+]/){
                $t=eval($t);
            }
        }
        push @$f, "label ".join(', ', @{$l}). ";\n";
    }
    my $l = $main_func->{consts};
    if($l and @{$l}){
        push @$f, "const\n";
        foreach my $p (@{$l}){
            push @$f, "    $p;\n";
        }
    }
    if($global_types and @{$global_types}){
        push @$f, "type\n";
        foreach my $p (@{$global_types}){
            if($p=~/^record (\w+)/){
                my $tlist=$global_records{$1};
                foreach my $t (@$tlist){
                    push @$f, "    $t\n";
                }
            }
            else{
                push @$f, "    $p;\n";
            }
        }
    }
    if(@$global_list){
        push @$f, "var\n";
        foreach my $p (@$global_list){
            my $var = $global_hash->{$p};
            my $t="$p: $var->{type}";
            if(defined $var->{init}){
                $t.=" = $var->{init}";
            }
            push @$f, "    $t;\n";
        }
    }
    unshift @$out, "begin", "INDENT";
    push @$out, "DEDENT", "end.";
    foreach my $func (@function_list){
        process_function($func);
        push @$f, "$func->{declare} forward;\n";
    }
    if(@fn_block){
        $dump->{fn_block}=\@fn_block;
        unshift @$out, "INCLUDE_BLOCK fn_block";
    }
    MyDef::dumpout::dumpout($dump);
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
