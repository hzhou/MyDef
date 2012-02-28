use MyDef::dumpout;
package MyDef::output_xs;
my $debug;
my $cur_page_name;
my @xs_globals;
use MyDef::dumpout;
use MyDef::regex;
my $cur_indent;
our $cur_function;
my $debug;
our %includes;
sub add_include {
    my $l=shift;
    my @tlist=split /,/, $l;
    foreach my $t (@tlist){
        if($t=~/(\S+)/){
            $includes{"<$1>"}=1;
        }
    }
}
our $define_id_base=1000;
our %defines;
our %enums;
our @enum_list;
our %structs;
our @struct_list;
our $global_type={};
our $global_flag={};
our @global_list;
our %functions;
our @function_declare_list;
our %var_type_cast;
our @declare_list;
our @initcodes;
my %function_flags;
sub set_function_flag {
    my ($k, $v)=@_;
    $function_flags{$k}=$v;
}
our @func_var_hooks;
our @func_extra_init;
our @func_extra_release;
our @func_pre_assign;
our @func_post_assign;
our %fntype;
our %type_name=(
    c=>"char",
    i=>"int",
    j=>"int",
    k=>"int",
    m=>"int",
    n=>"int",
    f=>"float",
    d=>"double",
    count=>"int",
);
our %type_prefix=(
    n=>"int",
    ui=>"unsigned int",
    c=>"char",
    "uc"=>"unsigned char",
    b=>"int",
    s=>"char *",
    v=>"unsigned char *",
    f=>"float",
    d=>"double",
    "time"=>"time_t",
    "file"=>"FILE *",
    "strlen"=>"STRLEN",
    "has"=>"int",
    "is"=>"int",
);
our %stock_functions=(
    "printf"=>1,
);
my %lib_include=(
    glib=>"glib.h",
);
my %type_include=(
    time_t=>"time.h",
);
my %text_include=(
    "printf"=>"stdio.h",
    "sin|cos|sqrt"=>"math.h",
    "malloc"=>"stdlib.h",
    "strlen"=>"string.h",
    "strdup"=>"string.h",
    "fstat"=>"sys/stat.h",
);
sub register_type_prefix {
    my ($k, $v)=@_;
    $type_prefix{$k}=$v;
}
our %misc_vars;
our $except;
sub declare_var {
    my ($var, $type)=@_;
    $cur_function->{var_type}->{$var}=$type;
}
sub single_block {
    my ($t, $out)=@_;
    push @$out, "$t\{";
    push @$out, "INDENT";
    push @$out, "BLOCK";
    push @$out, "DEDENT";
    push @$out, "}";
    return "NEWBLOCK";
}
sub regex_init_code {
    print "regex_init_code\n";
    $includes{"<stdlib.h>"}=1;
    if(!$structs{"VMInst"}){
        push @struct_list, "VMInst";
        $structs{"VMInst"}=make_struct("VMInst", "int opcode, int c, int x, int y");
        MyDef::regex::add_regex_vm_code(\@initcodes);
    }
    if(!$enums{"RegexOp"}){
        push @enum_list, "RegexOp";
        $enums{"RegexOp"}="Char, Match, Jmp, Split, AnyChar";
    }
}
sub parse_condition {
    my ($param, $out)=@_;
    if($param=~/^\s*(!)?\/(.*)\//){
        my $var=$misc_vars{regex_var};
        my $pos=$misc_vars{regex_pos};
        my $end=$misc_vars{regex_end};
        my $t= MyDef::regex::parse_regex_match($2, $out, \&regex_init_code, $var, $pos, $end);
        if($1){
            return "!($t)";
        }
        else{
            return $t;
        }
    }
    elsif($param=~/(\w+)->\{(.*)\}/){
        return hash_check($out, $1, $2);
    }
    else{
        return $param;
    }
}
sub allocate {
    my ($out, $dim, $param2)=@_;
    $includes{"<stdlib.h>"}=1;
    my $init;
    if($dim=~/(.*),\s*(.*)/){
        $dim=$1;
        $init=$2;
    }
    if($dim=~/[+-]/){
        $dim="($dim)";
    }
    my @plist=split /,\s+/, $param2;
    foreach my $p (@plist){
        if($p){
            func_add_var($p);
            $cur_function->{var_flag}->{$p}="retained";
            my $type=pointer_type(get_var_type($p));
            if($dim == 1){
                push @$out, "$p=($type*)malloc(sizeof($type));";
                if($t->{constructor}){
                    push @$out, "$1_constructor($p);";
                }
            }
            else{
                push @$out, "$p=($type*)malloc($dim*sizeof($type));";
                if($t->{constructor}){
                    func_add_var("i", "int");
                    push @$out, "for(i=0;i<$dim;i++)$1_constructor($p\[i]);";
                }
            }
            if($misc_vars{mu_enable}){
                my $destructor="NULL";
                if($type=~/struct (\w+)/){
                    my $t=$structs{$1}->[0];
                    if($t->{destructor}){
                        $destructor="&$1_destructor";
                    }
                }
                push @$out, "mu_add((void*)$p, sizeof($type), $dim, $destructor);";
            }
            if($misc_vars{"debug_mem"}==1){
                push @$out, "printf(\"Mem \%d - $p \%d $type [%x]\\n\", mu_lastmem, $dim, $p);";
            }
            if(defined $init and $init ne ""){
                func_add_var("i", "int");
                push @$out, "for(i=0;i<$dim;i++){";
                foreach my $p (@plist){
                    if($p){
                        push @$out, "    $p\[i]=$init;";
                    }
                }
                push @$out, "}";
            }
        }
    }
}
sub debug_dump {
    my ($param, $prefix, $out)=@_;
    my @vlist=split /,\s+/, $param;
    my @a1;
    my @a2;
    foreach my $v(@vlist){
        push @a2, $v;
        my $type=get_c_type($v);
        if($type=~/^(float|double)/){
            push @a1,"$v=\%g";
        }
        elsif($type=~/^int/){
            push @a1,"$v=\%d";
        }
        elsif($type=~/^char \*/){
            push @a1, "$v=\%s";
        }
        elsif($type=~/^char/){
            push @a1,"$v=\%d";
        }
        else{
            print "debug_dump: unhandled $v - $type\n";
        }
    }
    if($prefix){
        push @$out, "fprintf(stderr, \"    :[$prefix] ".join(", ", @a1)."\\n\", ".join(", ", @a2).");";
    }
    else{
        push @$out, "fprintf(stderr, \"    :".join(", ", @a1)."\\n\", ".join(", ", @a2).");";
    }
    $includes{"<stdio.h>"}=1;
}
sub comma_split {
    my $l=shift;
    my @t;
    my $i0=0;
    my $n=length($l);
    my @wait_stack;
    my $cur_wait;
    my %pairlist=("'"=>"'", '"'=>'"', '('=>')', '['=>']', '{'=>'}');
    for(my $i=0;$i<$n;$i++){
        if(substr($l, $i) eq "\\"){
            $i++;
            next;
        }
        if($cur_wait){
            if(substr($l, $i) eq $cur_wait){
                $cur_wait=pop @wait_stack;
                next;
            }
            if(substr($l, $i) =~ /['"\(\[\{]/){
                $cur_wait=$pairlist{substr($l, $i)};
                push @wait_stack, $cur_wait;
                next;
            }
        }
        else{
            if(substr($l, $i) =~ /['"\(\[\{]/){
                $cur_wait=$pairlist{substr($l, $i)};
                next;
            }
            if(substr($l, $i) eq ","){
                if($i>$i0){
                    push @t, substr($l, $i0, $i-$i0-1);
                }
                else{
                    push @t, "";
                }
                $i0=$i+1;
                next;
            }
        }
    }
    if($n>$i0){
        push @t, substr($l, $i0, $n-$i0);
    }
    return @t;
}
sub check_assignment {
    my ($l, $out)=@_;
    if($cur_function and $$l=~/^[^'"]*=/){
        my $tl=$$l;
        $tl=~s/;+\s*$//;
        if($tl=~/^\s*(.*?\w)\s*=\s*([^=].*)/){
            undef $$l;
            my ($left, $right)=($1, $2);
            my @left=split /,\s*/, $left;
            my @right=comma_split($right);
            for(my $i=0; $i<=$#left; $i++){
                do_assignment($left[$i], $right[$i], $out);
            }
        }
    }
}
sub do_assignment {
    my ($left, $right, $out)=@_;
    if($debug){ print "do_assignment: $left = $right\n"; };
    my $type;
    if($left=~/^(.*?)\s+(\S+)$/){
        $type=$1;
        $left=$2;
    }
    if($left=~/^\w+$/){
        func_add_var($left, $type, $right);
        $type=get_var_type($left);
        func_var_assign($type, $left, $right, $out);
    }
    elsif($left=~/(\w+)(\.|->)(\w+)/){
        my $v1=$1;
        my $v2=$3;
        if($v1=~/^gns_(\w+)/){
            global_namespace($v1);
            add_struct($v1, $v2, $right);
        }
        my $stype=get_struct_element_type($v1, $v2);
        func_var_assign($stype, $left, $right, $out);
    }
    else{
        push @$out, "$left = $right;";
    }
}
sub global_namespace{
    my $v=shift;
    my $stname="ns$v";
    if(!$structs{$stname}){
        push @struct_list, $stname;
        $structs{$stname}=make_struct($stname, "");
        $type_name{$v}="struct $stname";
        global_add_var($v);
    }
}
sub last_exp {
    my $l=shift;
    my $tlen=length($l);
    my $i=$tlen-1;
    if(substr($l, $i, 1) eq ')'){
        my $level=1;
        while($i>1){
            $i--;
            if(substr($l, $i, 1) eq ')'){$level++;};
            if(substr($l, $i, 1) eq '('){$level--;};
            if($level==0){last;};
        }
    }
    else{
        while($i>0){
            if(substr($l, $i, 1) eq ']'){
                my $level=1;
                while($i>1){
                    $i--;
                    if(substr($l, $i, 1) eq ']'){$level++;};
                    if(substr($l, $i, 1) eq '['){$level--;};
                    if($level==0){last;};
                }
                $i--;
                next;
            }
            elsif(substr($l, $i-1, 2) eq '->'){
                $i-=2;
                next;
            }
            elsif(substr($l, $i, 1)=~/[0-9a-zA-Z_.]/){
                $i--;
                next;
            }
            last;
        }
        if(substr($l, $i, 1)!~/[a-zA-Z_.]/){
            $i++;
        }
    }
    my $t0=substr($l, 0, $i);
    my $t3=substr($l, $i, $tlen-$i);
    return ($t0, $t3);
}
sub make_struct {
    my ($name, $param)=@_;
    my @struct;
    my (@init, @exit);
    push @struct, {constructor=>undef, destructor=>undef};
    my @plist=split /,\s+/, $param;
    foreach my $p (@plist){
        my $element={};
        push @struct, $element;
        if($p=~/^@/){
            $element->{needfree}=1;
            $p=$';
        }
        my $init;
        if($p=~/(.*?)(\S+)\s*=\s*(.*)/){
            $p="$1$2";
            $init=1;
            push @init, "p->$2=$3;";
        }
        if($p=~/(.*\S)\s+(\S+)\s*$/){
            $element->{type}=$1;
            $element->{name}=$2;
            $p=$2;
        }
        else{
            $element->{name}=$p;
            if($p eq "next" or $p eq "prev"){
                $element->{type}="struct $name\_node *";
                if(!@init){
                    push @init, "p->$p=NULL;";
                }
            }
            elsif($p eq "list"){
                $element->{type}="struct $name\_node";
            }
            elsif($p eq "tail"){
                $element->{type}="struct $name\_node *";
                if(!@init){
                    push @init, "p->$p=&p->list;";
                }
            }
            elsif($fntype{$p}){
                $element->{type}="function";
            }
            elsif($p){
                my $type=get_c_type($p);
                $element->{type}=$type;
            }
        }
        my $type=$element->{type};
        my $name=$element->{name};
        foreach my $fh (@func_var_hooks){
            if($fh->{var_check}->($type)){
                my $init=$fh->{var_init}->($type, "p->$name");
                if($init){
                    push @init, "p->$p=$init;";
                }
                my $exit=$fh->{var_release}->($type, "p->$name", "skipcheck");
                if($exit){
                    foreach my $l (@$exit){
                        push @exit, $l;
                    }
                }
            }
        }
    }
    if(@init){
        $struct[0]->{constructor}=\@init;
    }
    if(@exit){
        $struct[0]->{destructor}=\@exit;
    }
    return \@struct;
}
sub add_struct {
    my ($stname, $pname)=@_;
    my $struct=$structs{$stname};
    if($struct){
        foreach my $p(@$struct){
            if($p->{name} eq $pname){
                return;
            }
        }
        if($fntype{$pname}){
            push @$struct, {type=>"function", name=>$pname};
        }
        else{
            my $type=get_c_type($pname);
            push @$struct, {type=>$type, name=>$pname};
        }
    }
}
sub get_struct_element_type {
    my ($svar, $evar)=@_;
    my $stype=get_var_type($svar);
    if($stype=~/struct\s+(\w+)/){
        my $struc=$structs{$1};
        foreach my $p(@$struc){
            if($p->{name} eq $evar){
                return $p->{type};
            }
        }
    }
    return "void";
}
sub struct_free {
    my ($out, $ptype, $name)=@_;
    my $type=pointer_type($ptype);
    if($type=~/struct\s+(\w+)/ and $structs{$1}){
        foreach my $p (@{$structs{$1}}){
            if($p->{needfree}){
                struct_free($out, $p->{type}, "$name"."->".$p->{name});
            }
        }
    }
    push @$out, "free($name);";
}
sub open_function {
    my ($fname, $t)=@_;
    my @plist=split /,/, $t;
    my $func= {param_list=>[], var_list=>[], var_type=>{}, var_flag=>{}, var_decl=>{}, init=>[], finish=>[]};
    while(my ($k, $v)=each %function_flags){
        $func->{$k}=$v;
    }
    $func->{name}=$fname;
    my $pbuf=$func->{param_list};
    my $var_type=$func->{var_type};
    foreach my $p(@plist){
        if($p=~/(\S.*)\s+(\S+)\s*$/){
            push @$pbuf, "$1 $2";
            $var_type->{$2}=$1;
        }
        else{
            if($fntype{$p}){
                push @$pbuf, $fntype{$p};
                $var_type->{$p}="function";
            }
            else{
                my $t= get_c_type($p);
                push @$pbuf, "$t $p";
                $var_type->{$p}=$t;
            }
        }
    }
    if($func->{name}){
        my $name=$func->{name};
        push @function_declare_list, $name;
        $functions{$name}=$func;
    }
    $cur_function=$func;
    my $fidx=MyDef::dumpout::add_function($func);
    return $fidx;
}
sub open_closure {
    my ($open, $close)=@_;
    my $func= {var_list=>[], var_type=>{}, var_flag=>{}, var_decl=>{}};
    $func->{openblock}=[$open];
    $func->{closeblock}=[$close];
    $cur_function=$func;
    my $fidx=MyDef::dumpout::add_function($func);
    return $fidx;
}
sub get_var_type {
    my $name=shift;
    if($cur_function and $cur_function->{var_type}->{$name}){
        return $cur_function->{var_type}->{$name};
    }
    else{
        return $global_type->{$name};
    }
}
sub get_var_flag {
    my $name=shift;
    if($cur_function->{var_flag}->{$name}){
        return $cur_function->{var_flag}->{$name};
    }
    else{
        return $global_flag->{$name};
    }
}
sub global_add_var {
    my ($name, $type, $value)=@_;
    if($global_type->{$name}){
        return;
    }
    my ($tail, $array);
    if($name=~/(\S+)(=.*)/){
        $name=$1;
        $tail=$2;
    }
    if($name=~/(\w+)\[(.*)\]/){
        $name=$1;
        $array=$2;
    }
    if(!$type){
        if($fntype{$name}){
            $type="function";
        }
        elsif($value){
            $type=infer_c_type($value);
        }
        if(!$type){
            $type=get_c_type($name);
        }
    }
    if($array){
        $type=pointer_type($type);
        $global_type->{$name}="$type *";
    }
    else{
        $global_type->{$name}=$type;
    }
    my $init_line;
    if($type eq "function"){
        $init_line=$fntype{$name};
    }
    elsif($array){
        $init_line="$type $name\[$array]$tail";
    }
    else{
        $init_line="$type $name$tail";
    }
    push @global_list, $init_line;
}
sub func_add_var {
    my ($name, $type, $value)=@_;
    if(!$cur_function){
        return;
    }
    if(get_var_type($name)){
        return;
    }
    my $var_list=$cur_function->{var_list};
    my $var_decl=$cur_function->{var_decl};
    my $var_type=$cur_function->{var_type};
    my ($tail, $array);
    if($name=~/(\S+)(=.*)/){
        $name=$1;
        $tail=$2;
    }
    if($name=~/(\w+)\[(.*)\]/){
        $name=$1;
        $array=$2;
    }
    push @$var_list, $name;
    if(!$type){
        if($fntype{$name}){
            $type="function";
        }
        elsif($value){
            $type=infer_c_type($value);
        }
        if(!$type){
            $type=get_c_type($name);
        }
    }
    if($debug){
        print "func_add_var: $name - $type - $array\n";
    }
    if($array){
        $type=pointer_type($type);
        $var_type->{$name}="$type *";
    }
    else{
        $var_type->{$name}=$type;
    }
    if(!$tail){
        my $init_value=func_var_init($name, $type);
        if($init_value){
            if($array){
                func_add_var("i", "int");
                push @{$cur_function->{init}}, "for(i=0;i<$array;i++){$name\[i] = $init_value;}";
            }
            else{
                $tail=" = $init_value";
            }
        }
    }
    my $init_line;
    if($type eq "function"){
        $init_line=$fntype{$name};
    }
    elsif($array){
        $init_line="$type $name\[$array]$tail";
    }
    else{
        $init_line="$type $name$tail";
    }
    $var_decl->{$name}=$init_line;
    if($type=~/struct (\w+)$/){
        if($structs{$1}->[0]->{constructor}){
            if($array){
                func_add_var("i", "int");
                push @{$cur_function->{init}}, "for(i=0;i<$array;i++){$1_constructor(&$name\[i]);}";
            }
            else{
                push @{$cur_function->{init}}, "$1_constructor(&$name);";
            }
        }
    }
}
sub func_return {
    my ($l, $out)=@_;
    if(!$cur_function->{ret_type}){
        if($l=~/return\s+(.*)/){
            my $t=$1;
            if($t=~/(\w+)/){
                $cur_function->{ret_var}=$1;
            }
            $cur_function->{ret_type}=infer_c_type($t);
        }
        else{
            $cur_function->{ret_type}="void";
        }
    }
    if($cur_indent<=1){
        $cur_function->{has_return}=1;
    }
    func_var_release($out);
}
sub func_var_init {
    my ($v, $type)=@_;
    my $init;
    foreach my $fh (@func_var_hooks){
        if($fh->{var_check}->($type)){
            $init=$fh->{var_init}->($v, $type);
        }
    }
    if($init){
        return $init;
    }
}
sub func_var_release {
    my ($out)=@_;
    my $ret_type=$cur_function->{ret_type};
    my $ret_var=$cur_function->{ret_var};
    my $var_list=$cur_function->{var_list};
    my $var_type=$cur_function->{var_type};
    if(@$var_list and @func_var_hooks){
        foreach my $name (@$var_list){
            my $type=$var_type->{$name};
            if($name ne $ret_var){
                foreach my $fh (@func_var_hooks){
                    if($fh->{var_check}->($type)){
                        my $exit=$fh->{var_release}->($type, $name);
                        if($exit){
                            foreach my $l (@$exit){
                                push @$out, $l;
                            }
                        }
                    }
                }
            }
        }
    }
}
sub func_var_assign {
    my ($type, $name, $val, $out)=@_;
    if($debug){print "func_var_assign: $type $name = $val\n"};
    my $done_out;
    if(@func_var_hooks){
        foreach my $fh (@func_var_hooks){
            if($fh->{var_check}->($type)){
                $fh->{var_pre_assign}->($type, $name, $val, $out);
                push @$out, "$name = $val;";
                $fh->{var_post_assign}->($type, $name, $val, $out);
                $done_out=1;
                last;
            }
        }
    }
    if(!$done_out){
        push @$out, "$name = $val;";
    }
}
sub mu_enable {
    $misc_vars{mu_enable}=1;
    push @func_var_hooks, {var_check=>\&mu_var_check, var_init=>\&mu_var_init, var_pre_assign=>\&mu_pre_assign, var_post_assign=>\&mu_post_assign, var_release=>\&mu_release};
}
sub mu_var_check {
    my ($type)=@_;
    if($type=~/\*$/){
        return 1;
    }
    else{
        return 0;
    }
}
sub mu_var_init {
    return "NULL";
}
sub mu_pre_assign {
    my ($type, $name, $val, $out)=@_;
    if($var_flag->{$name} eq "retained"){
        my $var_flag=$cur_function->{var_flag};
        push @$out, "if($name){mu_release($name);}";
        $var_flag->{$name}=0;
    }
}
sub mu_post_assign {
    my ($type, $name, $val, $out)=@_;
    print "mu_post_assign: $type $name = $val\n";
    my $var_flag=$cur_function->{var_flag};
    print "mu_post_assign: $name = $val\n";
    if($val=~/^\s*(NULL|0)\s*$/i){
    }
    elsif($val=~/^\s*(\w+)(.*)/){
        $var_flag->{$name}="retained";
        print "retain $name\n";
        my $name=$1;
        my $tail=$2;
        if($tail=~/^\s*\(/ and MyDef::is_sub($name)){
        }
        else{
            push @$out, "mu_retain($name);";
        }
    }
}
sub mu_release {
    my ($type, $name, $skipcheck)=@_;
    if($skipcheck){
        return mu_release_0($type, $name, $out);
    }
    else{
        my $var_flag=$cur_function->{var_flag};
        if($func->{mu_skip}->{$name}){
        }
        elsif($var_flag->{$name} eq "retained"){
            return mu_release_0($type, $name, $out);
        }
    }
}
sub mu_release_0 {
    my ($type, $name)=@_;
    my @out;
    push @out, "if($name){";
    push @out, "INDENT";
    if($type=~/^struct\s+(\w+)\s*$/){
        my $t=$structs{$1}->[0];
        if($t->{destructor}){
            push @out, "$1_destructor($name);";
        }
    }
    push @out, "mu_release($name);";
    push @out, "DEDENT";
    push @out, "}";
    return \@out;
}
sub struct_set {
    my ($struct_type, $struct_var, $val, $out)=@_;
    my $struct=$structs{$struct_type};
    my @vals=split /,\s*/, $val;
    for(my $i=0; $i<=$#vals; $i++){
        my $sname=$struct->[$i]->{name};
        do_assignment("$struct_var\->$sname", $vals[$i], $out);
    }
}
sub struct_get {
    my ($struct_type, $struct_var, $var, $out)=@_;
    my $struct=$structs{$struct_type};
    my @vars=split /,\s*/, $var;
    for(my $i=0; $i<=$#vars; $i++){
        my $sname=$struct->[$i]->{name};
        do_assignment( $vars[$i],"$struct_var\->$sname", $out);
    }
}
sub hash_check {
    my ($out, $h, $name)=@_;
    func_add_var("p_$h", "struct $h\_node *");
    push @$out, "p_$h=hash_lookup_$h($name);";
    return "p_$h\->s_text";
}
sub hash_assign {
    my ($out, $h, $name, $val)=@_;
    my $p="p_$h";
    func_add_var("p_$h", "struct $h\_node *");
    push @$out, "p_$h=hash_lookup_$h($name);";
    push @$out, "if(p_$h\->s_text==NULL){p_$h->s_text=strdup($name);}";
    struct_set("$h\_node", "p_$h", $val, $out);
}
sub hash_fetch {
    my ($out, $h, $name, $var)=@_;
    func_add_var("p_$h", "struct $h\_node *");
    push @$out, "p_$h=hash_lookup_$h($name);";
    push @$out, "if(p_$h\->s_text){";
    struct_get("$h\_node", "p_$h", $var, $out);
    push @$out, "}";
    $except="else";
}
sub get_array_type {
    my ($var)=@_;
    if(my $type = get_var_type($var)){
        return $type;
    }
    elsif($var_type_cast/{$var}){
        return $var_type_cast{$var};
    }
    else{
        return $var;
    }
}
sub array_push {
    my ($out, $v, $val)=@_;
    my $a=get_array_type($v);
    func_add_var("p_$a", "struct $a\_node *");
    push @$out, "p_$a=list_push_$a();";
    struct_set("$a\_node", "p_$a", $val, $out);
}
sub array_unshift {
    my ($out, $v, $val)=@_;
    my $a=get_array_type($v);
    func_add_var("p_$a", "struct $a\_node *");
    push @$out, "p_$a=list_unshift_$a();";
    struct_set("$a\_node", "p_$a", $val, $out);
}
sub array_pop {
    my ($out, $v, $var)=@_;
    my $a=get_array_type($v);
    if($var){
        func_add_var("p_$a", "struct $a\_node *");
        push @$out, "p_$a=list_pop_$a();";
        struct_get("$a\_node", "p_$a", $var, $out);
    }
    else{
        push @$out, "list_pop_$a();";
    }
}
sub array_shift {
    my ($out, $v, $var)=@_;
    my $a=get_array_type($v);
    if($var){
        func_add_var("p_$a", "struct $a\_node *");
        push @$out, "p_$a=list_shift_$a();";
        struct_get("$a\_node", "p_$a", $var, $out);
    }
    else{
        push @$out, "list_shift_$a();";
    }
}
sub infer_c_type {
    my $val=shift;
    if($val=~/^[+-]?\d+\./){
        return "float";
    }
    elsif($val=~/^[+-]?\d/){
        return "int";
    }
    elsif($val=~/^"/){
        $cur_function->{ret_type}="char *";
    }
    elsif($val=~/^'/){
        $cur_function->{ret_type}="char";
    }
    elsif($val=~/(\w+)/){
        return get_var_type($1);
    }
}
sub get_c_type_word {
    my $name=shift;
    if($debug){
        print "get_c_type_word: [$name] -> $type_prefix{$name}\n";
    }
    if($name=~/^([a-z]+)/){
        $prefix=$1;
        if($type_prefix{$prefix}){
            return $type_prefix{$prefix};
        }
        elsif(substr($prefix, 0, 1) eq "t"){
            return get_c_type_word(substr($prefix,1));
        }
        elsif(substr($prefix, 0, 1) eq "p"){
            return get_c_type_word(substr($prefix,1)).'*';
        }
        elsif($name=~/^st(\w+)/){
            return "struct $1";
        }
        else{
        }
    }
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
    elsif($name=~/([a-zA-Z]+)_(.*)/){
        my $t1=$1;
        my $t2=$2;
        my $t=get_c_type_word($t1);
        if(!$t){
            if($t1=~/^\w+$/){
                $type=get_c_type_word($t2);
            }
        }
        elsif($t=~/^\*/){
            $type=get_c_type_word($t2).$t;
        }
        else{
            $type=$t;
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
    while($name=~/\[.*?\]/g){
        $type=pointer_type($type);
    }
    if($type_include{$type}){
        add_include($type_include{$type});
    }
    return $type;
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
sub get_c_fmt {
    my $name=shift;
    my $type=get_var_type($name);
    if($type eq "int"){
        return "%d";
    }
    elsif($type eq "char"){
        return "%c";
    }
    elsif($type eq "char *"){
        return "%s";
    }
}
sub get_interface {
    return (\&init_page, \&parsecode, \&modeswitch, \&dumpout);
}
sub init_page {
    my ($page)=@_;
    my $ext="xs";
    if($page->{type}){
        $ext=$page->{type};
    }
    $cur_page_name=$page->{pagename};
    register_type_prefix("hv", "HV*");
    register_type_prefix("av", "AV*");
    register_type_prefix("sv", "SV*");
    %includes=();
    if($MyDef::def->{"macros"}->{"use_double"}){
        $type_name{f}="double";
        $type_prefix{f}="double";
    }
    MyDef::dumpout::init_funclist();
    return ($ext, "sub");
}
sub modeswitch {
    my ($pmode, $mode, $out)=@_;
    if($mode eq "xs" and $pmode ne "xs"){
        push @$out, "INCLUDE_BLOCK xs_start";
        set_function_flag("xs_mode", 1);
        set_function_flag("skip_declare", 1);
    }
    if($mode=~/(\w+)-(.*)/){
        my $fname=$1;
        my $t=$2;
        if($fname eq "n_main"){
            $fname="main";
        }
        my $fidx=open_function($fname, $t);
        push @$out, "OPEN_FUNC_$fidx";
        $cur_indent=0;
        return 1;
    }
}
sub parsecode {
    my ($l, $mode, $out)=@_;
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
    }
    if($l=~/^\s*\$(if|while|elif|elsif|elseif)\s*(.*)/){
        $l="\$$1 ".translate_perl_cond($2, $out);
    }
    elsif($l=~/^\$foreach\s+(\w+)\s+in\s+(av_\w+)/){
        my $v_i=$1;
        my $v_av=$2;
        func_add_var("i");
        func_add_var($v_i);
        func_add_var("t_psv");
        push @$out, "for(i=0; i<=av_len($v_av); i++){";
        push @$out, "INDENT";
        push @$out, "t_psv=av_fetch($v_av, i, 0);";
        translate_scalar($out, $v_i, get_var_type($v_i), "*t_psv");
        push @$out, "BLOCK";
        push @$out, "DEDENT";
        push @$out, "}";
        return "NEWBLOCK";
    }
    elsif($l=~/^\$foreach\s+\((\w+),\s*(\w+)\)\s+in\s+(hv_\w+)/){
        my ($v_name, $v_val, $v_hv)=($1, $2, $3);
        func_add_var("t_n");
        func_add_var($v_name);
        func_add_var($v_val);
        func_add_var("t_sv");
        push @$out, "t_n=hv_iterinit($v_hv);";
        push @$out, "while((t_sv=hv_iternextsv($v_hv, &$v_name, &t_n))){";
        push @$out, "INDENT";
        translate_scalar($out, $v_val, get_var_type($v_val), "t_sv");
        push @$out, "BLOCK";
        push @$out, "DEDENT";
        push @$out, "}";
        return "NEWBLOCK";
    }
    elsif($l=~/^\$getparam\s+(.*)/){
        my @vlist=split /,\s+/, $1;
        my $j=0;
        foreach my $v (@vlist){
            my $type=get_c_type($v);
            func_add_var($v);
            translate_scalar($out, $v, $type, "ST($j)");
            $j++;
        }
        return;
    }
    while(my ($k, $v)=each %text_include){
        if($l=~/$k/){
            if($v=~/(\S+)/){
                $includes{"<$1>"}=1;
            }
        }
    }
    my $should_return=1;
    if($l=~/^\s*PRINT\s+(.*)$/){
        $includes{"<stdio.h>"}=1;
        my @fmt=split /(\$[0-9a-zA-Z_\[\]]+)/, $l;
        my @var;
        for(my $j=0; $j<@fmt; $j++){
            if($fmt[$j]=~/^\$(\w+)(.*)/){
                push @var, "$1$2";
                $fmt[$j]=get_c_fmt($1);
            }
        }
        if(@var){
            push @$out, "printf(\"".join('', @fmt)."\", ".join(', ', @var).");";
        }
        else{
            push @$out, "printf(\"$l\");";
        }
    }
    elsif($l=~/^\s*\$(\w+)\((.*)\)\s+(.*)$/){
        my ($func, $param1, $param2)=($1, $2, $3);
        if($func eq "allocate"){
            allocate($out, $param1, $param2);
        }
        elsif($func eq "dump"){
            debug_dump($param2, $param1, $out);
        }
        elsif($func eq "register_prefix"){
            $param2=~s/^\s+//;
            $param2=~s/\s+$//;
            $type_prefix{$param1}=$param2;
        }
        elsif($func eq "register_name"){
            $param2=~s/^\s+//;
            $param2=~s/\s+$//;
            $type_name{$param1}=$param2;
        }
        elsif($func eq "register_include"){
            $param2=~s/^\s+//;
            $param2=~s/\s+$//;
            $type_include{$param1}.=",$param2";
        }
        elsif($func eq "struct"){
            if(!$structs{$param1}){
                push @struct_list, $param1;
                $structs{$param1}=make_struct($param1, $param2);
                $type_prefix{"st$param1"}="struct $param1";
            }
        }
        elsif($func eq "get_type"){
            my $type=get_var_type($param2);
            return "SET:$param1=$type";
        }
        elsif($func eq "get_pointer_type"){
            my $type=pointer_type(get_var_type($param2));
            return "SET:$param1=$type";
        }
        elsif($func eq "enum"){
            if(!$enums{$param1}){
                push @enum_list, $param1;
                $enums{$param1}=$param2;
            }
        }
        elsif($func eq "enumbit"){
            my $base=0;
            my @plist=split /,\s+/, $param2;
            foreach my $t(@plist){
                $defines{"$param1\_$t"}=0x1<<$base;
                $base++;
            }
        }
        else{
            $should_return=0;
        }
    }
    elsif($l=~/^\s*\$(\w+)\s*(.*)$/){
        my ($func, $param)=($1, $2);
        while($param =~ /(\S+)\s+eq\s+"(.*?)"/){
            my ($var, $key)=($1, $2);
            my $keylen=length($key);
            $param=$`."strncmp($var, \"$key\", $keylen)==0".$';
        }
        if($func eq "block"){
            return single_block($param, $out);
        }
        elsif($func eq "allocate"){
            allocate($out, 1, $param);
        }
        elsif($func =~/^except/){
            return single_block($except, $out);
        }
        elsif($func =~ /^(if|while|switch|(el|els|else)if)$/){
            my $name=$1;
            if($2){
                $name="else if";
            }
            my $p=parse_condition($param, $out);
            return single_block("$name($p)", $out);
        }
        elsif($func eq "else"){
            return single_block("else", $out);
        }
        elsif($func eq "for"){
            if($param=~/(\w+)=(.*?):(.*?)(:.*)?$/){
                my ($var, $i0, $i1, $step)=($1, $2, $3, $4);
                func_add_var($var, undef, $i0);
                my $stepclause;
                if($step){
                    my $t=substr($step, 1);
                    if($t eq "-1"){
                        $stepclause="$var=$i0;$var>$i1;$var--";
                    }
                    elsif($t=~/^-/){
                        $stepclause="$var=$i0;$var>$i1;$var=$var$t";
                    }
                    elsif($t eq "1"){
                        $stepclause="$var=$i0;$var<$i1;$var++";
                    }
                    else{
                        $stepclause="$var=$i0;$var<$i1;$var+=$t";
                    }
                }
                else{
                    $stepclause="$var=$i0;$var<$i1;$var++";
                }
                return single_block("for($stepclause)", $out);
            }
            else{
                print "\$for mismatch [$param]\n";
            }
        }
        elsif($func eq "return_type"){
            $cur_function->{ret_type}=$param;
        }
        elsif($func eq "parameter"){
            my @plist=split /,\s*/, $param;
            my $fplist=$cur_function->{param_list};
            foreach my $p(@plist){
                push @$fplist, $p;
                if($p=~/(.*)\s+(\w+)\s*$/){
                    $cur_function->{var_type}->{$2}=$1;
                }
            }
        }
        elsif($func eq "mu_skip"){
            my @plist=split /,\s*/, $param;
            foreach my $p(@plist){
                $cur_function->{mu_skip}->{$p}=1;
            }
        }
        elsif($func eq "mu_enable"){
            mu_enable();
        }
        elsif($func eq "include"){
            my @flist=split /,\s+/, $param;
            foreach my $f(@flist){
                if($f=~/\.h$/){
                    $includes{"\"$f\""}=1;
                }
                else{
                    $includes{"<$f.h>"}=1;
                }
            }
        }
        elsif($func eq "declare"){
            push @declare_list, $param;
        }
        elsif($func eq "define") {
            push @$out, "#define $param";
        }
        elsif($func eq "uselib"){
            my @flist=split /,\s+/, $param;
            foreach my $f(@flist){
                $includes{"lib$f"}=1;
                if($lib_include{$f}){
                    add_include($lib_include{$f});
                }
            }
        }
        elsif($func eq "fntype"){
            if($param=~/^.*?\(\s*\*\s*(\w+)\s*\)/){
                $fntype{$1}=$param;
            }
        }
        elsif($func eq "debug_mem"){
            push @$out, "debug_mem=1;";
            $misc_vars{"debug_mem"}=1;
        }
        elsif($func eq "namespace"){
            my @vlist=split /,\s+/, $param;
            foreach my $v(@vlist){
                global_namespace($v);
            }
        }
        elsif($func eq "global"){
            my @vlist=split /,\s+/, $param;
            foreach my $v(@vlist){
                if($v=~/^(\S.*)\s+(\S+)$/){
                    global_add_var($2, $1);
                }
                else{
                    global_add_var($v);
                }
            }
        }
        elsif($func eq "globalinit"){
            global_add_var($param);
        }
        elsif($func eq "local"){
            my @vlist=split /,\s+/, $param;
            foreach my $v(@vlist){
                if($v=~/^(\S.*)\s+(\S+)$/){
                    func_add_var($2, $1);
                }
                else{
                    func_add_var($v);
                }
            }
        }
        elsif($func eq "localinit"){
            func_add_var($param);
        }
        elsif($func eq "new"){
            my @plist=split /,\s+/, $param;
            foreach my $p(@plist){
                if($p){
                    func_add_var($p);
                    my $type=pointer_type(get_var_type($p));
                    $includes{"<stdlib.h>"}=1;
                    push @$out, "$p=($type*) malloc(sizeof($type));";
                }
            }
        }
        elsif($func eq "free"){
            my @plist=split /,\s+/, $param;
            foreach my $p(@plist){
                my $ptype=get_var_type($p);
                struct_free($out, $ptype, $p);
            }
        }
        elsif($func eq "regex_setup"){
            my @plist=split /,\s+/, $param;
            $misc_vars{regex_var}=$plist[0];
            $misc_vars{regex_pos}=$plist[1];
            $misc_vars{regex_end}=$plist[2];
        }
        elsif($func eq "dump"){
            debug_dump($param, undef, $out);
        }
        elsif($func eq "getopt"){
            $includes{"<stdlib.h>"}=1;
            $includes{"<unistd.h>"}=1;
            my @vlist=split /,\s+/, $param;
            my $cstr='';
            foreach my $v(@vlist){
                if($v=~/(\w+):(\w+)(=.*)?/){
                    func_add_var($1);
                    if(substr($1, 0, 2) eq "b_"){
                        $cstr.=$2;
                        push @$out, "$1=0;";
                    }
                    elsif($3){
                        push @$out, "$1$3;";
                        $cstr.="$2::";
                    }
                    else{
                        $cstr.="$2:";
                    }
                }
            }
            push @$out, "opterr = 1;";
            func_add_var("c", "char");
            push @$out, "while ((c=getopt(argc, argv, \"$cstr\"))!=-1){";
            push @$out, "    switch(c){";
            foreach my $v(@vlist){
                if($v=~/(\w+):(\w+)/){
                    push @$out, "        case '$2':";
                    my $type=get_var_type($1);
                    if(substr($1, 0, 2) eq "b_"){
                        push @$out, "            $1=1;";
                    }
                    elsif($type eq "char *"){
                        push @$out, "            $1=optarg;";
                    }
                    elsif($type eq "int" or $type eq "long"){
                        push @$out, "            $1=atoi(optarg);";
                    }
                    elsif($type eq "float" or $type eq "double"){
                        push @$out, "            $1=atof(optarg);";
                    }
                }
                push @$out, "            break;";
            }
            push @$out, "    }";
            push @$out, "}";
        }
        else{
            $should_return=0;
        }
    }
    else{
        $should_return=0;
    }
    if($should_return){
        return;
    }
    if($l=~/(\S+)=(\w+)->\{(.*)\}/){
        my ($var, $hv, $key)=($1, $2, $3);
        if($key=~/^['"](.*)['"]/){
            $key=$1;
        }
        my $keylen=length($key);
        my $vartype;
        if($var=~/(\S+)\.(\S+)/){
            $vartype=get_c_type($2);
        }
        else{
            func_add_var($var);
            $vartype=get_var_type($var);
        }
        func_add_var("t_psv");
        push @$out, "t_psv=hv_fetch($hv, \"$key\", $keylen, 0);";
        translate_tpsv($out, $var, $vartype);
        return;
    }
    elsif($l=~/(\S+)=(\w+)->\[(.*)\]/){
        my ($var, $av, $key)=($1, $2, $3);
        my $vartype;
        if($var=~/(\S+)\.(\S+)/){
            $vartype=get_c_type($2);
        }
        else{
            func_add_var($var);
            $vartype=get_var_type($var);
        }
        func_add_var("t_psv");
        push @$out, "t_psv=av_fetch($av, $key, 0);";
        translate_tpsv($out, $var, $vartype);
        return;
    }
    elsif($l=~/\((\w+)->\{(.*)\}\)/){
        my ($pre, $hv, $key, $post)=($`, $1, $2, $');
        if($key=~/^['"](.*)['"]/){
            $key=$1;
        }
        my $keylen=length($key);
        push @$out, "$pre(hv_exists($hv, $keylen))$post";
        return;
    }
    if($l=~/^return\b/){
        func_return($l, $out);
    }
    elsif($l=~/^SOURCE_INDENT/){
        $cur_indent++;
    }
    elsif($l=~/^SOURCE_DEDENT/){
        $cur_indent--;
    }
    while($l=~/\^([234])/){
        my $t_p=$1;
        my $t_tail=$';
        my ($t_head, $t_exp)=last_exp($`);
        my $t_trunk="$t_exp*" x ($t_p-1);
        $t_trunk.=$t_exp;
        $l="$t_head($t_trunk)$t_tail";
    }
    if($l=~/^(push|unshift|pop|shift)\s+(\w+),\s*(.*)/){
        if($1 eq "push"){
            $l=array_push($out, $2, $3);
        }
        elsif($1 eq "unshift"){
            $l=array_unshift($out, $2, $3);
        }
        elsif($1 eq "pop"){
            $l=array_pop($out, $2);
        }
        elsif($1 eq "shift"){
            $l=array_shift($out, $2);
        }
    }
    if($l=~/^(\w+)\s+(.*)$/ and ($functions{$1} or $stock_functions{$1})){
        my $fn=$1;
        my $t=$2;
        $t=~s/;\s*$//;
        $t=~s/\s+$//;
        $l="$fn($t);";
    }
    if($l=~/^\s*$/){
    }
    elsif($l=~/(for|while|if|else if)\s*\(.*\)\s*$/){
    }
    elsif($l!~/[:\{\};]\s*$/){
        $l.=";";
    }
    if($l=~/^[^'"]*=/){
        if($l=~/^(\w+)->\{(.*)\}\s*=\s*(.+)/){
            $l=hash_assign($out, $1, $2, $3);
        }
        elsif($l=~/^(\w+)\s*=\s*(\w+)->\{(.*)\}/){
            $l=hash_fetch($out, $2, $3, $1);
        }
        elsif($l=~/^(\w+)\s*=\s*(shift|pop)\s+(\w+)/){
            if($2 eq "shift"){
                $l=array_shift($out, $3, $1);
            }
            elsif($2 eq "pop"){
                $l=array_pop($out, $3, $1);
            }
        }
        check_assignment(\$l, $out);
    }
    if($l){
        push @$out, $l;
    }
}
sub dumpout {
    my ($f, $out)=@_;
    my $dump={out=>$out,f=>$f};
    my $funclist=MyDef::dumpout::get_func_list();
    foreach my $func (@$funclist){
        if($func->{xs_mode}){
            my (@t0, @t1, @pre, @post);
            $func->{openblock}=\@t0;
            $func->{closeblock}=\@t1;
            $func->{preblock}=\@pre;
            $func->{postblock}=\@post;
            my $name=$func->{name};
            if($name){
                my $ret_type=$func->{'ret_type'};
                if(!$ret_type){$ret_type="void";};
                my $paramlist=$func->{'param_list'};
                my @param_name_list;
                foreach my $p(@$paramlist){
                    if($p=~/(\w+)\s*$/){
                        push @param_name_list, $1;
                    }
                }
                my $param_name_list_str=join(",", @param_name_list);
                push @t0, "$ret_type";
                push @t0, "$name($param_name_list_str)";
                if(@$paramlist){
                    push @pre, "INDENT";
                    foreach my $p (@$paramlist){
                        push @pre, "$p;";
                    }
                    push @pre, "DEDENT";
                }
            }
            my $varlist=$func->{'var_list'};
            if(@$varlist){
                push @pre, "PREINIT:";
                push @pre, "INDENT";
                foreach my $v (@$varlist){
                    push @pre, "$v;";
                }
                push @pre, "DEDENT";
            }
            push @pre, "PPCODE:";
            push @pre, "INDENT";
            foreach my $tl (@{$func->{init}}){
                push @pre, $tl;
            }
            foreach my $tl (@{$func->{finish}}){
                push @post, $tl;
            }
            if($name){
                push @post, "DEDENT";
                push @t1, "NEWLINE";
            }
        }
        else{
            my $name=$func->{name};
            if(!$func->{openblock}){
                my @t;
                my $ret_type=$func->{ret_type};
                if(!$ret_type){$ret_type="void";};
                my $paramlist=$func->{'param_list'};
                my $param=join(', ', @$paramlist);
                push @t,  "$ret_type $name($param){";
                $func->{openblock}=\@t;
            }
            if(!$func->{closeblock}){
                my @t;
                push @t, "}";
                push @t, "NEWLINE";
                $func->{closeblock}=\@t;
            }
            my (@pre, @post);
            $func->{preblock}=\@pre;
            $func->{postblock}=\@post;
            my $var_decl=$func->{var_decl};
            my $var_list=$func->{var_list};
            if(@$var_list){
                foreach my $v (@$var_list){
                    push @pre, "$var_decl->{$v};";
                }
                push @pre, "NEWLINE";
            }
            foreach my $tl (@{$func->{init}}){
                push @pre, $tl;
            }
            if(!$func->{has_return}){
                $cur_function=$func;
                func_var_release(\@post);
            }
            foreach my $tl (@{$func->{finish}}){
                push @post, $tl;
            }
        }
    }
    my @dump_init;
    $dump->{block_init}=\@dump_init;
    unshift @$out, "INCLUDE_BLOCK block_init";
    my $cnt=0;
    while(my ($k, $t)=each %includes){
        if($k!~/^lib/){
            push @dump_init, "#include $k\n";
            $cnt++;
        }
    }
    if($cnt>0){
        push @dump_init, "\n";
    }
    my $cnt=0;
    while(my ($k, $t)=each %defines){
        push @dump_init, "#define $k $t\n";
        $cnt++;
    }
    if($cnt>0){
        push @dump_init, "\n";
    }
    my $cnt=0;
    foreach my $name (@enum_list){
        my $t=$enums{$name};
        push @dump_init, "enum $name {$t};\n";
        $cnt++;
    }
    if($cnt>0){
        push @dump_init, "\n";
    }
    foreach my $name (@struct_list){
        push @dump_init, "struct $name {\n";
        my @plist=@{$structs{$name}};
        my $info=$plist[0];
        my $i=0;
        foreach my $p (@plist){
            $i++;
            if($i==1){
                next;
            }
            if($p->{type} eq "function"){
                push @dump_init, "\t".$fntype{$p->{name}}.";\n";
            }
            else{
                push @dump_init, "\t$p->{type} $p->{name};\n";
            }
        }
        push @dump_init, "};\n\n";
    }
    my $cnt=0;
    foreach my $t (@function_declare_list){
        my $func=$functions{$t};
        if(!$func->{skip_declare}){
            my $name=$func->{name};
            my $ret_type=$func->{'ret_type'};
            if(!$ret_type){$ret_type="void";};
            my $paramlist=$func->{'param_list'};
            my $param=join(', ', @$paramlist);
            push @dump_init, "$ret_type $name($param);\n";
            $cnt++;
        }
    }
    if($cnt>0){
        push @dump_init, "\n";
    }
    foreach my $l (@declare_list){
        push @dump_init, "$l\n";
    }
    if(@declare_list){
        push @dump_init, "\n";
    }
    my $cnt=0;
    foreach my $name (@struct_list){
        my $info=$structs{$name}->[0];
        if($info->{"constructor"}){
            push @dump_init, "void $name\_constructor(struct $name* p){\n";
            foreach my $l(@{$info->{constructor}}){
                push @dump_init, "    $l\n";
            }
            push @dump_init, "}\n";
            $cnt++;
        }
        if($info->{"destructor"}){
            push @dump_init, "void $name\_destructor(struct $name* p){\n";
            foreach my $l(@{$info->{destructor}}){
                push @dump_init, "    $l\n";
            }
            push @dump_init, "}\n";
            $cnt++;
        }
    }
    if($cnt>0){
        push @dump_init, "\n";
    }
    my $cnt=0;
    foreach my $v (@global_list){
        if($v=~/^[SHA]V/){
            push @xs_globals, "$v;\n";
        }
        else{
            push @dump_init, "$v;\n";
            $cnt++;
        }
    }
    if($cnt>0){
        push @dump_init, "\n";
    }
    foreach my $l (@initcodes){
        push @dump_init, "$l\n";
    }
    if(@initcodes){
        push @dump_init, "\n";
    }
    my @block_xs_start;
    $dump->{xs_start}=\@block_xs_start;
    push @block_xs_start, "#include \"EXTERN.h\"\n";
    push @block_xs_start, "#include \"perl.h\"\n";
    push @block_xs_start, "#include \"XSUB.h\"\n";
    push @block_xs_start, "\n";
    push @block_xs_start, "#include \"ppport.h\"\n";
    push @block_xs_start, "\n";
    foreach my $l (@xs_globals){
        push @block_xs_start, $l;
    }
    push @block_xs_start, "\n";
    push @block_xs_start, "MODULE = $cur_page_name\t\tPACKAGE = $cur_page_name\n";
    push @block_xs_start, "\n";
    MyDef::dumpout::dumpout($dump);
}
sub translate_scalar {
    my ($out, $var, $vartype, $sv)=@_;
    if($vartype eq "int"){
        push @$out, "$var = SvIV($sv);";
    }
    elsif($vartype eq "double" or $vartype eq "float"){
        push @$out, "$var = SvNV($sv);";
    }
    elsif($vartype eq "char *"){
        func_add_var("t_strlen");
        push @$out, "$var = SvPV($sv, t_strlen);";
        push @$out, "$var\[t_strlen\] = '\\0';";
    }
    elsif($vartype =~ /^([SAH]V\*)/){
        push @$out, "$var = ($1)SvRV($sv);";
    }
    else{
        print "translate_scalar: unhandled $var - $vartype\n";
    }
}
sub translate_null {
    my ($out, $var, $vartype)=@_;
    if($vartype !~/int|float|double/){
        push @$out, "    $var = NULL;";
    }
    elsif($vartype eq "int"){
        push @$out, "    $var = 0;";
    }
    else{
        push @$out, "    $var = 0.0;";
    }
}
sub translate_tpsv {
    my ($out, $var, $vartype)=@_;
    push @$out, "if(t_psv){";
    push @$out, "INDENT";
    translate_scalar($out, $var, $vartype, "*t_psv");
    push @$out, "DEDENT";
    push @$out, "}";
    push @$out, "else{";
    translate_null($out, $var, $vartype);
    push @$out, "}";
}
sub translate_perl_cond {
    my ($l, $out)=@_;
    if($l=~/^\s*(\w+)->\{(.+)\}\s*$/){
        my ($hv, $key)=($1, $2);
        my $keylen=length($key);
        my $tl="hv_exists($hv, \"$key\", $keylen)";
        return $tl;
    }
    elsif($l=~/^\s*(\w+)->\[(.+)\]\s*$/){
        my ($hv, $key)=($1, $2);
        my $tl="SvTRUE(*(av_fetch($hv, $key, 0)))";
        return $tl;
    }
    else{
        return $l;
    }
}
1;
