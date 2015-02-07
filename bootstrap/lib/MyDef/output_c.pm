use strict;
package MyDef::output_c;
our @scope_stack;
our $cur_scope;
our $global_scope;
our $debug;
our $out;
our $mode;
our $page;
our %misc_vars;
our %basic_types;
our %type_name;
our %type_prefix;
our %fntype;
our %stock_functions;
our %lib_include;
our %type_include;
our %text_include;
our %tuple_hash;
our $autoload;
our $autoload_h;
our %protected_var;
our @case_stack;
our $case_state;
our $case_wrap;

$global_scope={var_list=>[], var_hash=>{}, name=>"global"};
$cur_scope={var_list=>[], var_hash=>{}, name=>"default"};
push @scope_stack, $global_scope;
sub open_scope {
    my ($blk_idx, $scope_name)=@_;
    push @scope_stack, $cur_scope;
    $cur_scope={var_list=>[], var_hash=>{}, name=>$scope_name};
}
sub close_scope {
    my ($blk, $pre, $post)=@_;
    if(!$blk){
        $blk=$cur_scope;
    }
    my ($var_hash, $var_list);
    if(ref($blk) eq "HASH"){
        $var_hash=$blk->{var_hash};
        $var_list=$blk->{var_list};
    }
    else{
        $var_hash=$cur_scope->{var_hash};
        $var_list=$cur_scope->{var_list};
    }
    my @exit_calls;
    if(@$var_list){
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
    if($blk->{return}){
        if(!$post){
            $post=MyDef::compileutil::get_named_block("_post");
        }
        push @$post, $blk->{return};
    }
    $cur_scope=pop @scope_stack;
}
sub find_var {
    my ($name)=@_;
    if($debug eq "type"){
        print "  cur_scope\[$cur_scope->{name}]: ";
        foreach my $v (@{$cur_scope->{var_list}}){
            print "$v, ";
        }
        print "\n";
        for(my $i=$#scope_stack; $i >=0; $i--){
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
    for(my $i=$#scope_stack; $i >=0; $i--){
        if($scope_stack[$i]->{var_hash}->{$name}){
            return $scope_stack[$i]->{var_hash}->{$name};
        }
    }
    return undef;
}
our $except;
our $anonymous_count=0;
our $print_type=1;
use File::stat;
sub get_mtime {
    my ($fname)=@_;
    my $st=stat($fname);
    return $st->[9];
}
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
    i=>"int",
    j=>"int",
    k=>"int",
    m=>"int",
    n=>"int",
    l=>"long",
    f=>"float",
    d=>"double",
    count=>"int",
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
    c=>"unsigned char",
    uc=>"unsigned char",
    b=>"int",
    s=>"char *",
    f=>"float",
    d=>"double",
    "time"=>"time_t",
    "file"=>"FILE *",
    "has"=>"int",
    "is"=>"int",
);
%stock_functions=(
    "printf"=>1,
);
%lib_include=(
    glib=>"glib",
);
%type_include=(
    time_t=>"time",
    int8_t=>"stdlib",
    int16_t=>"stdlib",
    int32_t=>"stdlib",
    int64_t=>"stdlib",
    uint8_t=>"stdlib",
    uint16_t=>"stdlib",
    uint32_t=>"stdlib",
    uint64_t=>"stdlib",
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
sub get_interface {
    my $interface_type="general";
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout, $interface_type);
}
sub init_page {
    my ($t_page)=@_;
    $page=$t_page;
    MyDef::set_page_extension("c");
    my $init_mode="sub";
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
    if($l=~/^DEBUG (\w+)/){
        if($1 eq "OFF"){
            $debug=0;
        }
        else{
            $debug=$1;
        }
        return;
    }
    elsif($l=~/^\$warn (.*)/){
        my $curfile=MyDef::compileutil::curfile_curline();
        print "[$curfile]\x1b[33m $1\n\x1b[0m";
        return;
    }
    elsif($l=~/^\$template\s*(.*)/){
        open In, $1 or die "Can't open template $1\n";
        my @all=<In>;
        close In;
        foreach my $a (@all){
            push @$out, $a;
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
            print "eval error: [$@]\n";
        }
        return;
    }
    push @$out, $l;
}
sub dumpout {
    my ($f, $out, $pagetype)=@_;
    my $dump={out=>$out,f=>$f};
    MyDef::dumpout::dumpout($dump);
}
sub single_block {
    my ($t1, $t2, $scope)=@_;
    push @$out, "$t1";
    push @$out, "INDENT";
    push @$out, "BLOCK";
    push @$out, "DEDENT";
    push @$out, "$t2";
    if($scope){
        return "NEWBLOCK-$scope";
    }
    else{
        return "NEWBLOCK";
    }
}
sub single_block_pre_post {
    my ($pre, $post, $scope)=@_;
    if($pre){
        push @$out, @$pre;
    }
    push @$out, "BLOCK";
    if($post){
        push @$out, @$post;
    }
    if($scope){
        return "NEWBLOCK-$scope";
    }
    else{
        return "NEWBLOCK";
    }
}
sub parse_condition {
    my ($param)=@_;
    if($param=~/(\$map\b.*)/){
        my $pre=$`;
        $param=$1;
        my @args=MyDef::utils::proper_split($param);
        my $map=shift @args;
        if($map=~/\$map\((.*?),\s+(.*)\)/){
            my $sep=$1;
            my $template=$2;
            my @segs;
            foreach my $a (@args){
                my $t=$template;
                $t=~s/\$1/$a/g;
                push @segs, $t;
            }
            return $pre . join($sep, @segs);
        }
        else{
            return $pre . $param;
        }
    }
    elsif($param=~/^\$(\w+)\s+(.*)/){
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
                print "eval error: [$@]\n";
            }
            return $condition;
        }
    }
    return check_expression($param, "condition");
}
sub declare_tuple {
    my ($param)=@_;
    my $name;
    if($tuple_hash{$param}){
        $name=$tuple_hash{$param};
    }
    else{
        $name=MyDef::utils::uniq_name("T", \%structs);
        $tuple_hash{$param}=$name;
    }
    MyDef::compileutil::set_current_macro("T", $name);
    my $s_list=[];
    my $s_hash={};
    $structs{$name}={list=>$s_list, hash=>$s_hash};
    push @struct_list, $name;
    my @plist=split /,\s+/, $param;
    my $i=0;
    foreach my $p (@plist){
        $i++;
        my $m_name="a$i";
        push @$s_list, $m_name;
        $s_hash->{$m_name}=$p;
    }
    return $name;
}
sub declare_struct {
    my ($name, $param)=@_;
    if($MyDef::compileutil::in_autoload){
        $autoload=undef;
        $autoload_h=0;
        if($page->{autoload} eq "write_h"){
            if(!$h_hash{"autoload"}){
                $autoload=[];
                $h_hash{"autoload"}=$autoload;
            }
            else{
                $autoload=$h_hash{"autoload"};
            }
        }
        elsif($page->{autoload} eq "h"){
            $autoload_h=1;
        }
    }
    else{
        $autoload=undef;
        $autoload_h=0;
    }
    my ($s_list, $s_hash);
    my ($s_init, $s_exit);
    if($structs{$name}){
        $s_list=$structs{$name}->{list};
        $s_hash=$structs{$name}->{hash};
        $s_init=$s_hash->{"-init"};
        $s_exit=$s_hash->{"-exit"};
    }
    else{
        $s_init=[];
        $s_exit=[];
        $s_list=[];
        $s_hash={"-init"=>$s_init, "-exit"=>$s_exit};
        $structs{$name}={list=>$s_list, hash=>$s_hash};
        if(!$autoload_h){
            push @struct_list, $name;
        }
    }
    if($autoload){
        push @$autoload, "struct-$name";
    }
    $type_prefix{"st$name"}="struct $name";
    my @plist=split /,\s+/, $param;
    my $i=0;
    foreach my $p (@plist){
        my ($m_name, $type, $needfree);
        if($p=~/^\s*$/){
            next;
        }
        elsif($p=~/(-\w+)=>(.*)/){
            $s_hash->{$1}=$2;
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
        elsif($p=~/^@/){
            $needfree=1;
            $p=$';
        }
        $i++;
        if($p=~/(.*?)(\S+)\s*=\s*(.*)/){
            $p="$1$2";
            push @$s_init, "$2=$3";
        }
        if($p=~/(.*\S)\s+(\S+)\s*$/){
            $type=$1;
            $m_name=$2;
            if($m_name=~/^(\*+)(.*)/){
                $type.=" $1";
                $m_name=$2;
            }
            $p=$m_name;
        }
        elsif($basic_types{$p} or $p=~/\*$/){
            $m_name="a$i";
            $type=$p;
        }
        else{
            $m_name=$p;
            if($p=~/^(next|prev)$/){
                $type="struct $name *";
            }
            elsif($p=~/^(left|right)$/){
                $type="struct $name *";
            }
            elsif($fntype{$p}){
                $type="function";
            }
            else{
                $type=get_c_type($p);
            }
        }
        if(!$s_hash->{$m_name}){
            push @$s_list, $m_name;
        }
        $s_hash->{$m_name}=$type;
        if($needfree){
            $s_hash->{"$name-needfree"}=1;
        }
    }
}
sub get_struct_constructor {
    my ($name)=@_;
    my $s_list=$structs{$name}->{list};
    my $s_hash=$structs{$name}->{hash};
    my $s_init=$s_hash->{"-init"};
    if($s_init and @$s_init){
        my @param_list;
        my @initializer;
        my %init_hash;
        foreach my $l (@$s_init){
            if($l=~/^(\w+)=\$(\w+)/ and $s_hash->{$1}){
                my $dummy=$2;
                push @param_list, $s_hash->{$1}." $dummy";
                push @initializer, "$1=$dummy";
                $init_hash{$1}=1;
            }
            elsif($l=~/^(\w+)=(.*)/ and $s_hash->{$1}){
                if($2 eq "\$"){
                    my $dummy="dummy_$1";
                    push @param_list, $s_hash->{$1}." $dummy";
                    push @initializer, "$1=$dummy";
                }
                else{
                    push @initializer, "$1=$2";
                }
                $init_hash{$1}=1;
            }
            else{
            }
        }
        foreach my $m (@$s_list){
            if(!$init_hash{$m}){
                my $default=type_default($s_hash->{$m});
                if($default){
                    push @initializer, "$m=$default";
                }
            }
        }
        return (\@param_list, \@initializer);
    }
    else{
        return (undef, undef);
    }
}
sub get_struct_element_type {
    my ($stype, $evar)=@_;
    if($stype=~/(\w+)(.*)/){
        if($typedef_hash{$1}){
            $stype=$typedef_hash{$1}.$2;
        }
    }
    if($stype=~/struct\s+(\w+)/){
        my $struc=$structs{$1};
        my $h=$struc->{hash};
        if($h->{$evar}){
            return $h->{$evar};
        }
        else{
            foreach my $k (keys(%$h)){
                if($k=~/^$evar\[/){
                    return "$h->{$k} *";
                }
            }
        }
        if($debug eq "type"){
            while(my ($k, $v)=each %$h){
                print "  :|$k: $v\n";
            }
            print "$evar not defined in struct $1\n";
        }
    }
    return "void";
}
sub struct_free {
    my ($out, $ptype, $name)=@_;
    my $type=pointer_type($ptype);
    if($type=~/struct\s+(\w+)/ and $structs{$1}){
        my $s_list=$structs{$1}->{list};
        my $s_hash=$structs{$1}->{hash};
        foreach my $p (@$s_list){
            if($s_hash->{"$p-needfree"}){
                struct_free($out, $s_hash->{$p}, "$name->$p");
            }
        }
    }
    push @$out, "free($name);";
}
sub struct_set {
    my ($struct_type, $struct_var, $val, $out)=@_;
    my $struct=$structs{$struct_type}->{list};
    my @vals=split /,\s*/, $val;
    for(my $i=0; $i<=$#vals; $i++){
        my $sname=$struct->[$i];
        do_assignment("$struct_var\->$sname", $vals[$i], $out);
    }
}
sub struct_get {
    my ($struct_type, $struct_var, $var, $out)=@_;
    my $struct=$structs{$struct_type}->{list};
    my @vars=split /,\s*/, $var;
    for(my $i=0; $i<=$#vars; $i++){
        my $sname=$struct->[$i];
        do_assignment( $vars[$i],"$struct_var\->$sname", $out);
    }
}
sub open_function {
    my ($fname, $param)=@_;
    my $func= {param_list=>[], var_list=>[], var_hash=>{}, init=>[], finish=>[], openblock=>[], closeblock=>[], preblock=>[], postblock=>[]};
    MyDef::compileutil::set_named_block("fn_init", $func->{init});
    MyDef::compileutil::set_named_block("fn_finish", $func->{finish});
    $func->{name}=$fname;
    if($param eq "api"){
        if($fname=~/^([a-zA-Z0-9]+)_(\w+)/){
            if($fntype{$2}){
                my $t=$fntype{$2};
                if($t=~/^(.*?)\s*\(\s*\*\s*(\w+)\s*\)\s*\(\s*(.*)\)/){
                    $func->{ret_type}=$1;
                    $param=$3;
                }
            }
        }
    }
    if($param){
        my $param_list=$func->{param_list};
        my $var_hash=$func->{var_hash};
        my @plist=split /,\s*/, $param;
        my $i=0;
        foreach my $p (@plist){
            $i++;
            if($p=~/(\S.*)\s+(\S+)\s*$/){
                my ($type, $name)=($1, $2);
                if($name=~/^(\*+)(.+)/){
                    $type.=" $1";
                    $name=$2;
                }
                elsif($name=~/^(&)(.+)/){
                    $type.=" $1";
                    $name=$2;
                }
                $var_hash->{$name}={name=>$name, type=>$type};
                push @$param_list, "$type $name";
            }
            elsif($p eq "fmt" and $i==@plist){
                push @$param_list, "char * fmt, ...";
            }
            else{
                if($fntype{$p}){
                    push @$param_list, $fntype{$p};
                    $var_hash->{$p}={name=>$p, type=>"function"};
                }
                else{
                    my $t= get_c_type($p);
                    push @$param_list, "$t $p";
                    $var_hash->{$p}={name=>$p, type=>$t};
                }
            }
        }
    }
    if($func->{name}){
        my $name=$func->{name};
        push @function_declare_list, $name;
        $functions{$name}=$func;
    }
    return $func;
}
sub func_return {
    my ($t)=@_;
    MyDef::compileutil::trigger_block_post();
    if(!$cur_function->{ret_type}){
        if($t){
            $cur_function->{ret_var}=$t;
            $cur_function->{ret_type}=infer_c_type($t);
        }
        else{
            $cur_function->{ret_type}="void";
        }
    }
}
sub global_add_symbol {
    my ($name, $type, $value)=@_;
    my $var=parse_var($name, $type, $value);
    my $name=$var->{name};
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
    my ($name, $type, $value)=@_;
    my $var=parse_var($name, $type, $value);
    my $name=$var->{name};
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
    my ($name, $type, $value)=@_;
    if(!$cur_function){
        return $name;
    }
    my $var_list=$cur_function->{var_list};
    my $var_hash=$cur_function->{var_hash};
    my $var=parse_var($name, $type, $value);
    my $name=$var->{name};
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
    my ($name, $type, $value)=@_;
    my $var_list=$cur_scope->{var_list};
    my $var_hash=$cur_scope->{var_hash};
    my $var=parse_var($name, $type, $value);
    my $name=$var->{name};
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
sub auto_add_var {
    my ($name, $type, $value)=@_;
    my $var=find_var($name);
    if(!$var){
        if($debug eq "type"){
            my $curfile=MyDef::compileutil::curfile_curline();
            print "[$curfile]\x1b[33m auto_add_var: $name - $type - $value\n\x1b[0m";
        }
        func_add_var($name, $type, $value);
    }
}
sub temp_add_var {
    my ($name, $type, $value)=@_;
    my $var=parse_var($name, $type, $value);
    my $name=$var->{name};
    my $macro_name=$name;
    $name=MyDef::utils::uniq_name($name, \%protected_var);
    if($debug eq "type"){
        print "temp_var $macro_name -> $name of $var->{type}\n";
    }
    my $hash=$cur_scope->{var_hash};
    if($hash->{$name} and $hash->{$name}->{type} ne $type){
        my $i=2;
        if($name=~/[0-9_]/){
            $name.="_";
        }
        while($hash->{"$name$i"} and $hash->{"$name$i"} ne $type){
            $i++;
        }
    }
    if(!$hash->{$name}){
        $var->{name}=$name;
        $hash->{$name}=$var;
        my $var_list=$cur_scope->{var_list};
        push @$var_list, $name;
    }
    MyDef::compileutil::set_current_macro($macro_name, $name);
    return $name;
}
sub parse_var {
    my ($name, $type, $value)=@_;
    my $type_given=$type;
    my ($init, $array, $constructor);
    my @attrs;
    my $explicit_type;
    $name=~s/;\s*$//;
    if(!$type){
        if($name=~/^\s*(\S[^=]*)\s+([^= \t].*)/){
            ($type, $name)=($1, $2);
            $explicit_type=1;
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
    if($type){
        while($type=~/^\s*(extern|static|const|register)\s*(.*)/){
            push @attrs, $1;
            $type=$2;
        }
    }
    if($name=~/(\S+?)\s*=\s*(.*)/){
        ($name, $init)=($1, $2);
        if($debug eq "type"){
            print "    parse_var: name $1, init $2\n";
        }
        if($init=~/^\[string_from_file:(\S+)\]/){
            my @t;
            open In, $1 or die "string_from_file: can't open $1\n";
            while(<In>){
                chomp;
                s/\\/\\\\/g;
                s/"/\\"/g;
                push @t, $_;
            }
            close In;
            $init="=\"".join("\\n\\\n", @t)."\"";
        }
        elsif($init=~/^=\[binary_from_file:(\S+)\]/){
            $global_hash->{"_$name"}="extern char _$name";
            push @$global_list, "_$name";
            $init="=&_$name";
            push @extern_binary, "$name:$1";
        }
        if(!$value){
            $value=$init;
        }
    }
    if($name=~/(\w+)\[(.*)\]/){
        $name=$1;
        $array=$2;
    }
    elsif($name=~/(\w+)\((.*)\)/){
        $name=$1;
        $constructor=$2;
    }
    if(!$type){
        $type=get_c_type($name);
        if($fntype{$name}){
            $type="function";
        }
        if(!($type and $type ne "void" and name_with_prefix($name))){
            if(defined $value){
                my $val_type=infer_c_type($value);
                if($debug eq "type"){
                    print "    infer_c_type: [$value] -> $val_type\n";
                }
                if($val_type and $val_type ne "void"){
                    $type = $val_type;
                }
            }
        }
    }
    my $var={};
    $var->{name}=$name;
    $var->{type}=$type;
    $var->{init}=$init;
    if(@attrs){
        $var->{attr}=join(" ", @attrs);
    }
    if(defined $array){
        $var->{array}=$array;
        $var->{dimension}=$array;
        if($type!~/\*$/){
            $var->{type}.=" *";
        }
        elsif($type_given or $explicit_type){
            $var->{type}.="*";
        }
    }
    elsif(defined $constructor){
        $var->{constructor}=$constructor;
    }
    if($debug eq "type"){
        my $curfile=MyDef::compileutil::curfile_curline();
        print "[$curfile]\x1b[33m add_var: type:[$type] - $name ($array) - $init ($value)\n\x1b[0m";
    }
    return $var;
}
sub var_declare {
    my ($var)=@_;
    if($var->{type} eq "function"){
        return $fntype{$var->{name}};
    }
    else{
        my $name=$var->{name};
        my $type=$var->{type};
        my $t;
        if(defined $var->{array}){
            $t=pointer_type($type)." $name"."[$var->{array}]";
        }
        elsif(defined $var->{constructor}){
            $t=pointer_type($type)." $name"."($var->{constructor})";
        }
        else{
            $t="$type $name";
        }
        if(defined $var->{init}){
            $t.=" = $var->{init}";
        }
        if(defined $var->{attr}){
            return  $var->{attr}." $t";
        }
        else{
            return  $t;
        }
    }
}
sub get_var_type_direct {
    my ($name)=@_;
    my $var=find_var($name);
    if($debug eq "type"){
        print "get_var_type_direct: $name - [$var] - $var->{type}\n";
    }
    if($var){
        return $var->{type};
    }
    else{
        return undef;
    }
}
sub get_var_type {
    my ($name)=@_;
    if($name=~/^(\w+)(.*)/){
        my $tail=$2;
        my $base_type=get_var_type_direct($1);
        $base_type=~s/\s*&$//;
        return get_sub_type($base_type, $tail);
    }
    else{
        return "void";
    }
}
sub get_sub_type {
    my ($type0, $tail)=@_;
    if(!$type0){
        return "void";
    }
    if($tail=~/^(\.|->)(\w+)(.*)/){
        $tail=$3;
        my $type=get_struct_element_type($type0, $2);
        return get_sub_type($type, $tail);
    }
    elsif($tail=~/^\[.*?\](.*)/){
        $tail=$1;
        if($type0=~/\*$/){
            return get_sub_type(pointer_type($type0), $tail);
        }
        else{
            my $curfile=MyDef::compileutil::curfile_curline();
            print "[$curfile]\x1b[33m error in dereferencing pointer type $type0\n\x1b[0m";
            return "void";
        }
    }
    else{
        return $type0;
    }
}
sub protect_var {
    my ($v)=@_;
    if($protected_var{$v}){
        my $curfile=MyDef::compileutil::curfile_curline();
        print "[$curfile]\x1b[33m Variable $v protected: [$protected_var{$v}]\n\x1b[0m";
        $protected_var{$v}++;
    }
    else{
        $protected_var{$v}=1;
    }
}
sub infer_c_type {
    my $val=shift;
    if($val=~/^\((float|int|char|unsigned .*|.+\*)\)/){
        return $1;
    }
    elsif($val=~/^\((.*)/){
        return infer_c_type($1);
    }
    elsif($val=~/^[+-]?\d+\./){
        return "float";
    }
    elsif($val=~/^[+-]?\d/){
        return "int";
    }
    elsif($val=~/^"/){
        return "char *";
    }
    elsif($val=~/^'/){
        return "char";
    }
    elsif($val=~/^\((\w+)\)\w/){
        return $1;
    }
    elsif($val=~/(\w+)\(.*\)/){
        my $func=$functions{$1};
        return $func->{ret_type};
    }
    elsif($val=~/(\w+)(.*)/){
        my $type=get_var_type($val);
        return $type;
    }
}
sub type_default {
    my ($type)=@_;
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
sub get_c_type_word {
    my ($name)=@_;
    if($name){
        if($type_prefix{$name}){
            my $type=$type_prefix{$name};
            return $type;
        }
        if($name=~/^([a-z0-9]+)/){
            my $prefix=$1;
            if($type_prefix{$prefix}){
                return $type_prefix{$prefix};
            }
            elsif($prefix=~/^(.*?)\d+$/ and $type_prefix{$1}){
                return $type_prefix{$1};
            }
            elsif($structs{$1}){
                return "struct $1";
            }
        }
        if(substr($name, 0, 1) eq "t"){
            return get_c_type_word(substr($name,1));
        }
        elsif(substr($name, 0, 1) eq "p"){
            return get_c_type_word(substr($name,1)).'*';
        }
    }
    return undef;
}
sub get_c_type {
    my $name=shift;
    my $check;
    my $type="void";
    if($name=~/.*\.([a-zA-Z].+)/){
        $name=$1;
    }
    if($type_name{$name}){
        $type= $type_name{$name};
    }
    elsif($name=~/(\w+?)_(.*)/){
        my ($t1, $t2)=($1, $2);
        my $t=get_c_type_word($t1);
        if($t1 eq "t" or $t1 eq "temp"){
            $type=get_c_type_word($t2);
        }
        elsif($t1 eq "p" or $t1 eq "tp"){
            $type=get_c_type_word($t2).'*';
        }
        else{
            $type=get_c_type_word($t1);
        }
    }
    else{
        $type=get_c_type_word($name);
    }
    if(!$type){
        $type="void";
    }
    elsif($type =~/^\*/){
        $type="void";
    }
    if($type_include{$type}){
        my @flist=split /,\s*/, $type_include{$type};
        if($MyDef::compileutil::in_autoload){
            $autoload=undef;
            $autoload_h=0;
            if($page->{autoload} eq "write_h"){
                if(!$h_hash{"autoload"}){
                    $autoload=[];
                    $h_hash{"autoload"}=$autoload;
                }
                else{
                    $autoload=$h_hash{"autoload"};
                }
            }
            elsif($page->{autoload} eq "h"){
                $autoload_h=1;
            }
        }
        else{
            $autoload=undef;
            $autoload_h=0;
        }
        foreach my $f (@flist){
            my $key;
            if($f=~/\.\w+$/){
                $key="\"$f\"";
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
            $includes{$key}=1;
            if($autoload){
                push @$autoload, "include-$key";
            }
        }
    }
    while($name=~/\[.*?\]/g){
        $type=pointer_type($type);
    }
    if($debug eq "type"){
        print "    get_c_type:   $name: $type\n";
    }
    return $type;
}
sub name_with_prefix {
    my ($name)=@_;
    if($type_name{$name}){
        return 1;
    }
    if($name=~/^(t_?)*(p_?)*([a-zA-Z][a-zA-Z0-9]*)\_/){
        my $prefix=$3;
        if($debug eq "type"){
            print "name_with_prefix: $prefix - $type_prefix{$prefix}\n";
        }
        if($type_prefix{$prefix}){
            return 1;
        }
    }
    return 0;
}
sub pointer_type {
    my ($t)=@_;
    $t=~s/\s*\*\s*$//;
    return $t;
}
sub get_name_type {
    my $t=shift;
    if($t=~/(\S.*\S)\s+(\S+)/){
        return ($1, $2);
    }
    else{
        return (get_c_type($t), $t);
    }
}
sub get_var_fmt {
    my ($v, $warn)=@_;
    my $type=get_var_type($v);
    if(!$type or $type eq "void"){
        $type=get_c_type($v);
    }
    if($type=~/^char \*/){
        return "\%s";
    }
    elsif($type=~/\*\s*$/){
        return "\%p";
    }
    elsif($type=~/^(float|double)/){
        return "\%g";
    }
    elsif($type=~/(int|long)\s*$/){
        return "\%d";
    }
    elsif($type=~/^unsigned char/){
        return "\%d";
    }
    elsif($type=~/char/){
        return "\%c";
    }
    else{
        if($warn){
            my $curfile=MyDef::compileutil::curfile_curline();
            print "[$curfile]\x1b[33m get_var_fmt: unhandled $v - $type\n\x1b[0m";
        }
        return undef;
    }
}
sub allocate {
    my ($dim, $param2)=@_;
    $includes{"<stdlib.h>"}=1;
    my $init_value;
    if($dim=~/(.*),\s*(.*)/){
        $dim=$1;
        $init_value=$2;
    }
    if($dim=~/[+-]/){
        $dim="($dim)";
    }
    my @plist=split /,\s+/, $param2;
    foreach my $p (@plist){
        if($p){
            if($p=~/^(\w+)$/){
                my $var=find_var($p);
                if(!$var){
                    func_add_var($p);
                    $var=find_var($p);
                }
                $var->{dimension}=$dim;
                if($dim=~/\*/){
                    my @parts=split /\s*\*\s*/, $dim;
                    my $i=0;
                    foreach my $d (@parts){
                        $i++;
                        $var->{"dim$i"}=$d;
                    }
                    if($i==2){
                        $var->{"class"}="matrix";
                    }
                }
            }
            my $type=pointer_type(get_var_type($p));
            if($dim eq "1"){
                push @$out, "$p=($type*)malloc(sizeof($type));";
            }
            else{
                push @$out, "$p=($type*)malloc($dim*sizeof($type));";
            }
        }
    }
    if(defined $init_value and $init_value ne ""){
        func_add_var("i", "int");
        push @$out, "for(i=0;i<$dim;i++){";
        foreach my $p (@plist){
            if($p){
                push @$out, "    $p\[i]=$init_value;";
            }
        }
        push @$out, "}";
    }
}
sub local_allocate {
    my ($dim, $param2)=@_;
    my $post=MyDef::compileutil::get_named_block("_post");
    $includes{"<stdlib.h>"}=1;
    my $init_value;
    if($dim=~/(.*),\s*(.*)/){
        $dim=$1;
        $init_value=$2;
    }
    if($dim=~/[+-]/){
        $dim="($dim)";
    }
    my @plist=split /,\s+/, $param2;
    foreach my $p (@plist){
        if($p){
            if($p=~/^(\w+)$/){
                my $var=find_var($p);
                if(!$var){
                    func_add_var($p);
                    $var=find_var($p);
                }
                $var->{dimension}=$dim;
                if($dim=~/\*/){
                    my @parts=split /\s*\*\s*/, $dim;
                    my $i=0;
                    foreach my $d (@parts){
                        $i++;
                        $var->{"dim$i"}=$d;
                    }
                    if($i==2){
                        $var->{"class"}="matrix";
                    }
                }
            }
            my $type=pointer_type(get_var_type($p));
            if($dim eq "1"){
                push @$out, "$p=($type*)malloc(sizeof($type));";
            }
            else{
                push @$out, "$p=($type*)malloc($dim*sizeof($type));";
            }
            push @$post, "free($p);";
        }
    }
    if(defined $init_value and $init_value ne ""){
        func_add_var("i", "int");
        push @$out, "for(i=0;i<$dim;i++){";
        foreach my $p (@plist){
            if($p){
                push @$out, "    $p\[i]=$init_value;";
            }
        }
        push @$out, "}";
    }
}
sub check_expression {
    my ($l, $context)=@_;
    if($l=~/^return\b\s*(.*)/){
        if(length($1)<=0){
            func_return();
            return "return";
        }
        else{
            my $t=check_expression($1, $context);
            func_return($t);
            return "return $t";
        }
    }
    elsif($l=~/^\s*(if|for|while|switch)/){
        return $l;
    }
    my ($assign, $left, $right);
    my %cache;
    my @stack;
    my @types;
    while(1){
        my ($token, $type);
        if($l=~/\G$/gc){
            last;
        }
        elsif($l=~/\G("([^"\\]|\\.)*")/gc){
            $token=$1;
            $type="atom-string";
        }
        elsif($l=~/\G('([^'\\]|\\.)*')/gc){
            $token=$1;
            $type="atom-char";
        }
        elsif($l=~/\G(\d+[eE]-?\d+|\d*\.\d+([eE]-?\d+)?)/gc){
            $token=$1;
            $type="atom-number-float";
            if($types[-1] =~/^atom/ and $token=~/^\.(\d+)/){
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
            if($stack[-1] eq "^" and $token<10 and $token>1){
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
            if($types[-1] =~/^op/ && $stack[-1] eq "." or $stack[-1] eq "->"){
                if($types[-2] !~/^atom/){
                    #error;
                }
                $token=join("", splice(@stack, -2)).$token;
                $type="atom-exp";
                splice(@types, -2);
            }
        }
        elsif($l=~/\G\$(\w+)/gc){
            my $method=$1;
            if($method=~/^(eq|ne|le|ge|lt|gt)$/){
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
                    my $var=find_var($varname);
                    if($var->{class}){
                        my $subname=$var->{class}."_".$method;
                        my $call_line="$subname, $varname";
                        $arg=~s/^\s+//;
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
                            push @stack, $yield;
                            push @types, "atom";
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
                        push @stack, $yield;
                        push @types, "atom";
                        last;
                    }
                    else{
                        return;
                    }
                }
                my $curfile=MyDef::compileutil::curfile_curline();
                print "[$curfile]\x1b[33m Method \$$method not defined\n\x1b[0m";
                push @stack, "\$$method";
                push @types, "atom-unknown";
            }
        }
        elsif($l=~/\G([\(\[\{])/gc){
            push @stack, $1;
            push @types, undef;
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
            my $found;
            for(my $i=$n-1; $i >=0; $i--){
                if($stack[$i] eq $open){
                    $found=$i;
                    last;
                }
            }
            if(defined $found and $stack[$found] eq $open){
                my $exp=join("", splice(@stack, $found+1));
                pop @stack;
                splice(@types, $found);
                if($types[-1] =~/^atom/ and $stack[-1]!~/^[0-9'"]/){
                    my $primary=pop @stack;
                    pop @types;
                    my $processed;
                    $type="atom-exp";
                    if($open eq '('){
                        if($primary=~/^(sin|cos|tan|asin|acos|atan|atan2|exp|log|log10|pow|sqrt|ceil|floor|fabs)$/){
                            $includes{"<math.h>"}=1;
                            $objects{"libm"}=1;
                        }
                        elsif($primary=~/^(mem|str)[a-z]+$/){
                            $includes{"<string.h>"}=1;
                        }
                        elsif($primary=~/^(malloc|free)$/){
                            $includes{"<stdlib.h>"}=1;
                        }
                        else{
                            if($function_autolist{$primary}){
                                if($MyDef::compileutil::in_autoload){
                                    $autoload=undef;
                                    $autoload_h=0;
                                    if($page->{autoload} eq "write_h"){
                                        if(!$h_hash{"autoload"}){
                                            $autoload=[];
                                            $h_hash{"autoload"}=$autoload;
                                        }
                                        else{
                                            $autoload=$h_hash{"autoload"};
                                        }
                                    }
                                    elsif($page->{autoload} eq "h"){
                                        $autoload_h=1;
                                    }
                                }
                                else{
                                    $autoload=undef;
                                    $autoload_h=0;
                                }
                                if(!$list_function_hash{$primary}){
                                    $list_function_hash{$primary}=1;
                                    push @list_function_list, $primary;
                                    if($autoload){
                                        push @$autoload, "function-$primary";
                                    }
                                }
                                else{
                                    $list_function_hash{$primary}++;
                                }
                            }
                            if($function_defaults{$primary}){
                                if($function_defaults{$primary}=~/^prepend:(.*)/){
                                    if($exp eq ""){
                                        $exp=$1;
                                    }
                                    else{
                                        $exp=$1.",".$exp;
                                    }
                                }
                                elsif($function_defaults{$primary}=~/^append:(.*)/){
                                    if($exp eq ""){
                                        $exp=$1;
                                    }
                                    else{
                                        $exp=$exp.",".$1;
                                    }
                                }
                                else{
                                }
                            }
                        }
                    }
                    elsif($open eq '['){
                        if($exp<0){
                            my $var=find_var($primary);
                            if($var and $var->{dimension}){
                                $token=$primary.'['.$var->{dimension}."$exp".']';
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
                    }
                    if(!$processed){
                        $token=$primary.$open.$exp.$close;
                        if($open eq '['){
                            $token=~s/ +//g;
                        }
                    }
                }
                else{
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
        }
        elsif($l=~/\G=~/gc){
            if($types[-1] =~/^atom/){
                my $atom=pop @stack;
                pop @types;
                my $func="regex";
                my $pat;
                if($l=~/\G\s*(\/(?:[^\/\\]|\\.)*\/\w*)/gc){
                    $pat=$1;
                }
                elsif($l=~/\G\s*(s\/(?:[^\/\\]|\\.)*\/(?:[^\/\\]|\\.)*\/\w*)/gc){
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
                    print "eval error: [$@]\n";
                }
                $token=$condition;
                $type="atom-regex";
            }
            else{
                my $curfile=MyDef::compileutil::curfile_curline();
                print "[$curfile]\x1b[33m =~ missing string variable\n\x1b[0m";
            }
        }
        elsif($l=~/\G(=[=~]?)/gc){
            if($1 eq "=~"){
                if($types[-1] =~/^atom/){
                    my $atom=pop @stack;
                    pop @types;
                    my $func="regex";
                    my $pat;
                    if($l=~/\G\s*(\/(?:[^\/\\]|\\.)*\/\w*)/gc){
                        $pat=$1;
                    }
                    elsif($l=~/\G\s*(s\/(?:[^\/\\]|\\.)*\/(?:[^\/\\]|\\.)*\/\w*)/gc){
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
                        print "eval error: [$@]\n";
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
                $token=$1;
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
                push @types, "atom-exp";
            }
            elsif($token eq ":"){
                my $exp=pop @stack;
                pop @types;
                push @stack, "$exp$token ";
                push @types, "atom-label";
            }
            elsif($token=~/^(.*)=$/ and $1!~/^[!><=]$/){
                $assign=$token;
                if($left){
                    my $curfile=MyDef::compileutil::curfile_curline();
                    print "[$curfile]\x1b[33m Chained assignment not supported [left=$left, assign=$assign]!\n\x1b[0m";
                }
                if(!$1 and @stack==1 and $types[0] eq "atom-("){
                    $left=substr($stack[0], 1, -1);
                    pop @stack;
                    pop @types;
                }
                else{
                    $left=join("", @stack);
                    @stack=();
                    @types=();
                }
                if($assign eq "="){
                    if(%cache){
                        foreach my $t (keys %cache){
                            if($t=~/(\w+)\{(.*)\}/){
                                my ($t1, $t2)=($1, $2);
                                my $var=find_var($t1);
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
            if($types[-1] =~/^op/){
                if($types[-2] !~/^atom/){
                    my $op=pop @stack;
                    pop @types;
                    $token=$op.$token;
                    $type="atom-exp";
                    goto check_exp_precedence;
                }
                else{
                    if($stack[-1] eq ","){
                        $stack[-1]="$stack[-1] ";
                    }
                    elsif($stack[-1]=~/^(eq|ne|lt|le|gt|ge)$/){
                        my $op=pop @stack;
                        pop @types;
                        my $exp=pop @stack;
                        pop @types;
                        my %str_op=(eq=>"==", ne=>"!=", lt=>"<", gt=>">", le=>"<=", ge=>">=");
                        my $op=$str_op{$op};
                        if($type eq "atom-string"){
                            if($token=~/^"(.*)"/){
                                my $len=length($1);
                                $token= "strncmp($exp, $token, $len) $op 0";
                            }
                            else{
                                $token= "strcmp($exp, $token) $op 0";
                            }
                            $type="atom";
                        }
                        else{
                            my $var=find_var($token);
                            if($var and $var->{strlen}){
                                $token="strncmp($exp, $token, $var->{strlen}) $op 0";
                                $type="atom";
                            }
                            else{
                                $token="strcmp($exp, $token) $op 0";
                                $type="atom";
                            }
                        }
                    }
                    elsif($stack[-1]=~/^\S+$/){
                        $stack[-1]=" $stack[-1] ";
                    }
                    push @stack, $token;
                    push @types, $type;
                }
            }
            elsif($types[-1] =~/^atom/){
                if($stack[-1]=~/\w$/){
                    $stack[-1].=" $token";
                }
                else{
                    $stack[-1].=$token;
                    if($types[-1] eq "atom-("){
                        $types[-1] = "atom";
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
        $right=join("", @stack);
    }
    if($assign){
        if($assign eq "="){
            if($context eq "condition"){
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
        else{
            $right= "$left $assign $right";
        }
    }
    if(%cache){
        foreach my $t (keys %cache){
            if($t=~/(\w+)\{(.*)\}/){
                my ($t1, $t2)=($1, $2);
                my $var=find_var($t1);
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
    return $right;
}
sub fmt_string {
    my ($str, $add_newline)=@_;
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
    my @group;
    my $flag_hyphen=0;
    while(1){
        if($str=~/\G$/gc){
            last;
        }
        elsif($str=~/\G%/gc){
            if($str=~/\G%/gc){
                push @fmt_list, '%%';
            }
            elsif($str=~/\G[-+ #]*[0-9]*(\.\d+)?[diufFeEgGxXoscpaAn]/gc){
                push @arg_list, shift @pre_list;
                push @fmt_list, "%$&";
            }
            else{
                push @fmt_list, '%%';
            }
        }
        elsif($str=~/\G\$/gc){
            if($str=~/\G(red|green|yellow|blue|magenta|cyan)/gc){
                push @fmt_list, "\\x1b[$colors{$1}m";
                if($str=~/\G\{/gc){
                    push @group, $1;
                }
            }
            elsif($str=~/\Greset/gc){
                push @fmt_list, "\\x1b[0m";
            }
            elsif($str=~/\G(\w+)/gc){
                my $v=$1;
                if($str=~/\G(\[.*?\])/gc){
                    $v.=$1;
                }
                elsif($str=~/\G(\{.*?\})/gc){
                    $v.=$1;
                    $v=check_expression($v);
                }
                push @arg_list, $v;
                push @fmt_list, get_var_fmt($v, 1);
                if($str=~/\G-/gc){
                }
            }
            elsif($str=~/\G\{(.*?)\}/gc){
                push @arg_list, $1;
                push @fmt_list, get_var_fmt($1, 1);
            }
            else{
                push @fmt_list, '$';
            }
        }
        elsif($str=~/\G\\\$/gc){
            push @fmt_list, '$';
        }
        elsif($str=~/\G\}/gc){
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
        elsif($str=~/\G[^%\$\}]+/gc){
            push @fmt_list, $&;
        }
    }
    if(@pre_list){
        warn "Extra fmt arg list: ", join(", ", @pre_list), "\n";
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
        return ($vcnt, '"'.join('',@fmt_list).'", '.join(', ', @arg_list));
    }
}
sub debug_dump {
    my ($param, $prefix, $out)=@_;
    my %colors=(red=>31,green=>32,yellow=>33,blue=>34,magenta=>35,cyan=>36);
    my @vlist=split /,\s+/, $param;
    my @a1;
    my @a2;
    foreach my $v (@vlist){
        if($v=~/^(\w+):(.*)/){
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
    if($prefix){
        if($prefix=~/(red|green|yellow|blue|magenta|cyan)/){
            push @$out, "printf(\"\x1b[$colors{$prefix}m\");";
            push @$out, "printf(\"    :".join(", ", @a1)."\\n\", ".join(", ", @a2).");";
            push @$out, "printf(\"\x1b[0m\");";
        }
        else{
            push @$out, "fprintf(stdout, \"    :[$prefix] ".join(", ", @a1)."\\n\", ".join(", ", @a2).");";
        }
    }
    else{
        push @$out, "fprintf(stdout, \"    :".join(", ", @a1)."\\n\", ".join(", ", @a2).");";
    }
    $includes{"<stdio.h>"}=1;
}
sub do_assignment {
    my ($left, $right)=@_;
    if(!defined $right){
        my $type=get_var_type($left);
        if($type and $type ne "void"){
            $right=type_default($type);
            push @$out, "$left = $right;";
            return;
        }
        return;
    }
    if(!defined $left){
        return;
    }
    if($debug eq "type"){
        print "\x1b[36m do_assignment: $left = $right\n\x1b[0m";
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
                    do_assignment("$left.$p", $right_list[$i]);
                    $i++;
                }
            }
            elsif($type=~/^struct (\w+)\s*\*$/){
                my $s_list=$structs{$1}->{list};
                my $i=0;
                foreach my $p (@$s_list){
                    do_assignment("$left->$p", $right_list[$i]);
                    $i++;
                }
            }
            elsif($type=~/^(.*?)\s*\*$/){
                for(my $i=0; $i <@right_list; $i++){
                    do_assignment("$left\[$i\]", $right_list[$i]);
                }
            }
            else{
                my $curfile=MyDef::compileutil::curfile_curline();
                print "[$curfile]\x1b[33m tuple assigned to scalar\n\x1b[0m";
                do_assignment($left, $right_list[0]);
            }
        }
        elsif(@right_list=1){
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
                        do_assignment($left_list[$i], "$right.$p");
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
                        do_assignment($left_list[$i], "$right->$p");
                        $i++;
                    }
                }
            }
            elsif($type=~/^(.*?)\s*\*$/){
                for(my $i=0; $i <@right_list; $i++){
                    do_assignment($left_list[$i], "$right\[$i\]");
                }
            }
            else{
                my $curfile=MyDef::compileutil::curfile_curline();
                print "[$curfile]\x1b[33m scalar assigned to tuple\n\x1b[0m";
                for(my $i=0; $i <@right_list; $i++){
                    do_assignment($left_list[$i], $right);
                }
            }
        }
        else{
            for(my $i=0; $i <@left_list; $i++){
                do_assignment($left_list[$i], $right_list[$i]);
            }
        }
        return;
    }
    my $type;
    if($left=~/^([^\(\[]*)\s+(\S+)$/){
        $type=$1;
        $left=$2;
    }
    if($left=~/^(\w+)(.*)/){
        if($protected_var{$1}){
            my $curfile=MyDef::compileutil::curfile_curline();
            print "[$curfile]\x1b[33m Variable $1 protected (unmutable)\n\x1b[0m";
        }
        if(!$2){
            auto_add_var($left, $type, $right);
        }
    }
    else{
    }
    push @$out, "$left = $right;";
    return;
}
sub data_pack {
    my ($param)=@_;
    my @t=split /,\s*/, $param;
    my $buf=shift @t;
    my $fmt=shift @t;
    if(!$buf){
        warn " datapack (pack): buf empty: $param\n";
    }
    my @vlist=@t;
    if($fmt=~/"(.*)"/){
        $fmt=$1;
    }
    my $fmt_pos=0;
    my $buf_pos=0;
    my $fmt_len=length($fmt);
    my $last_var;
    while($fmt_pos<$fmt_len){
        my $var=shift @vlist;
        my $vartype=get_var_type($var);
        my $c=substr($fmt, $fmt_pos, 1);
        if($c eq "s"){
            push @$out, "memcpy($buf+$buf_pos, (const void *)$var, $last_var);";
        }
        elsif($c=~/\d/){
            if($vartype=~/int/){
                if($c==1){
                    push @$out, "*((char *)($buf+$buf_pos))=$var;";
                }
                elsif($c==2){
                    push @$out, "*((short *)($buf+$buf_pos))=$var;";
                }
                elsif($c==4){
                    push @$out, "*((int *)($buf+$buf_pos))=$var;";
                }
            }
            elsif($vartype=~/unsigned/){
                if($c==1){
                    push @$out, "*((unsigned char *)($buf+$buf_pos))=$var;";
                }
                elsif($c==2){
                    push @$out, "*((unsigned short *)($buf+$buf_pos))=$var;";
                }
                elsif($c==4){
                    push @$out, "*((unsigned int *)($buf+$buf_pos))=$var;";
                }
            }
            else{
                print "pack: unhandled type $var - $vartype\n";
            }
            $buf_pos+=$c;
        }
        $fmt_pos++;
        $last_var=$var;
    }
}
sub data_unpack {
    my ($param)=@_;
    my @t=split /,\s*/, $param;
    my $buf=shift @t;
    my $fmt=shift @t;
    if(!$buf){
        warn " datapack (unpack): buf empty: $param\n";
    }
    my @vlist=@t;
    if($fmt=~/"(.*)"/){
        $fmt=$1;
    }
    my $fmt_pos=0;
    my $buf_pos=0;
    my $fmt_len=length($fmt);
    my $last_var;
    while($fmt_pos<$fmt_len){
        my $var=shift @vlist;
        my $vartype=get_var_type($var);
        my $c=substr($fmt, $fmt_pos, 1);
        if($c eq "s"){
            push @$out, "$var=($vartype)($buf+$buf_pos);";
        }
        elsif($c=~/\d/){
            if($vartype=~/int/){
                if($c==1){
                    push @$out, "$var=*((char *)($buf+$buf_pos));";
                }
                elsif($c==2){
                    push @$out, "$var=*((short *)($buf+$buf_pos));";
                }
                elsif($c==4){
                    push @$out, "$var=*((int *)($buf+$buf_pos));";
                }
            }
            elsif($vartype=~/unsigned/){
                if($c==1){
                    push @$out, "$var=*((unsigned char *)($buf+$buf_pos));";
                }
                elsif($c==2){
                    push @$out, "$var=*((unsigned short *)($buf+$buf_pos));";
                }
                elsif($c==4){
                    push @$out, "$var=*((unsigned int *)($buf+$buf_pos));";
                }
            }
            else{
                print "unpack: unhandled type $var - $vartype\n";
            }
            $buf_pos+=$c;
        }
        $fmt_pos++;
        $last_var=$var;
    }
}
sub process_function_std {
    my ($func)=@_;
    my $name=$func->{name};
    my $open=$func->{openblock};
    my $close=$func->{closeblock};
    my $pre=$func->{preblock};
    my $post=$func->{postblock};
    my $ret_type=$func->{ret_type};
    if(!$ret_type){
        $ret_type="void";
        $func->{ret_type}=$ret_type;
    }
    if($func->{ret_type} eq "void" and $func->{ret_var}){
        my $curfile=MyDef::compileutil::curfile_curline();
        print "[$curfile]\x1b[33m Failed to infer function $name return type from [$func->{ret_var}]\n\x1b[0m";
    }
    my $declare=$func->{declare};
    if(!$declare){
        my $param_list=$func->{"param_list"};
        my $param=join(', ', @$param_list);
        $declare="$ret_type $name($param)";
        $func->{declare}=$declare;
    }
    push @$open, $declare."{";
    push @$close, "}";
    push @$close, "NEWLINE";
    close_scope($func, $pre, $post);
    if(@{$func->{var_list}}){
        push @$pre, "NEWLINE";
    }
    foreach my $t (@{$func->{init}}){
        push @$pre, $t;
    }
    foreach my $t (@{$func->{finish}}){
        push @$post, $t;
    }
}
sub add_define {
    my ($name, $var)=@_;
    if($MyDef::compileutil::in_autoload){
        $autoload=undef;
        $autoload_h=0;
        if($page->{autoload} eq "write_h"){
            if(!$h_hash{"autoload"}){
                $autoload=[];
                $h_hash{"autoload"}=$autoload;
            }
            else{
                $autoload=$h_hash{"autoload"};
            }
        }
        elsif($page->{autoload} eq "h"){
            $autoload_h=1;
        }
    }
    else{
        $autoload=undef;
        $autoload_h=0;
    }
    if(!$autoload_h){
        if(!defined $defines{$name}){
            push @define_list, $name;
        }
        else{
            warn "Duplicate define $name: [$defines{$name}] -> [$var]\n";
        }
        $defines{$name}=$var;
        if($autoload){
            push @$autoload, "define-$name";
        }
    }
}
sub add_typedef {
    my ($param)=@_;
    if($MyDef::compileutil::in_autoload){
        $autoload=undef;
        $autoload_h=0;
        if($page->{autoload} eq "write_h"){
            if(!$h_hash{"autoload"}){
                $autoload=[];
                $h_hash{"autoload"}=$autoload;
            }
            else{
                $autoload=$h_hash{"autoload"};
            }
        }
        elsif($page->{autoload} eq "h"){
            $autoload_h=1;
        }
    }
    else{
        $autoload=undef;
        $autoload_h=0;
    }
    if(!$autoload_h){
        if($param=~/(.*)\s+(\w+)\s*$/){
            $typedef_hash{$2}=$1;
            push @typedef_list, $2;
            if($autoload){
                push @$autoload, "typedef-$2";
            }
        }
        elsif($param=~/\(\*\s*(\w+)\)/){
            $typedef_hash{$1}=$param;
            push @typedef_list, $1;
            if($autoload){
                push @$autoload, "typedef-$1";
            }
        }
    }
}
sub start_function {
    my ($funcname, $paramline)=@_;
    my $func=open_function($funcname, $paramline);
    push @function_stack, $cur_function;
    $cur_function=$func;
    push @scope_stack, $cur_scope;
    $cur_scope=$cur_function;
    push @function_list, $func;
    my $fidx=$#function_list;
    MyDef::compileutil::set_named_block("fn$fidx\_open", $func->{openblock});
    MyDef::compileutil::set_named_block("fn$fidx\_pre", $func->{preblock});
    MyDef::compileutil::set_named_block("fn$fidx\_post", $func->{postblock});
    MyDef::compileutil::set_named_block("fn$fidx\_close", $func->{closeblock});
    push @$out, "DUMP_STUB fn$fidx\_open";
    push @$out, "INDENT";
    push @$out, "DUMP_STUB fn$fidx\_pre";
    MyDef::compileutil::set_current_macro("FunctionName", $funcname);
    return $fidx;
}
sub finish_function {
    my ($fidx)=@_;
    push @$out, "DUMP_STUB fn$fidx\_post";
    push @$out, "DEDENT";
    push @$out, "DUMP_STUB fn$fidx\_close";
}
sub start_function_block {
    my ($funcname, $paramline)=@_;
    if(!$lamda_functions{$funcname}){
        my $block=[];
        my $old_out=MyDef::compileutil::set_output($block);
        my $fidx = start_function($funcname, $paramline);
        $lamda_functions{$funcname}=$block;
        push @list_function_list, $funcname;
        $list_function_hash{$funcname}=1;
        return {out=>$old_out, fidx=>$fidx};
    }
    else{
        return undef;
    }
}
sub finish_function_block {
    my ($context)=@_;
    finish_function($context->{fidx});
    MyDef::compileutil::set_output($context->{out});
    $cur_function=pop @function_stack;
    $cur_scope=pop @scope_stack;
    my $level=@function_stack;
    if($level==0){
        @case_stack=();
        undef $case_state;
        if($case_wrap){
            push @$out, @$case_wrap;
            undef $case_wrap;
        }
    }
}
1;
