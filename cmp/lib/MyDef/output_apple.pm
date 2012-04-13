use MyDef::dumpout;
package MyDef::output_apple;
my $debug;
my $mode;
my $out;
my %view_hash;
my %imports=("UIKit/UIKit.h"=>1);
my %classes;
my $cur_class;
my %method_hash;
my $method_idx=1;
my $class_default;
my %view_hash;
my %view_id_hash;
my %controller_hash;
my @cur_method_stack;
my @cur_class_stack;
my $animate_block_depth=0;
my $animate_need_completion=0;
my %viewitems;
sub res_collect {
    my ($field, $from)=@_;
    if($from){
        while(my ($k, $v)=each %$from){
            if(!$field->{$k}){
                $field->{$k}=$v;
            }
        }
    }
}
sub collect_class_field {
    my ($name)=@_;
    my $field=$class_default->{$name};
    if(!$field){
        return $class_default->{Default};
    }
    else{
        while($field->{super}){
            my $super=$class_default->{$field->{super}};
            $field->{super}=undef;
            res_collect($field, $super);
        }
        res_collect($field, $class_default->{Default});
        return $field;
    }
}
sub parse_animation_param {
    my $param=shift;
    my @plist=split /,\s*/, $param;
    if(@plist>1){
        $animate_need_completion++;
        my @options;
        for(my $i=1; $i<@plist; $i++){
            push @options, "UIViewAnimationOption$plist[$i]";
        }
        $param="$plist[0] delay:0 options:".join('|', @options);
    }
    return $param;
}
sub newclass_spec {
    my ($init, $spec)=@_;
    if($init=~/\$2/){
        my @speclist=split /,\s*/, $spec;
        for(my $i=1; $i-1<@speclist; $i++){
            $init=~s/\$$i/$speclist[$i-1]/;
        }
    }
    else{
        $init=~s/\$1/$spec/;
    }
    return $init;
}
sub nsstring {
    my $s=shift;
    if($s=~/^"(.*)"/){
        return "@\"$1\"";
    }
    elsif($s =~/^nss_/){
        return $s;
    }
    else{
        return "@\"$s\"";
    }
}
sub nsnumber {
    my $s=shift;
    if($s=~/^\d/){
        if($s=~/\./){
            return "[NSNumber numberWithFloat:$s]";
        }
        else{
            return "[NSNumber numberWithInt:$s]";
        }
    }
    else{
        my $type=get_c_type($s);
        if($type =~/^int$/){
            return "[NSNumber numberWithInt:$s]";
        }
        elsif($type =~/^(float|double)$/){
            return "[NSNumber numberWithFloat:$s]";
        }
        else{
            return $s;
        }
    }
}
sub load_view_config {
    my ($f, $itemhash)=@_;
    my $item;
    open In, $f or return;
    while(<In>){
        if(/^#/){
        }
        elsif(/^(\w+)/){
            $item={};
            $itemhash->{$1}=$item;
        }
        elsif(/^\s+(\w+):\s*(.*)/){
            $item->{$1}=$2;
        }
    }
    close In;
}
sub addview {
    my ($out, $name, $parent)=@_;
    if(!$viewitems{$name}){
        warn "Missing layout item $name\n";
    }
    my $main=$viewitems{"main"};
    my $v=$viewitems{$name};
    my $type=$v->{type}?$v->{type}:"UIView";
    my $x=$v->{x};
    my $y=$v->{y};
    my $w=$v->{width};
    my $h=$v->{height};
    new_object($out, $name, $type, "CGRectMake($x, $y, $w, $h)");
    if($v->{background}){
        if($v->{background}=~/\.png/){
            push @$out, "$name.backgroundColor=[UIColor colorWithPatternImage:[UIImage ImageNamed:@\"$v->{background}\"]]";
        }
        elsif($v->{background}=~/#(..)(..)(..)(..)/){
            push @$out, "$name.backgroundColor=[UIColor colorWithRed:$1/255.0 green:$2/255.0 blue:$3/255.0 alpha:$4/255.0]";
        }
    }
    if(!$parent){
        push @$out, "self.view = $view";
    }
    else{
        push @$out, "[$parent addSubview:$name]";
    }
    if($v->{children}){
        my @tlist=split /,\s*/, $v->{children};
        foreach my $t (@tlist){
            addview($out, $t, $name);
        }
    }
}
sub new_object {
    my ($out, $v, $class, $spec)=@_;
    $spec=~s/^,?\s*//;
    my $init="init";
    my $field;
    if($classes{$class}){
        $field=$MyDef::def->{fields}->{$classes{$class}->{super}};
    }
    else{
        $field=$MyDef::def->{fields}->{$class};
        if($field->{class}){
            $class=$field->{class};
        }
    }
    if($v=~/^@(.*)/){
        $v=$1;
        $cur_class->{properties}->{$1}="$class *";
    }
    elsif($v!~/[.]/){
        func_add_var($v, "$class *");
    }
    if($field->{create_spec}){
        my $create=newclass_spec($field->{create_spec}, $spec);
        push @$out, "$v = [$class $create];";
    }
    else{
        if(!$spec){
            while($field){
                if($field->{init_default}){
                    last;
                }
                else{
                    $field=$MyDef::def->{fields}->{$field->{super}};
                }
            }
            if($field){
                $init=$field->{init_default};
            }
        }
        else{
            while($field){
                if($field->{init_spec}){
                    last;
                }
                else{
                    $field=$MyDef::def->{fields}->{$field->{super}};
                }
            }
            if($field){
                $init=newclass_spec($field->{init_spec}, $spec);
            }
            else{
                $init=$spec;
            }
        }
        push @$out, "$v = [[$class alloc] $init];";
    }
    if($class=~/EAGLContext/){
        $imports{"QuartzCore/QuartzCore.h"}=1;
        $imports{"OpenGLES/EAGL.h"}=1;
        if($init=~/OpenGLES1/){
            $imports{"OpenGLES/ES1/gl.h"}=1;
            $imports{"OpenGLES/ES1/glext.h"}=1;
        }
        if($init=~/OpenGLES2/){
            $imports{"OpenGLES/ES2/gl.h"}=1;
            $imports{"OpenGLES/ES2/glext.h"}=1;
        }
    }
}
use MyDef::dumpout;
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
    "printf|perror"=>"stdio.h",
    "malloc"=>"stdlib.h",
    "str(len|dup|cpy)"=>"string.h",
    "\\bopen\\("=>"fcntl.h",
    "sin|cos|sqrt"=>"math.h",
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
sub parse_condition {
    my ($param, $out)=@_;
    if($param=~/^(\S+)\s*(!~|=~)\s*\/(.*)\//){
        my ($var, $eq, $pattern)=($1, $2, $3);
        my ($pos, $end);
        if($var=~/(.*)\[(.*)\]/){
            ($var, $pos)=($1, $2);
        }
        else{
            ($pos, $end)=(0, 0);
        }
        my $t= parse_regex_match($pattern, $out, $var, $pos, $end);
        if($eq =~/!~/){
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
            func_add_var($p);
            $cur_function->{var_flag}->{$p}="retained";
            my $type=pointer_type(get_var_type($p));
            my ($init, $exit);
            if($type=~/struct (\w+)/){
                $init=@{$structs{$1}->{hash}->{"-init"}};
                $exit=@{$structs{$1}->{hash}->{"-exit"}};
            }
            if($dim == 1){
                push @$out, "$p=($type*)malloc(sizeof($type));";
                if($init){
                    push @$out, "$1_constructor($p);";
                }
            }
            else{
                push @$out, "$p=($type*)malloc($dim*sizeof($type));";
                if($init){
                    func_add_var("i", "int");
                    push @$out, "for(i=0;i<$dim;i++)$1_constructor($p\[i]);";
                }
            }
            if($global_type->{mu_total_mem}){
                push @$out, "mu_total_mem+=(float)$dim*sizeof($type)/1e6;";
            }
            if($global_type->{p_memlist}){
                push @$out, "mu_add_pointer((void*)$p, \"$p\", $dim*sizeof($type));";
            }
            if($misc_vars{mu_enable}){
                my $destructor="NULL";
                if($exit){
                    $destructor="&$1_destructor";
                }
                push @$out, "mu_add((void*)$p, sizeof($type), $dim, $destructor);";
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
        my $c=substr($l, $i, 1);
        if($c eq "\\"){
            $i++;
            next;
        }
        if($cur_wait){
            if($c eq $cur_wait){
                $cur_wait=pop @wait_stack;
                next;
            }
            if($c =~ /['"\(\[\{]/){
                $cur_wait=$pairlist{$c};
                push @wait_stack, $cur_wait;
                next;
            }
        }
        else{
            if($c =~ /['"\(\[\{]/){
                $cur_wait=$pairlist{$c};
                next;
            }
            if($c eq ","){
                if($i>$i0){
                    push @t, substr($l, $i0, $i-$i0);
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
        if($tl=~/^\s*\((.*?\w)\)\s*=\s*\((.*)\)/){
            undef $$l;
            my ($left, $right)=($1, $2);
            my @left=split /,\s*/, $left;
            my @right=comma_split($right);
            for(my $i=0; $i<=$#left; $i++){
                do_assignment($left[$i], $right[$i], $out);
            }
        }
        elsif($tl=~/^\s*(.*?\w)\s*=\s*([^=].*)/){
            undef $$l;
            my ($left, $right)=($1, $2);
            do_assignment($left, $right, $out);
        }
    }
}
sub do_assignment {
    my ($left, $right, $out)=@_;
    if($debug eq "type"){
        print "do_assignment: $left = $right\n";
    }
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
        my $stype=get_struct_element_type($v1, $v2);
        func_var_assign($stype, $left, $right, $out);
    }
    else{
        push @$out, "$left=$right;";
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
sub declare_struct {
    my ($name, $param)=@_;
    my ($s_list, $s_hash);
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
        push @struct_list, $name;
    }
    my @plist=split /,\s+/, $param;
    foreach my $p (@plist){
        my ($m_name, $type, $needfree);
        if($p=~/^\s*$/){
            next;
        }
        elsif($p=~/(-\w+)=>(.*)/){
            $s_hash->{$1}=$2;
            next;
        }
        elsif($p=~/^@/){
            $needfree=1;
            $p=$';
        }
        if($p=~/(.*?)(\S+)\s*=\s*(.*)/){
            $p="$1$2";
            push @$s_init, "p->$2=$3;";
        }
        if($p=~/(.*\S)\s+(\S+)\s*$/){
            $type=$1;
            $m_name=$2;
            $p=$2;
        }
        else{
            $m_name=$p;
            if($fntype{$p}){
                $type="function";
            }
            elsif($p){
                $type=get_c_type($p);
            }
        }
        foreach my $fh (@func_var_hooks){
            if($fh->{var_check}->($type)){
                my $init=$fh->{var_init}->($type, "p->$m_name");
                if($init){
                    push @$s_init, "p->$p=$init;";
                }
                my $exit=$fh->{var_release}->($type, "p->$m_name", "skipcheck");
                if($exit){
                    foreach my $l (@$exit){
                        push @$s_exit, $l;
                    }
                }
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
sub get_struct_element_type {
    my ($svar, $evar)=@_;
    my $stype=get_var_type($svar);
    if($stype=~/struct\s+(\w+)/){
        my $struc=$structs{$1};
        if($struc->{hash}->{$evar}){
            return $struc->{hash}->{$evar};
        }
    }
    return "void";
}
sub struct_free {
    my ($out, $ptype, $name)=@_;
    my $type=pointer_type($ptype);
    if($type=~/struct\s+(\w+)/ and $structs{$1}){
        $s_list=$structs{$1}->{list};
        $s_hash=$structs{$1}->{hash};
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
    my ($fname, $t)=@_;
    my @plist=split /,/, $t;
    my $func= {param_list=>[], var_list=>[], var_type=>{}, var_flag=>{}, var_decl=>{}, init=>[], finish=>[]};
    while(my ($k, $v)=each %function_flags){
        $func->{$k}=$v;
    }
    $func->{name}=$fname;
    my $pbuf=$func->{param_list};
    my $var_type=$func->{var_type};
    foreach my $p (@plist){
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
        $type=get_c_type($name);
        if($fntype{$name}){
            $type="function";
        }
        if($value){
            my $val_type=infer_c_type($value);
            if($debug eq "type" and $type ne $val_type){
                print "infer_type: $type -- $val_type\n";
            }
            if(!$type or $type eq "void"){
                if($val_type and $val_type ne "void"){
                    $type = $val_type;
                }
            }
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
    if(defined $value){
        $init_line.="=$value";
    }
    push @global_list, $init_line;
}
sub func_add_var {
    my ($name, $type, $value)=@_;
    if(!$cur_function){
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
    if(get_var_type($name)){
        return;
    }
    my $var_list=$cur_function->{var_list};
    my $var_decl=$cur_function->{var_decl};
    my $var_type=$cur_function->{var_type};
    push @$var_list, $name;
    if(!$type){
        $type=get_c_type($name);
        if($fntype{$name}){
            $type="function";
        }
        if($value){
            my $val_type=infer_c_type($value);
            if($debug eq "type" and $type ne $val_type){
                print "infer_type: $type -- $val_type\n";
            }
            if(!$type or $type eq "void"){
                if($val_type and $val_type ne "void"){
                    $type = $val_type;
                }
            }
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
        my $s_init=$structs{$1}->{hash}->{"-init"};
        if(@$s_init){
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
        if($debug eq "type"){
            print "Check ret_type: $cur_function->{name} [$l] -> $cur_function->{ret_type}\n";
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
                push @$out, "$name=$val;";
                $fh->{var_post_assign}->($type, $name, $val, $out);
                $done_out=1;
                last;
            }
        }
    }
    if(!$done_out){
        push @$out, "$name=$val;";
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
    my $var_flag=$cur_function->{var_flag};
    if($val=~/^\s*(NULL|0)\s*$/i){
    }
    elsif($val=~/^\s*(\w+)(.*)/){
        my $v_name=$1;
        my $v_tail=$2;
        if($v_tail=~/^\s*\(/ and MyDef::is_sub($v_name)){
            $var_flag->{$name}="retained";
        }
        else{
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
sub get_list_type {
    my ($var)=@_;
    if(my $type = get_var_type($var)){
        if($type=~/struct (\w+)/){
            return $1;
        }
    }
    print "Warning: $var not a list type\n";
    return undef;
}
sub list_push {
    my ($out, $v, $val)=@_;
    my $name=get_list_type($v);
    if($name){
        func_add_var("p_$name", "struct $name\_node *");
        push @$out, "p_$name=$name\_push($v);";
        struct_set("$name\_node", "p_$1", $val, $out);
    }
}
sub list_unshift {
    my ($out, $v, $val)=@_;
    my $name=get_list_type($v);
    if($name){
        func_add_var("p_$name", "struct $name\_node *");
        push @$out, "p_$name=$name\_unshift($v);";
        struct_set("$name_node", "p_$name", $val, $out);
    }
}
sub list_pop {
    my ($out, $v, $var)=@_;
    my $name=get_list_type($v);
    if($var){
        func_add_var("p_$name", "struct $name\_node *");
        push @$out, "p_$name=$name\_pop($v);";
        struct_get("$name\_node", "p_$name", $var, $out);
    }
    else{
        push @$out, "$name\_pop($v);";
    }
}
sub list_shift {
    my ($out, $v, $var)=@_;
    my $name=get_list_type($v);
    if($var){
        func_add_var("p_$name", "struct $name\_node *");
        push @$out, "p_$name=$name\_pop($v);";
        struct_get("$name\_node", "p_$name", $var, $out);
    }
    else{
        push @$out, "$name\_pop($v);";
    }
}
sub list_foreach {
    my ($out, $iv, $v)=@_;
    my $name=get_list_type($v);
    func_add_var("$iv", "struct $name\_node *");
    return "PARSE:&call dlist_each, $v, $iv";
}
sub infer_c_type {
    my $val=shift;
    if($debug eq "type"){
        print "infer_c_type: [$val]\n";
    }
    if($val=~/^[+-]?\d+\./){
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
    elsif($val=~/(\w+)(.*)/){
        my $tail=$2;
        my $type=get_var_type($1);
        if(!$type){
            $type=get_c_type($1);
        }
        my $check_tail=1;
        while($check_tail){
            $check_tail=0;
            if($type=~/struct (\w+)/){
                if($structs{$1}){
                    my $s_hash=$structs{$1}->{hash};
                    if($tail=~/^(->|\.)(\w+)/){
                        $tail=$';
                        $type=$s_hash->{$2};
                        $check_tail=1;
                    }
                }
                else{
                    return;
                }
            }
            if($type=~/\*\s*$/){
                if($tail=~/^\[.*?\]/){
                    $tail=$';
                    $type=~s/\s*\*\s*$//;
                    $check_tail=1;
                }
            }
        }
        return $type;
    }
}
sub get_c_type_word {
    my $name=shift;
    if($debug eq "type"){
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
    if($debug eq "type"){
        print "get_c_type:   $name: $type\n";
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
sub parse_regex_match {
    my ($re, $out, $var, $pos, $end)=@_;
    my @str_pool;
    while($re=~/\$(\S+)\((.*?)\)/){
        push @str_pool, {s=>$1, len=>$2};
        $re=$`."\\".$#str_pool.$';
    }
    my $regex=parse_regex($re);
    my ($startstate, $straight)=build_nfa($regex);
    if($straight){
        my $p=["and"];
        my @threadstack;
        push @threadstack, {state=>$startstate, offset=>0, output=>$p};
        while(my $thread=pop @threadstack){
            my $s=$thread->{state};
            my $off=$thread->{offset};
            my $rout=$thread->{output};
            while(1){
                my $position;
                if(!$pos){
                    $position=$off;
                }
                elsif($pos=~/^\d+/){
                    $position=$pos+$off;
                }
                elsif($off){
                    $position="$pos+$off";
                }
                else{
                    $position=$pos;
                }
                my @str_buffer;
                while($s->{c} !~ /^(Match|Split|AnyChar|Class|-..|\\\d)/){
                    push @str_buffer, $s->{c};
                    $s=$s->{"out1"};
                }
                my $n=@str_buffer;
                if($n>2){
                    my $s=join '', @str_buffer;
                    push @$rout, "strncmp($var+$position, \"$s\", $n)==0";
                    $off+=$n;
                    if(!$pos){
                        $position=$off;
                    }
                    elsif($pos=~/^\d+/){
                        $position=$pos+$off;
                    }
                    elsif($off){
                        $position="$pos+$off";
                    }
                    else{
                        $position=$pos;
                    }
                }
                else{
                    for(my $i=0;$i<$n;$i++){
                        push @$rout, "$var\[$position\]=='$str_buffer[$i]'";
                        $off++;
                        if(!$pos){
                            $position=$off;
                        }
                        elsif($pos=~/^\d+/){
                            $position=$pos+$off;
                        }
                        elsif($off){
                            $position="$pos+$off";
                        }
                        else{
                            $position=$pos;
                        }
                    }
                }
                if($s->{c} eq "Match"){
                    last;
                }
                elsif($s->{c} eq "Split"){
                    my ($s1, $s2)=(["and"], ["and"]);
                    push @$rout, ["or", $s1, $s2];
                    push @threadstack, {state=>$s->{"out1"}, offset=>$off, output=>$s1};
                    push @threadstack, {state=>$s->{"out2"}, offset=>$off, output=>$s2};
                    last;
                }
                elsif($s->{c} eq "AnyChar"){
                    $s=$s->{"out1"};
                    $off++;
                }
                elsif($s->{c} eq "Class"){
                    $s=$s->{"out1"};
                    $off++;
                }
                elsif($s->{c} =~ /\\(\d)/){
                    my $str=$str_pool[$1];
                    my $len=$str->{len};
                    push @$rout, "strncmp($var+$position, $str->{s}, $len)==0";
                    $s=$s->{"out1"};
                    if($len=~/\d+/){
                        $off+=$len;
                    }
                    elsif(!$pos){
                        $pos=$len;
                    }
                    else{
                        $pos="$pos+$len";
                    }
                }
                elsif($s->{c} =~/^-(.)(.)/){
                    push @$rout, "$var\[$position\]>='$1' && $var\[$position\]<='$2'";
                    $s=$s->{"out1"};
                    $off++;
                }
            }
        }
        return regex_straight($p);
    }
    else{
        my $strstart="$var+$pos";
        my $strend="$var+$end";
        if(!$pos){
            $strstart=$var;
        }
        if(!$end){
            func_add_var("n_regex_limit", "int");
            $strend="$strstart+n_regex_limit";
            push @$out, "n_regex_limit=strlen($strstart);";
        }
        print "regex_init_code\n";
        $includes{"<stdlib.h>"}=1;
        if(!$structs{"VMInst"}){
            declare_struct("VMInst", "int opcode, int c, int x, int y");
            add_regex_vm_code(\@initcodes);
        }
        if(!$structs{"String"}){
            declare_struct("String", "int len, char * s");
        }
        if(!$enums{"RegexOp"}){
            push @enum_list, "RegexOp";
            $enums{"RegexOp"}="Char, Match, Jmp, Split, AnyChar, Str, MatchedStr";
        }
        my $n=dump_vm_c(build_vm($startstate), \@str_pool, $out);
        return "regex_vm_match(nfa, $n, $strstart, $strend)";
    }
}
sub parse_regex {
    my $re=shift;
    my @dst;
    my $natom=0;
    my $nalt=0;
    my @parenlist;
    my @class;
    my $escape;
    my $inclass;
    for(my $i=0;$i<length($re);$i++){
        my $c=substr($re, $i, 1);
        if($inclass){
            my $c2=substr($re, $i+2, 1);
            if(substr($re, $i+1, 1) eq "-"){
                push @class, "-$c$c2";
                $i+=2;
            }
            elsif($escape){
                if($c =~/[tnr']/){
                    push @class, "\\$c";
                }
                elsif($c eq '\\'){
                    push @class, "\\\\";
                }
                else{
                    push @class, $c;
                }
                $escape=0;
            }
            elsif($c eq "\\"){
                $escape=1;
            }
            elsif($c eq ']'){
                foreach my $t (@class){
                    push @dst, $t;
                }
                for(my $i=0; $i<@class-1; $i++){
                    push @dst, "]|";
                }
                $inclass=0;
            }
            else{
                push @class, $c;
            }
        }
        else{
            if($escape){
                if($c=~/[tnr'0-9]/){
                    $c="\\$c";
                }
                elsif($c eq 'd'){
                    $c="-09";
                }
                elsif($c =~/[()*+?|.\]\[]/){
                    $c="]$c";
                }
                elsif($c eq '\\'){
                    $c="]\\\\";
                }
                $escape=0;
            }
            if($c eq "\\"){
                $escape=1;
            }
            elsif($c eq '['){
                for (my $i=0; $i<$natom-1; $i++){ push @dst, "]."; };
                if(!$natom){ $natom=1; } else{ $natom=2; };
                @class=();
                $inclass=1;
            }
            elsif($c eq '('){
                for (my $i=0; $i<$natom-1; $i++){ push @dst, "]."; };
                push @parenlist, {nalt=>$nalt, natom=>$natom};
                $natom=0;
                $nalt=0;
            }
            elsif($c eq ')'){
                for (my $i=0; $i<$natom-1; $i++){ push @dst, "]."; };
                for(my $i=0; $i<$nalt; $i++){ push @dst, "]|"; };
                my $p=pop @parenlist;
                if(!$p){
                    die "REGEX $re: Unmatched parenthesis\n";
                }
                if(!$natom){
                    die "REGEX $re: Empty parenthesis\n";
                }
                $natom=$p->{natom};
                $nalt=$p->{nalt};
                $natom++;
            }
            elsif($c eq '|'){
                if(!$natom){
                    die "REGEX $re: Empty alternations\n";
                }
                for (my $i=0; $i<$natom-1; $i++){ push @dst, "]."; };
                $natom=0;
                $nalt++;
            }
            elsif($c eq '*' or $c eq '+' or $c eq '?'){
                if(!$natom){
                    die "REGEX $re: Empty '$c'\n";
                }
                push @dst, "]$c";
            }
            else{
                for (my $i=0; $i<$natom-1; $i++){ push @dst, "]."; };
                if($c=~/](.+)/){
                    $c=$1;
                }
                elsif($c eq '.'){
                    $c = "AnyChar";
                }
                elsif($c eq '"'){
                    $c="\\\"";
                }
                push @dst, $c;
                if(!$natom){ $natom=1; } else{ $natom=2; };
            }
        }
    }
    if(@parenlist){
        die "REGEX $re: Unmatched parenthesis\n";
    }
    for(my $i=0; $i<$natom-1; $i++){ push @dst, "]."; };
    for(my $i=0; $i<$nalt; $i++){ push @dst, "]|"; };
    return \@dst;
}
sub build_nfa {
    my $src=shift;
    if(ref($src) ne "ARRAY"){
        die "build_nfa error.\n";
    }
    my @states;
    my @fragstack;
    my $straight=1;
    my $match={idx=>0, c=>"Match"};
    my $state_idx=1;
    foreach my $c (@$src){
        if($c eq "]."){
            my $e2=pop @fragstack;
            my $e1=pop @fragstack;
            my $e1out=$e1->{out};
            foreach $out (@$e1out){
                my $s=$out->{state};
                $s->{$out->{arrow}}=$e2->{start};
            }
            push @fragstack, {start=>$e1->{start}, out=>$e2->{out}};
        }
        elsif($c eq "]|"){
            my $e2=pop @fragstack;
            my $e1=pop @fragstack;
            my $state={idx=>$state_idx, c=>"Split", out1=>$e1->{start}, out2=>$e2->{start}};
            push @states, $state; $state_idx++;
            my $e1out=$e1->{out};
            my $e2out=$e2->{out};
            foreach my $out (@$e2out){
                push @$e1out, $out;
            }
            push @fragstack, {start=>$state, out=>$e1out};
        }
        elsif($c eq "]?"){
            my $e=pop @fragstack;
            my $point;
            my $state={idx=>$state_idx, c=>"Split", out1=>$e->{start}};
            push @states, $state; $state_idx++;
            my $eout=$e->{out};
            push @$eout, {state=>$state, arrow=>"out2"};
            push @fragstack, {start=>$state, out=>$eout};
            $straight=0;
        }
        elsif($c eq "]*"){
            my $e=pop @fragstack;
            my $point;
            my $state={idx=>$state_idx, c=>"Split", out1=>$e->{start}};
            push @states, $state; $state_idx++;
            my $eout=$e->{out};
            foreach $out (@$eout){
                $out->{state}->{$out->{arrow}}=$state;
            }
            push @fragstack, {start=>$state, out=>[{state=>$state, arrow=>"out2"}]};
            $straight=0;
        }
        elsif($c eq "]+"){
            my $e=pop @fragstack;
            my $point;
            my $state={idx=>$state_idx, c=>"Split", out1=>$e->{start}};
            push @states, $state; $state_idx++;
            my $eout=$e->{out};
            foreach $out (@$eout){
                $out->{state}->{$out->{arrow}}=$state;
            }
            push @fragstack, {start=>$e->{start}, out=>[{state=>$state, arrow=>"out2"}]};
            $straight=0;
        }
        else{
            my $state={idx=>$state_idx, c=>$c};
            push @states, $state; $state_idx++;
            push @fragstack, {start=>$state, out=>[{state=>$state, arrow=>"out1"}]};
        }
    }
    my $e=pop @fragstack;
    if(@fragstack){
        die "Unbalanced fragstack\n";
    }
    my $eout=$e->{out};
    foreach my $out (@$eout){
        $out->{state}->{$out->{arrow}}=$match;
    }
    return ($e->{start}, $straight);
}
sub build_vm {
    my $startstate=shift;
    my @threadstack;
    push @threadstack, $startstate;
    my $count;
    my @vm;
    my %history;
    my %labelhash;
    while(my $s=pop @threadstack){
        if(defined $history{$s}){
            next;
        }
        while(1){
            if(defined $history{$s}){
                push @vm, ["Jmp", undef, $s, undef];
                $labelhash{$s}=1;
                last;
            }
            else{
                $history{$s}=$#vm+1;
                if($s->{c} eq "Match"){
                    push @vm,  ["Match", undef, undef, undef];
                    last;
                }
                elsif($s->{c} eq "Split"){
                    push @vm, ["Split", undef, $s->{out1}, $s->{out2}];
                    push @threadstack, $s->{out1};
                    push @threadstack, $s->{out2};
                    $labelhash{$s->{out1}}=1;
                    $labelhash{$s->{out2}}=1;
                    last;
                }
                elsif($s->{c} eq "AnyChar"){
                    push @vm,  ["AnyChar", undef, undef, undef];
                    $s=$s->{out1};
                }
                elsif($s->{c} =~ /\\(\d)/){
                    push @vm,  ["Str", $1, undef, undef];
                    $s=$s->{out1};
                }
                else{
                    push @vm,  ["Char", $s->{c}, undef, undef];
                    $s=$s->{out1};
                }
                $count++;
                if($count>1000){
                    die "deadloop\n";
                }
            }
        }
    }
        if($l->[0] eq "Jmp"){
            $l->[2]=$history{$l->[2]};
        }
        elsif($l->[0] eq "Split"){
            $l->[2]=$history{$l->[2]};
            $l->[3]=$history{$l->[3]};
        }
        $vm[$history{$s}]->[4]=1;
    return \@vm;
}
sub dump_vm_c {
    my ($vm, $str_pool, $out)=@_;
    my $ns=@$str_pool;
    if($ns>0){
        if($ns>10){
            die "Maximum strings in regex is limited to 10 ($ns)\n";
        }
        func_add_var("str_pool[10]", "struct String");
        push @$out, "str_pool = (struct String *)malloc(sizeof(struct String)*$ns);";
        my $i=0;
        foreach my $str (@$str_pool){
            my ($s, $len)=($str->{s}, $str->{len});
            push @$out, "str_pool[$i].len=$len;";
            push @$out, "str_pool[$i].s=$s;";
            $i++;
        }
    }
    my $n=@$vm;
    func_add_var("nfa", "struct VMInst *");
    push @$out, "nfa=(struct VMInst[$n]) {";
    my $i=0;
    foreach my $l (@$vm){
        if($l->[0] eq "Match"){
            push @$out, "    Match, 0, 0, 0,";
        }
        elsif($l->[0] eq "Char"){
            my $c="'$l->[1]'";
            push @$out, "    Char, $c, 0, 0,";
        }
        elsif($l->[0] eq "Split"){
            push @$out, "    Split, 0, $l->[2], $l->[3],";
        }
        elsif($l->[0] eq "Jmp"){
            push @$out, "    Jmp, 0,  $l->[2], 0,";
        }
        elsif($l->[0] eq "AnyChar"){
            push @$out, "    AnyChar, 0, 0, 0,";
        }
        $i++;
    }
    push @$out, "};";
    return $n;
}
sub print_vm {
    my $vm=shift;
    my $i=0;
    foreach my $l (@$vm){
        if($l->[4]){
            print "$i:";
        }
        if($l->[0] eq "Match"){
            print "\tMatch\n";
        }
        elsif($l->[0] eq "Char"){
            print "\tChar $l->[1]\n";
        }
        elsif($l->[0] eq "Split"){
            print "\tSplit $l->[2], $l->[3]\n";
        }
        elsif($l->[0] eq "Jmp"){
            print "\tJmp $l->[2]\n";
        }
        elsif($l->[0] eq "AnyChar"){
            print "\tAnyChar\n";
        }
        $i++;
    }
}
sub add_regex_vm_code {
    my ($out, $n, $var, $end)=@_;
    push @$out, "void add_vm_thread(int* tlist, int thread){";
    push @$out, "    int i;";
    push @$out, "    for(i=0;i<tlist[0];i++){";
    push @$out, "        if(tlist[i+1]==thread){";
    push @$out, "            return;";
    push @$out, "        }";
    push @$out, "    }";
    push @$out, "    tlist[0]++;";
    push @$out, "    tlist[tlist[0]]=thread;";
    push @$out, "}";
    push @$out, "";
    push @$out, "int regex_vm_match(struct VMInst* nfa, int nfasize, char* s, char* end, struct String * str_pool){";
    push @$out, "    struct VMInst* pc;";
    push @$out, "    int* clist=(int*)malloc((nfasize+1)*sizeof(int));";
    push @$out, "    int* nlist=(int*)malloc((nfasize+1)*sizeof(int));";
    push @$out, "    int* tlist;";
    push @$out, "    clist[0]=0;";
    push @$out, "    nlist[0]=0;";
    push @$out, "    add_vm_thread(clist, 0);";
    push @$out, "    char * sp;";
    push @$out, "    int i;";
    push @$out, "    for(sp=s; sp<end; sp++){";
    push @$out, "        for(i=1; i<clist[0]+1; i++){";
    push @$out, "            pc=nfa+clist[i];";
    push @$out, "            switch(pc->opcode){";
    push @$out, "            case Char:";
    push @$out, "                if(*sp != pc->c)";
    push @$out, "                    break;";
    push @$out, "                add_vm_thread(nlist, clist[i]+1);";
    push @$out, "                break;";
    push @$out, "            case AnyChar:";
    push @$out, "                add_vm_thread(nlist, clist[i]+1);";
    push @$out, "                break;";
    push @$out, "            case Str:";
    push @$out, "                if(strncmp(sp, str_pool[pc->c].s, str_pool[pc->c].len)!=0)";
    push @$out, "                    break;";
    push @$out, "                pc->opcode=MatchedStr;";
    push @$out, "            case MatchedStr:";
    push @$out, "                str_pool[pc->c].len--;";
    push @$out, "                if(str_pool[pc->c].len>0)";
    push @$out, "                    add_vm_thread(nlist, clist[i]);";
    push @$out, "                else";
    push @$out, "                    add_vm_thread(nlist, clist[i]+1);";
    push @$out, "                break;";
    push @$out, "            case Match:";
    push @$out, "                free(clist);";
    push @$out, "                free(nlist);";
    push @$out, "                return 1;";
    push @$out, "            case Jmp:";
    push @$out, "                add_vm_thread(clist, pc->x);";
    push @$out, "                break;";
    push @$out, "            case Split:";
    push @$out, "                add_vm_thread(clist, pc->x);";
    push @$out, "                add_vm_thread(clist, pc->y);";
    push @$out, "                break;";
    push @$out, "            }";
    push @$out, "         }";
    push @$out, "         tlist=nlist; nlist=clist; clist=tlist;";
    push @$out, "         nlist[0]=0;";
    push @$out, "    }";
    push @$out, "    free(clist);";
    push @$out, "    free(nlist);";
    push @$out, "    return 0;";
    push @$out, "}";
    push @$out, "";
    my $strvar=$var;
    my $size=$end;
    if($pos){
        $strvar="$var+$pos";
        $size=$end-$pos;
    }
}
sub regex_straight {
    my $a=shift;
    if(!ref($a)){
        return $a;
    }
    elsif(ref($a) eq "ARRAY"){
        my $t=shift(@$a);
        my $sep;
        my @tlist;
        foreach my $b (@$a){
            push @tlist, regex_straight($b);
        }
        if($t eq "and"){
            if(@tlist==1 and $tlist[0]=~/^\((.*)\)$/){
                return $1;
            }
            else{
                return join(" && ", @tlist);
            }
        }
        elsif($t eq "or"){
            return "(".join(" || ", @tlist).")";
        }
    }
}
sub get_interface {
    return (\&init_page, \&parsecode, \&modeswitch, \&dumpout);
}
sub init_page {
    my ($page)=@_;
    my $ext="m";
    if($page->{type}){
        $ext=$page->{type};
    }
    %includes=();
    if($MyDef::def->{"macros"}->{"use_double"}){
        $type_name{f}="double";
        $type_prefix{f}="double";
    }
    MyDef::dumpout::init_funclist();
    register_type_prefix("obj", "id");
    $global_type->{self}=1;
    $class_default=$MyDef::def->{resource}->{"class_default"};
    return ($ext, "sub");
}
sub modeswitch {
    my $pmode;
    ($pmode, $mode, $out)=@_;
}
sub parsecode {
    my $l=shift;
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
    elsif($l=~/^NOOP/){
        return;
    }
    if($l=~/(RGB|RCT|IMG|FILE|ARRAY|HASH|CSTRING)\((.*?)\)/){
        my $pre=$`;
        my $post=$';
        my $fn=$1;
        my $param=$2;
        if($fn eq "RGB"){
            if(length($param)==6){
                my ($r, $g, $b)=(hex(substr($param, 0, 2)), hex(substr($param, 2, 2)), hex(substr($param, 4, 2)));
                $l=$pre."[UIColor colorWithRed:$r/255.0 green:$g/255.0 blue:$b/255.0 alpha:1]".$post;
            }
            elsif(length($param)==8){
                my ($r, $g, $b, $a)=(hex(substr($param, 0, 2)), hex(substr($param, 2, 2)), hex(substr($param, 4, 2)), hex(substr($param, 6, 2)));
                $l=$pre."[UIColor colorWithRed:$r/255.0 green:$g/255.0 blue:$b/255.0 alpha:$a/255.0]".$post;
            }
        }
        elsif($fn eq "RCT"){
            $l=$pre."CGRectMake($param)".$post;
        }
        elsif($fn eq "IMG"){
            my $t=nsstring($param);
            $l=$pre."[UIImage imageNamed:$t]".$post;
        }
        elsif($fn eq "FILE"){
            if($param=~/(Documents|Library)\/(.*)/i){
                my $dir;
                if(lc($1) eq "documents"){
                    $dir="NSDocumentDirectory";
                }
                elsif(lc($1) eq "library"){
                    $dir="NSLibraryDirectory";
                }
                my $s=nsstring($2);
                $l=$pre."[[NSSearchPathForDirectoriesInDomains($dir, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:$s]".$post;
            }
            else{
                my $s=nsstring($param);
                $l=$pre."[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:$s]".$post;
            }
        }
        elsif($fn eq "ARRAY"){
            my @plist=split /, \s*/, $param;
            my @objs;
            foreach my $p(@plist){
                push @objs, nsnumber($p);
            }
            my $objlist=join(", ", @objs);
            $l=$pre."[NSArray arrayWithObjects: $objlist, nil]". $post;
        }
        elsif($fn eq "HASH"){
            my @plist=split /,\s*/, $param;
            my @objs;
            my @keys;
            foreach my $p(@plist){
                my ($key, $val)=split /=>/, $p;
                push @objs, $val;
                push @keys, "@\"$keys\"";
            }
            my $objlist=join(", ", @objs);
            my $keylist=join(", ", @keys);
            $l=$pre."[NSDictionary dictionaryWithObjects:[arrayWithObjects $objlist, nil] forKeys:[arrayWithObjects $keylist, nil]]". $post;
        }
        elsif($fn eq "CSTRING"){
            $l=$pre."(char *)[$param cStringUsingEncoding:NSASCIIStringEncoding]". $post;
        }
    }
    if($l=~/^\$MakeController\s+(\w+)/){
        create_controller($1);
        return;
    }
    elsif($l=~/^\$subclass\s+(\w+)(.*)/){
        new_class($1, $2);
        return;
    }
    elsif($l=~/^\$implement\s+(\w+)/){
        my $protocol=$1;
        if($protocol){
            my $plist=$cur_class->{protocols};
            my $exist=0;
            foreach my $p (@plist){
                if($p eq $protocol){
                    $exist=1;
                }
            }
            if(!$exist){
                push @$plist, $protocol;
                res_collect($cur_class->{field}, $class_default->{$protocol});
            }
        }
        return;
    }
    elsif($l=~/^\$method\s+(\w+)(.*)/){
        my ($name, $tail)=($1, $2);
        my $declare;
        my $method=$cur_class->{field}->{$name};
        if(!ref($method)){
            $declare=$method;
        }
        else{
            if($method->{declare}){
                $declare=$method->{declare};
            }
            else{
                $declare=$method->{_name};
            }
        }
        if(!$declare){
            if($name=~/^\w+_/){
                my $ret_type=get_c_type($name);
                $declare="- ($ret_type)$name";
            }
            else{
                $declare="- (void)$name";
            }
        }
        if($tail=~/^\((.*)\)/){
            my @plist=split /,\s*/, $1;
            for(my $i=0; $i<@plist; $i++){
                my $type=get_c_type($plist[$i]);
                if($i>0){
                    $declare.=" p$i";
                }
                $declare.=":($type)$plist[$i]";
            }
        }
        my $fidx=open_closure("$declare {", "}");
        my $prop=$cur_class->{properties};
        foreach my $v (keys %$prop){
            declare_var($v, $prop->{$v});
        }
        my @method_block;
        push @method_block, "OPEN_FUNC_$fidx";
        push @method_block, "SOURCE_INDENT";
        if($method->{pre}){
            my $tempout=$MyDef::compileutil::out;
            $MyDef::compileutil::out=\@method_block;
            $out=\@method_block;
            if(!ref($method->{pre})){
                MyDef::compileutil::parseblock([$method->{pre}]);
            }
            else{
                MyDef::compileutil::parseblock($method->{pre}->{_list});
            }
            $MyDef::compileutil::out=$tempout;
            $out=$tempout;
        }
        push @method_block, "BLOCK";
        if($method->{post}){
            my $tempout=$MyDef::compileutil::out;
            $MyDef::compileutil::out=\@method_block;
            $out=\@method_block;
            if(!ref($method->{post})){
                MyDef::compileutil::parseblock([$method->{post}]);
            }
            else{
                MyDef::compileutil::parseblock($method->{post}->{_list});
            }
            $MyDef::compileutil::out=$tempout;
            $out=$tempout;
        }
        push @method_block, "SOURCE_DEDENT";
        push @{$cur_class->{methods}}, \@method_block;
        push @{$cur_class->{declares}}, $declare;
        return \@method_block;
    }
    elsif($l=~/^\s*\$prop\s+(.*)/){
        my ($t, $attr)=($1, undef);
        my @plist=split /,\s*/, $t;
        foreach my $p (@plist){
            my ($type, $name)=get_name_type($p);
            if($cur_class){
                if($attr){
                    $cur_class->{properties}->{$name}="($attr) $type";
                }
                else{
                    $cur_class->{properties}->{$name}=$type;
                }
                declare_var($name, $type);
            }
        }
        return;
    }
    elsif($l=~/^\s*\$prop\((.*)\)\s+(.*)/){
        my ($t, $attr)=($2, $1);
        my @plist=split /,\s*/, $t;
        foreach my $p (@plist){
            my ($type, $name)=get_name_type($p);
            if($cur_class){
                if($attr){
                    $cur_class->{properties}->{$name}="($attr) $type";
                }
                else{
                    $cur_class->{properties}->{$name}=$type;
                }
                declare_var($name, $type);
            }
        }
        return;
    }
    elsif($l=~/^\s*@(\w+)\s*=\s*(.*)/){
        my $type=get_c_type($1);
        if($cur_class){
            $cur_class->{properties}->{$1}=$type;
            declare_var($1, $type);
        }
        $l="$1 = $2";
    }
    elsif($l=~/^\s*@(.*)\s+(\w+)\s*=\s*(.*)/){
        my $type=$1;
        if($cur_class){
            $cur_class->{properties}->{$2}=$type;
            declare_var($2, $type);
        }
        $l="$2 = $3";
    }
    elsif($l=~/^\$addview\s+(.+)/){
        my @tlist=split /,\s*/, $1;
        foreach my $v(@tlist){
            addview($out, $v);
        }
    }
    elsif($l=~/^\$animate_begin\s+(.+)/){
        if($animate_block_depth!=0){
            die "animate_block_depth=$animate_block_depth at \$animate_begin\n";
        }
        $animate_block_depth=1;
        my $param=parse_animation_param($1);
        return single_block("[UIView animateWithDuration:$param animations:^", $out);
    }
    elsif($l=~/^\$animate_next\s+(.+)/){
        if($animate_block_depth<=0){
            die "Missing \$animate_begin?\n";
        }
        if($animate_need_completion>0){
            $animate_need_completion--;
        }
        $animate_block_depth++;
        my $param=parse_animation_param($1);
        return single_block("completion:^(BOOL finished){ [UIView animateWithDuration:$param animations:^", $out);
    }
    elsif($l=~/^\$animate_complete/){
        if($animate_need_completion>0){
            $animate_need_completion--;
        }
        return single_block("completion:^(BOOL finished)", $out);
    }
    elsif($l=~/^\$animate_finish/){
        while($animate_block_depth>1){
            push @$out, "]}";
            $animate_block_depth--;
        }
        if($animate_need_completion>0){
            $animate_need_completion=0;
            push @$out, "completion:NULL";
        }
        push @$out, "];";
        $animate_block_depth=0;
        return;
    }
    elsif($l=~/^(\S+)\s*=\s*new (\w+)(.*)/){
        new_object($out, $1, $2, $3);
        return;
    }
    elsif($l=~/^\s*\$foreach\s+(\w+)\s+in\s+(\w+)/){
        func_add_var($1);
        return single_block("for($1 in $2)", $out);
    }
    elsif($l=~/^\s*([a-zA-Z0-9._]+)->(\w+)(\s*)(.*)/){
        if(!$4){
            push @$out, "[$1 $2];";
            return;
        }
        else{
            my ($obj, $mtd, $s, $t)=($1, $2, $3, $4);
            if($s=~/\s/){
                push @$out, "[$obj $mtd:$t];";
                return;
            }
        }
    }
    my $should_return=1;
    if($l=~/^FUNC (\w+)-(.*)/){
        my $fname=$1;
        my $t=$2;
        if($fname eq "n_main"){
            $fname="main";
        }
        my $fidx=open_function($fname, $t);
        push @$out, "OPEN_FUNC_$fidx";
        $cur_indent=0;
        return;
    }
    elsif($l=~/^\s*PRINT\s+(.*)$/){
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
            declare_struct($param1, $param2);
            $type_prefix{"st$param1"}="struct $param1";
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
            foreach my $t (@plist){
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
            foreach my $p (@plist){
                push @$fplist, $p;
                if($p=~/(.*)\s+(\w+)\s*$/){
                    $cur_function->{var_type}->{$2}=$1;
                }
            }
        }
        elsif($func eq "mu_skip"){
            my @plist=split /,\s*/, $param;
            foreach my $p (@plist){
                $cur_function->{mu_skip}->{$p}=1;
            }
        }
        elsif($func eq "mu_enable"){
            mu_enable();
        }
        elsif($func eq "include"){
            my @flist=split /,\s+/, $param;
            foreach my $f (@flist){
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
        elsif($func eq "define"){
            push @$out, "#define $param";
        }
        elsif($func eq "uselib"){
            my @flist=split /,\s+/, $param;
            foreach my $f (@flist){
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
            foreach my $v (@vlist){
                global_namespace($v);
            }
        }
        elsif($func eq "global"){
            my @vlist=split /,\s+/, $param;
            foreach my $v (@vlist){
                my ($type, $val);
                if($v=~/^(.*)?\s*=\s*(.*)/){
                    $val=$2;
                    $v=$1;
                }
                if($v=~/^(\S.*)\s+(\S+)$/){
                    $type=$1;
                    $v=$2;
                }
                global_add_var($v, $type, $val);
            }
        }
        elsif($func eq "globalinit"){
            global_add_var($param);
        }
        elsif($func eq "local"){
            my @vlist=split /,\s+/, $param;
            foreach my $v (@vlist){
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
            foreach my $p (@plist){
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
            foreach my $p (@plist){
                my $ptype=get_var_type($p);
                struct_free($out, $ptype, $p);
            }
        }
        elsif($func eq "dump"){
            debug_dump($param, undef, $out);
        }
        elsif($func eq "getopt"){
            my @vlist=split /,\s+/, $param;
            $includes{"<stdlib.h>"}=1;
            $includes{"<unistd.h>"}=1;
            my $cstr='';
            foreach my $v (@vlist){
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
            foreach my $v (@vlist){
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
        elsif($func eq "push"){
            if($param=~/(\w+),\s*(.*)/){
                list_push($out, $1, $2);
            }
        }
        elsif($func eq "unshift"){
            if($param=~/(\w+),\s*(.*)/){
                list_unshift($out, $1, $2);
            }
        }
        elsif($func eq "pop"){
            if($param=~/(\w+)/){
                list_pop($out, $1);
            }
        }
        elsif($func eq "shift"){
            if($param=~/(\w+)/){
                list_shift($out, $1);
            }
        }
        elsif($func eq "foreach"){
            if($param=~/(\w+)\s+in\s+(\w+)/){
                return list_foreach($out, $iv, $v);
            }
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
    my $func=$functions{"main"};
    if($func){
        $func->{skip_declare}=1;
        $func->{ret_type}="int";
        $func->{param_list}=["int argc", "char** argv"];
        $func->{init}=["DUMP_STUB main_init"];
        $func->{finish}=["DUMP_STUB main_exit", "return 0;"];
    }
    my $funclist=MyDef::dumpout::get_func_list();
    foreach my $func (@$funclist){
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
                if($global_type->{$v}){
                    print "  [warning] In $name: local variable $v with exisiting global\n";
                }
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
    foreach my $name (@view_list){
        my $view = $MyDef::def->{resource}->{"view_$name"};
        if(!$view){
            print "Resource view: $name does not exist\n";
            return;
        }
        if(!$view->{processed}){
            my ($x, $y, $w, $h);
            if(!$view->{processed}){
                my $name=$view->{_name};
                my %attr;
                my $default=$MyDef::def->{resource}->{default_view};
                while(my ($k, $v)=each %$default){
                    if($k!~/^_(name|list)/){
                        $attr{$k}=$v;
                    }
                }
                my $a=$MyDef::def->{resource}->{"view_$name"};
                if($a){
                    while(my ($k, $v)=each %$a){
                        if($k!~/^_(name|list)/){
                            $attr{$k}=$v;
                        }
                    }
                }
                my $a=$MyDef::def->{resource}->{"ctl_$name"};
                if($a){
                    while(my ($k, $v)=each %$a){
                        if($k!~/^_(name|list)/){
                            $attr{$k}=$v;
                        }
                    }
                }
                while(my ($k, $v)=each %attr){
                    if(!defined $view->{$k}){
                        $view->{$k} = $v;
                    }
                }
                ($x, $y)=split /,\s*/, $view->{position};
                ($w, $h)=split /,\s*/, $view->{size};
                if($x=~/-(.*)/ and $w=~/-.*/){
                    $x=$1;
                }
                if($y=~/-(.*)/ and $h=~/-.*/){
                    $y=$1;
                }
                $view->{x}=$x;
                $view->{y}=$y;
                $view->{w}=$w;
                $view->{h}=$h;
                if($x=~/-(.*)/ or $y=~/-(.*)/ or $w=~/-(.*)/ or $h=~/-(.*)/){
                    $view->{docked}=1;
                }
                else{
                    $view->{docked}=0;
                }
                $view->{processed}=1;
            }
            else{
                $x=$view->{x};
                $y=$view->{y};
                $w=$view->{w};
                $h=$view->{h};
            }
        }
        push @cur_class_stack, $cur_class;
        my $actionlist={"_target"=>"self"};
        my $proplist={};
        my $initlist=[];
        new_class("UIViewController", ", controller_$name");
        if($view->{protocol}){
            $cur_class->{protocols}=$view->{protocol};
        }
        if(1){
            push @cur_method_stack, $cur_function;
            my $block=[];
            my $method_name="loadView";
            $method_hash{"METHOD$method_idx"}=$block;
            my $declare;
            my $method=$cur_class->{field}->{$method_name};
            if(!ref($method)){
                $declare=$method;
            }
            else{
                if($method->{declare}){
                    $declare=$method->{declare};
                }
                else{
                    $declare=$method->{_name};
                }
            }
            if(!$declare){
                if($method_name=~/^\w+_/){
                    my $ret_type=get_c_type($method_name);
                    $declare="- ($ret_type)$method_name";
                }
                else{
                    $declare="- (void)$method_name";
                }
            }
            if($tail=~/^\((.*)\)/){
                my @plist=split /,\s*/, $1;
                for(my $i=0; $i<@plist; $i++){
                    my $type=get_c_type($plist[$i]);
                    if($i>0){
                        $declare.=" p$i";
                    }
                    $declare.=":($type)$plist[$i]";
                }
            }
            my $fidx=open_closure("$declare {", "}");
            my $prop=$cur_class->{properties};
            foreach my $v (keys %$prop){
                declare_var($v, $prop->{$v});
            }
            my @method_block;
            push @method_block, "OPEN_FUNC_$fidx";
            push @method_block, "SOURCE_INDENT";
            if($method->{pre}){
                my $tempout=$MyDef::compileutil::out;
                $MyDef::compileutil::out=\@method_block;
                $out=\@method_block;
                if(!ref($method->{pre})){
                    MyDef::compileutil::parseblock([$method->{pre}]);
                }
                else{
                    MyDef::compileutil::parseblock($method->{pre}->{_list});
                }
                $MyDef::compileutil::out=$tempout;
                $out=$tempout;
            }
            push @method_block, "INCLUDE_BLOCK METHOD$method_idx";
            if($method->{post}){
                my $tempout=$MyDef::compileutil::out;
                $MyDef::compileutil::out=\@method_block;
                $out=\@method_block;
                if(!ref($method->{post})){
                    MyDef::compileutil::parseblock([$method->{post}]);
                }
                else{
                    MyDef::compileutil::parseblock($method->{post}->{_list});
                }
                $MyDef::compileutil::out=$tempout;
                $out=$tempout;
            }
            push @method_block, "SOURCE_DEDENT";
            push @{$cur_class->{methods}}, \@method_block;
            push @{$cur_class->{declares}}, $declare;
            $method_idx++;
            my $tempout=$MyDef::compileutil::out;
            $MyDef::compileutil::out=$block;
            $out=$block;
            func_add_var("frame0", "CGRect");
            push @$out, "frame0=[[UIScreen mainScreen] applicationFrame];";
            my $mainview={_name=>$name, _list=>$view->{_list}};
            $mainview->{actionlist}=$actionlist;
            $mainview->{proplist}=$proplist;
            $mainview->{initlist}=$initlist;
            my $view_var=create_view($mainview, 1);
            push @$out, "[self setView:$view_var];";
            $MyDef::compileutil::out=$tempout;
            $out=$tempout;
            $cur_function=pop @cur_method_stack;
        }
        while(my ($name, $type) = each %$proplist){
            $cur_class->{properties}->{$name}=$type;
        }
        my @alist=keys %$actionlist;
        my $need_init;
        if(@$initlist){
            $need_init=1;
        }
        foreach my $a (@alist){
            if($a !~/^_.*/){
                my $tail;
                if($actionlist->{$a}=~/event/){
                    $tail="(obj)";
                }
                push @cur_method_stack, $cur_function;
                my $block=[];
                my $method_name="$a";
                $method_hash{"METHOD$method_idx"}=$block;
                my $declare;
                my $method=$cur_class->{field}->{$method_name};
                if(!ref($method)){
                    $declare=$method;
                }
                else{
                    if($method->{declare}){
                        $declare=$method->{declare};
                    }
                    else{
                        $declare=$method->{_name};
                    }
                }
                if(!$declare){
                    if($method_name=~/^\w+_/){
                        my $ret_type=get_c_type($method_name);
                        $declare="- ($ret_type)$method_name";
                    }
                    else{
                        $declare="- (void)$method_name";
                    }
                }
                if($tail=~/^\((.*)\)/){
                    my @plist=split /,\s*/, $1;
                    for(my $i=0; $i<@plist; $i++){
                        my $type=get_c_type($plist[$i]);
                        if($i>0){
                            $declare.=" p$i";
                        }
                        $declare.=":($type)$plist[$i]";
                    }
                }
                my $fidx=open_closure("$declare {", "}");
                my $prop=$cur_class->{properties};
                foreach my $v (keys %$prop){
                    declare_var($v, $prop->{$v});
                }
                my @method_block;
                push @method_block, "OPEN_FUNC_$fidx";
                push @method_block, "SOURCE_INDENT";
                if($method->{pre}){
                    my $tempout=$MyDef::compileutil::out;
                    $MyDef::compileutil::out=\@method_block;
                    $out=\@method_block;
                    if(!ref($method->{pre})){
                        MyDef::compileutil::parseblock([$method->{pre}]);
                    }
                    else{
                        MyDef::compileutil::parseblock($method->{pre}->{_list});
                    }
                    $MyDef::compileutil::out=$tempout;
                    $out=$tempout;
                }
                push @method_block, "INCLUDE_BLOCK METHOD$method_idx";
                if($method->{post}){
                    my $tempout=$MyDef::compileutil::out;
                    $MyDef::compileutil::out=\@method_block;
                    $out=\@method_block;
                    if(!ref($method->{post})){
                        MyDef::compileutil::parseblock([$method->{post}]);
                    }
                    else{
                        MyDef::compileutil::parseblock($method->{post}->{_list});
                    }
                    $MyDef::compileutil::out=$tempout;
                    $out=$tempout;
                }
                push @method_block, "SOURCE_DEDENT";
                push @{$cur_class->{methods}}, \@method_block;
                push @{$cur_class->{declares}}, $declare;
                $method_idx++;
                my $tempout=$MyDef::compileutil::out;
                $MyDef::compileutil::out=$block;
                $out=$block;
                if($a eq "on_init" and $need_init){
                    MyDef::compileutil::parseblock($initlist);
                    $need_init=0;
                }
                MyDef::compileutil::call_sub("$name\_$a");
                $MyDef::compileutil::out=$tempout;
                $out=$tempout;
                $cur_function=pop @cur_method_stack;
            }
        }
        if($need_init){
            push @cur_method_stack, $cur_function;
            my $block=[];
            my $method_name="on_init";
            $method_hash{"METHOD$method_idx"}=$block;
            my $declare;
            my $method=$cur_class->{field}->{$method_name};
            if(!ref($method)){
                $declare=$method;
            }
            else{
                if($method->{declare}){
                    $declare=$method->{declare};
                }
                else{
                    $declare=$method->{_name};
                }
            }
            if(!$declare){
                if($method_name=~/^\w+_/){
                    my $ret_type=get_c_type($method_name);
                    $declare="- ($ret_type)$method_name";
                }
                else{
                    $declare="- (void)$method_name";
                }
            }
            if($tail=~/^\((.*)\)/){
                my @plist=split /,\s*/, $1;
                for(my $i=0; $i<@plist; $i++){
                    my $type=get_c_type($plist[$i]);
                    if($i>0){
                        $declare.=" p$i";
                    }
                    $declare.=":($type)$plist[$i]";
                }
            }
            my $fidx=open_closure("$declare {", "}");
            my $prop=$cur_class->{properties};
            foreach my $v (keys %$prop){
                declare_var($v, $prop->{$v});
            }
            my @method_block;
            push @method_block, "OPEN_FUNC_$fidx";
            push @method_block, "SOURCE_INDENT";
            if($method->{pre}){
                my $tempout=$MyDef::compileutil::out;
                $MyDef::compileutil::out=\@method_block;
                $out=\@method_block;
                if(!ref($method->{pre})){
                    MyDef::compileutil::parseblock([$method->{pre}]);
                }
                else{
                    MyDef::compileutil::parseblock($method->{pre}->{_list});
                }
                $MyDef::compileutil::out=$tempout;
                $out=$tempout;
            }
            push @method_block, "INCLUDE_BLOCK METHOD$method_idx";
            if($method->{post}){
                my $tempout=$MyDef::compileutil::out;
                $MyDef::compileutil::out=\@method_block;
                $out=\@method_block;
                if(!ref($method->{post})){
                    MyDef::compileutil::parseblock([$method->{post}]);
                }
                else{
                    MyDef::compileutil::parseblock($method->{post}->{_list});
                }
                $MyDef::compileutil::out=$tempout;
                $out=$tempout;
            }
            push @method_block, "SOURCE_DEDENT";
            push @{$cur_class->{methods}}, \@method_block;
            push @{$cur_class->{declares}}, $declare;
            $method_idx++;
            my $tempout=$MyDef::compileutil::out;
            $MyDef::compileutil::out=$block;
            $out=$block;
            MyDef::compileutil::parseblock($initlist);
            $MyDef::compileutil::out=$tempout;
            $out=$tempout;
            $cur_function=pop @cur_method_stack;
        }
        $cur_class=pop @cur_class_stack;
    }
    my $block=MyDef::compileutil::get_named_block("global_init");
    my @class_list = sort keys %classes;
    foreach my $name (@class_list){
        push @$block, "\@class $name;";
    }
    push @$block, "NEWLINE";
    foreach my $name (@class_list){
        my $class=$classes{$name};
        my $interface=$class->{interface};
        if(@{$class->{protocols}}){
            my $plist=$class->{protocols};
            $interface.=" <".join(", ", @$plist).">";
        }
        push @$block, "\@interface $name : $interface";
        while(my ($pname, $ptype)=each %{$class->{properties}}){
            push @$block, "\@property $ptype $pname;";
        }
        foreach my $declare (@{$class->{declares}}){
            push @$block, "$declare;";
        }
        push @$block, "\@end";
        push @$block, "NEWLINE";
    }
    foreach my $name (@class_list){
        my $class=$classes{$name};
        push @$block, "\@implementation $name";
        while(my ($pname, $ptype)=each %{$class->{properties}}){
            push @$block, "\@synthesize $pname;";
        }
        foreach my $method (@{$class->{methods}}){
            push @$block, "NEWLINE";
            foreach my $t (@$method){
                push @$block, $t;
            }
            push @$block, "NEWLINE";
        }
        push @$block, "\@end";
        push @$block, "NEWLINE";
    }
    while(my ($k, $v)=each %method_hash){
        $dump->{$k}=$v;
    }
    my @includes=keys %imports;
    foreach my $i (@includes){
        push @$f, "#import <$i>\n";
    }
    push @$f, "\n";
    unshift @$out, "DUMP_STUB global_init";
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
        my $s_list=$structs{$name}->{list};
        my $s_hash=$structs{$name}->{hash};
        my $i=0;
        foreach my $p (@$s_list){
            $i++;
            if($s_hash->{$p} eq "function"){
                push @dump_init, "\t".$fntype{$p}.";\n";
            }
            else{
                push @dump_init, "\t$s_hash->{$p} $p;\n";
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
        my $s_hash=$structs{$name}->{hash};
        my $s_init=$s_hash->{"-init"};
        if(@$s_init){
            push @dump_init, "void $name\_constructor(struct $name* p){\n";
            foreach my $l(@$s_init){
                push @dump_init, "    $l\n";
            }
            push @dump_init, "}\n";
            $cnt++;
        }
        my $s_exit=$s_hash->{"-exit"};
        if(@$s_exit){
            push @dump_init, "void $name\_destructor(struct $name* p){\n";
            foreach my $l(@$s_exit){
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
        push @dump_init, "$v;\n";
        $cnt++;
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
    MyDef::dumpout::dumpout($dump);
}
sub new_class {
    my ($name, $tail)=@_;
    my $newclass;
    if($tail=~/,\s*(\w+)/){
        $newclass=$1;
    }
    elsif($tail=~/,\s*_(\w+)/){
        $newclass="$name\_$1";
    }
    else{
        $newclass=$name;
    }
    $cur_class={super=>$name, protocols=>[], name=>$newclass, properties=>{}, declares=>[], methods=>[]};
    my $field=collect_class_field($name);
    $cur_class->{field}=$field;
    $classes{$newclass} = $cur_class;
    my $class=$field->{class};
    if(!$class){
        $class=$name;
    }
    $cur_class->{interface}="$class";
    my $protocol=$field->{protocol};
    if($protocol){
        my $plist=$cur_class->{protocols};
        my $exist=0;
        foreach my $p (@plist){
            if($p eq $protocol){
                $exist=1;
            }
        }
        if(!$exist){
            push @$plist, $protocol;
            res_collect($cur_class->{field}, $class_default->{$protocol});
        }
    }
}
sub create_controller {
    my ($name)=@_;
    my $view = $MyDef::def->{resource}->{"view_$name"};
    if(!$view){
        print "Resource view: $name does not exist\n";
        return;
    }
    my $controller_name="controller_$name";
    my $var="controller";
    func_add_var($var, "controller_$name *");
    push @$out, "$var = [[controller_$name alloc] init];";
    if(!$controller_hash{$name}){
        $controller_hash{$name}="controller_$name";
        push @cur_class_stack, $cur_class;
        my $actionlist={"_target"=>"self"};
        my $proplist={};
        my $initlist=[];
        new_class("UIViewController", ", controller_$name");
        if($view->{protocol}){
            $cur_class->{protocols}=$view->{protocol};
        }
        if(1){
            push @cur_method_stack, $cur_function;
            my $block=[];
            my $method_name="loadView";
            $method_hash{"METHOD$method_idx"}=$block;
            my $declare;
            my $method=$cur_class->{field}->{$method_name};
            if(!ref($method)){
                $declare=$method;
            }
            else{
                if($method->{declare}){
                    $declare=$method->{declare};
                }
                else{
                    $declare=$method->{_name};
                }
            }
            if(!$declare){
                if($method_name=~/^\w+_/){
                    my $ret_type=get_c_type($method_name);
                    $declare="- ($ret_type)$method_name";
                }
                else{
                    $declare="- (void)$method_name";
                }
            }
            if($tail=~/^\((.*)\)/){
                my @plist=split /,\s*/, $1;
                for(my $i=0; $i<@plist; $i++){
                    my $type=get_c_type($plist[$i]);
                    if($i>0){
                        $declare.=" p$i";
                    }
                    $declare.=":($type)$plist[$i]";
                }
            }
            my $fidx=open_closure("$declare {", "}");
            my $prop=$cur_class->{properties};
            foreach my $v (keys %$prop){
                declare_var($v, $prop->{$v});
            }
            my @method_block;
            push @method_block, "OPEN_FUNC_$fidx";
            push @method_block, "SOURCE_INDENT";
            if($method->{pre}){
                my $tempout=$MyDef::compileutil::out;
                $MyDef::compileutil::out=\@method_block;
                $out=\@method_block;
                if(!ref($method->{pre})){
                    MyDef::compileutil::parseblock([$method->{pre}]);
                }
                else{
                    MyDef::compileutil::parseblock($method->{pre}->{_list});
                }
                $MyDef::compileutil::out=$tempout;
                $out=$tempout;
            }
            push @method_block, "INCLUDE_BLOCK METHOD$method_idx";
            if($method->{post}){
                my $tempout=$MyDef::compileutil::out;
                $MyDef::compileutil::out=\@method_block;
                $out=\@method_block;
                if(!ref($method->{post})){
                    MyDef::compileutil::parseblock([$method->{post}]);
                }
                else{
                    MyDef::compileutil::parseblock($method->{post}->{_list});
                }
                $MyDef::compileutil::out=$tempout;
                $out=$tempout;
            }
            push @method_block, "SOURCE_DEDENT";
            push @{$cur_class->{methods}}, \@method_block;
            push @{$cur_class->{declares}}, $declare;
            $method_idx++;
            my $tempout=$MyDef::compileutil::out;
            $MyDef::compileutil::out=$block;
            $out=$block;
            func_add_var("frame0", "CGRect");
            push @$out, "frame0=[[UIScreen mainScreen] applicationFrame];";
            my $mainview={_name=>$name, _list=>$view->{_list}};
            $mainview->{actionlist}=$actionlist;
            $mainview->{proplist}=$proplist;
            $mainview->{initlist}=$initlist;
            my $view_var=create_view($mainview, 1);
            push @$out, "[self setView:$view_var];";
            $MyDef::compileutil::out=$tempout;
            $out=$tempout;
            $cur_function=pop @cur_method_stack;
        }
        while(my ($name, $type) = each %$proplist){
            $cur_class->{properties}->{$name}=$type;
        }
        my @alist=keys %$actionlist;
        my $need_init;
        if(@$initlist){
            $need_init=1;
        }
        foreach my $a (@alist){
            if($a !~/^_.*/){
                my $tail;
                if($actionlist->{$a}=~/event/){
                    $tail="(obj)";
                }
                push @cur_method_stack, $cur_function;
                my $block=[];
                my $method_name="$a";
                $method_hash{"METHOD$method_idx"}=$block;
                my $declare;
                my $method=$cur_class->{field}->{$method_name};
                if(!ref($method)){
                    $declare=$method;
                }
                else{
                    if($method->{declare}){
                        $declare=$method->{declare};
                    }
                    else{
                        $declare=$method->{_name};
                    }
                }
                if(!$declare){
                    if($method_name=~/^\w+_/){
                        my $ret_type=get_c_type($method_name);
                        $declare="- ($ret_type)$method_name";
                    }
                    else{
                        $declare="- (void)$method_name";
                    }
                }
                if($tail=~/^\((.*)\)/){
                    my @plist=split /,\s*/, $1;
                    for(my $i=0; $i<@plist; $i++){
                        my $type=get_c_type($plist[$i]);
                        if($i>0){
                            $declare.=" p$i";
                        }
                        $declare.=":($type)$plist[$i]";
                    }
                }
                my $fidx=open_closure("$declare {", "}");
                my $prop=$cur_class->{properties};
                foreach my $v (keys %$prop){
                    declare_var($v, $prop->{$v});
                }
                my @method_block;
                push @method_block, "OPEN_FUNC_$fidx";
                push @method_block, "SOURCE_INDENT";
                if($method->{pre}){
                    my $tempout=$MyDef::compileutil::out;
                    $MyDef::compileutil::out=\@method_block;
                    $out=\@method_block;
                    if(!ref($method->{pre})){
                        MyDef::compileutil::parseblock([$method->{pre}]);
                    }
                    else{
                        MyDef::compileutil::parseblock($method->{pre}->{_list});
                    }
                    $MyDef::compileutil::out=$tempout;
                    $out=$tempout;
                }
                push @method_block, "INCLUDE_BLOCK METHOD$method_idx";
                if($method->{post}){
                    my $tempout=$MyDef::compileutil::out;
                    $MyDef::compileutil::out=\@method_block;
                    $out=\@method_block;
                    if(!ref($method->{post})){
                        MyDef::compileutil::parseblock([$method->{post}]);
                    }
                    else{
                        MyDef::compileutil::parseblock($method->{post}->{_list});
                    }
                    $MyDef::compileutil::out=$tempout;
                    $out=$tempout;
                }
                push @method_block, "SOURCE_DEDENT";
                push @{$cur_class->{methods}}, \@method_block;
                push @{$cur_class->{declares}}, $declare;
                $method_idx++;
                my $tempout=$MyDef::compileutil::out;
                $MyDef::compileutil::out=$block;
                $out=$block;
                if($a eq "on_init" and $need_init){
                    MyDef::compileutil::parseblock($initlist);
                    $need_init=0;
                }
                MyDef::compileutil::call_sub("$name\_$a");
                $MyDef::compileutil::out=$tempout;
                $out=$tempout;
                $cur_function=pop @cur_method_stack;
            }
        }
        if($need_init){
            push @cur_method_stack, $cur_function;
            my $block=[];
            my $method_name="on_init";
            $method_hash{"METHOD$method_idx"}=$block;
            my $declare;
            my $method=$cur_class->{field}->{$method_name};
            if(!ref($method)){
                $declare=$method;
            }
            else{
                if($method->{declare}){
                    $declare=$method->{declare};
                }
                else{
                    $declare=$method->{_name};
                }
            }
            if(!$declare){
                if($method_name=~/^\w+_/){
                    my $ret_type=get_c_type($method_name);
                    $declare="- ($ret_type)$method_name";
                }
                else{
                    $declare="- (void)$method_name";
                }
            }
            if($tail=~/^\((.*)\)/){
                my @plist=split /,\s*/, $1;
                for(my $i=0; $i<@plist; $i++){
                    my $type=get_c_type($plist[$i]);
                    if($i>0){
                        $declare.=" p$i";
                    }
                    $declare.=":($type)$plist[$i]";
                }
            }
            my $fidx=open_closure("$declare {", "}");
            my $prop=$cur_class->{properties};
            foreach my $v (keys %$prop){
                declare_var($v, $prop->{$v});
            }
            my @method_block;
            push @method_block, "OPEN_FUNC_$fidx";
            push @method_block, "SOURCE_INDENT";
            if($method->{pre}){
                my $tempout=$MyDef::compileutil::out;
                $MyDef::compileutil::out=\@method_block;
                $out=\@method_block;
                if(!ref($method->{pre})){
                    MyDef::compileutil::parseblock([$method->{pre}]);
                }
                else{
                    MyDef::compileutil::parseblock($method->{pre}->{_list});
                }
                $MyDef::compileutil::out=$tempout;
                $out=$tempout;
            }
            push @method_block, "INCLUDE_BLOCK METHOD$method_idx";
            if($method->{post}){
                my $tempout=$MyDef::compileutil::out;
                $MyDef::compileutil::out=\@method_block;
                $out=\@method_block;
                if(!ref($method->{post})){
                    MyDef::compileutil::parseblock([$method->{post}]);
                }
                else{
                    MyDef::compileutil::parseblock($method->{post}->{_list});
                }
                $MyDef::compileutil::out=$tempout;
                $out=$tempout;
            }
            push @method_block, "SOURCE_DEDENT";
            push @{$cur_class->{methods}}, \@method_block;
            push @{$cur_class->{declares}}, $declare;
            $method_idx++;
            my $tempout=$MyDef::compileutil::out;
            $MyDef::compileutil::out=$block;
            $out=$block;
            MyDef::compileutil::parseblock($initlist);
            $MyDef::compileutil::out=$tempout;
            $out=$tempout;
            $cur_function=pop @cur_method_stack;
        }
        $cur_class=pop @cur_class_stack;
    }
}
sub create_view {
    my ($view, $level, $parent_view)=@_;
    my $name=$view->{_name};
    my ($x, $y, $w, $h);
    if(!$view->{processed}){
        my $name=$view->{_name};
        my %attr;
        my $default=$MyDef::def->{resource}->{default_view};
        while(my ($k, $v)=each %$default){
            if($k!~/^_(name|list)/){
                $attr{$k}=$v;
            }
        }
        my $a=$MyDef::def->{resource}->{"view_$name"};
        if($a){
            while(my ($k, $v)=each %$a){
                if($k!~/^_(name|list)/){
                    $attr{$k}=$v;
                }
            }
        }
        my $a=$MyDef::def->{resource}->{"ctl_$name"};
        if($a){
            while(my ($k, $v)=each %$a){
                if($k!~/^_(name|list)/){
                    $attr{$k}=$v;
                }
            }
        }
        while(my ($k, $v)=each %attr){
            if(!defined $view->{$k}){
                $view->{$k} = $v;
            }
        }
        ($x, $y)=split /,\s*/, $view->{position};
        ($w, $h)=split /,\s*/, $view->{size};
        if($x=~/-(.*)/ and $w=~/-.*/){
            $x=$1;
        }
        if($y=~/-(.*)/ and $h=~/-.*/){
            $y=$1;
        }
        $view->{x}=$x;
        $view->{y}=$y;
        $view->{w}=$w;
        $view->{h}=$h;
        if($x=~/-(.*)/ or $y=~/-(.*)/ or $w=~/-(.*)/ or $h=~/-(.*)/){
            $view->{docked}=1;
        }
        else{
            $view->{docked}=0;
        }
        $view->{processed}=1;
    }
    else{
        $x=$view->{x};
        $y=$view->{y};
        $w=$view->{w};
        $h=$view->{h};
    }
    my $view_type="UIView";
    if($view->{class}){
        $view_type=$view->{class};
    }
    my $cur_view;
    if($view->{id}){
        $cur_view=$view->{id};
    }
    else{
        my $idx=1;
        while($view_id_hash{"$name$idx"}){
            $idx++;
        }
        $cur_view="$name$idx";
        $view_id_hash{$cur_view}=1;
    }
    my $need_view;
    my $actionlist={};
    if(MyDef::compileutil::get_def_attr("codes", "$name\_on_draw")){
        $actionlist->{on_draw}=1;
        $need_view=1;
    }
    if($need_view){
        $actionlist->{_target}=$cur_view;
        $view->{actionlist}=$actionlist;
        $view->{proplist}={};
        $view->{initlist}=[];
        $view_type="view_$name";
    }
    func_add_var("frame$level", "CGRect");
    $view->{frame}="frame$level";
    my $parent_frame;
    my $plevel=$level-1;
    $parent_frame="frame".$plevel;
    if($x=~/-(.*)/){
        $x="$parent_frame.size.width-$1-$w";
    }
    if($y=~/-(.*)/){
        $y="$parent_frame.size.height-$1-$h";
    }
    if($w=~/-(.*)/){
        $w="$parent_frame.size.width-$1-$x";
    }
    if($h=~/-(.*)/){
        $h="$parent_frame.size.height-$1-$y";
    }
    push @$out, "frame$level=CGRectMake($x, $y, $w, $h);";
    func_add_var($cur_view, "$view_type *");
    if($view->{create}){
        my $l=$view->{create};
        my @codelist;
        my $error;
        if(ref($l) eq "HASH"){
            foreach my $tl (@{$l->{_list}}){
                $tl=~s/\$view/$cur_view/g;
                $tl=res_get_str($view, $tl);
                if($tl){
                    push @codelist, $tl;
                }
                else{
                    $error=1;
                }
            }
        }
        else{
            $l=~s/\$view/$cur_view/g;
            my $tl=res_get_str($view, $l);
            if($tl){
                push @codelist, $tl;
            }
            else{
                $error=1;
            }
        }
        if(!$error){
            MyDef::compileutil::parseblock(\@codelist);
        }
        if($error){
            die "$name create [$l] missing variables\n";
        }
    }
    else{
        push @$out, "$cur_view=[[$view_type alloc] initWithFrame:frame$level];";
    }
    while(my ($k, $l)=each %$view){
        if($k=~/^do_(\w+)/){
            my @codelist;
            my $error;
            if(ref($l) eq "HASH"){
                foreach my $tl (@{$l->{_list}}){
                    $tl=~s/\$view/$cur_view/g;
                    $tl=res_get_str($view, $tl);
                    if($tl){
                        push @codelist, $tl;
                    }
                    else{
                        $error=1;
                    }
                }
            }
            else{
                $l=~s/\$view/$cur_view/g;
                my $tl=res_get_str($view, $l);
                if($tl){
                    push @codelist, $tl;
                }
                else{
                    $error=1;
                }
            }
            if(!$error){
                MyDef::compileutil::parseblock(\@codelist);
            }
        }
    }
    if($view->{property}){
        my $proplist=$view->{proplist};
        my $initlist=$view->{initlist};
        my @plist=split /,/, $view->{property};
        foreach my $p (@plist){
            my $init;
            if($p=~/(.*)=(.*)/){
                ($p, $init)=($1, $2);
            }
            my ($type, $name)=get_name_type($p);
            if($p=~/(\S.*)\s+(\S+)/){
                $proplist->{$2}=$1;
            }
            else{
                $p=~s/^\s+//;
                $p=~s/\s+$//;
                $proplist->{$p}=get_c_type($p);
            }
            if(defined $init){
                push @$initlist, "$name = $init;";
            }
        }
    }
    if($view->{action}){
        my $actionlist=$view->{actionlist};
        my $target=$actionlist->{_target};
        my @alist=split /,/, $view->{action};
        foreach my $a (@alist){
            if($a=~/(\w+):\s*(\w+)/){
                push @$out, "[$cur_view addTarget:$target action:\@selector($2:) forControlEvents:$1];";
                $actionlist->{$2}="event";
            }
            elsif($view->{default_event}){
                push @$out, "[$cur_view addTarget:$target action:\@selector($a:) forControlEvents:$view->{default_event}];";
                $actionlist->{$a}="event";
            }
            else{
                push @$out, "[$cur_view addTarget:$target action:\@selector($a:)];";
                $actionlist->{$a}="event";
            }
        }
    }
    if($parent_view){
        push @$out, "[$parent_view addSubview:$cur_view];";
    }
    push @$out, "NEWLINE";
    my $list=$view->{_list};
    foreach my $v (@$list){
        $v->{actionlist}=$view->{actionlist};
        create_view($v, $level+1, $cur_view);
    }
    if($need_view and !$view_hash{$name}){
        $view_hash{$name}="view_$name";
        push @cur_class_stack, $cur_class;
        new_class( "UIView", ", view_$name",);
        my $proplist=$view->{proplist};
        while(my ($name, $type) = each %$proplist){
            $cur_class->{properties}->{$name}=$type;
        }
        my $actionlist=$view->{actionlist};
        my $initlist=$view->{initlist};
        my @alist=keys %$actionlist;
        my $need_init;
        if(@$initlist){
            $need_init=1;
        }
        foreach my $a (@alist){
            if($a !~/^_.*/){
                my $tail;
                if($actionlist->{$a}=~/event/){
                    $tail="(obj)";
                }
                push @cur_method_stack, $cur_function;
                my $block=[];
                my $method_name="$a";
                $method_hash{"METHOD$method_idx"}=$block;
                my $declare;
                my $method=$cur_class->{field}->{$method_name};
                if(!ref($method)){
                    $declare=$method;
                }
                else{
                    if($method->{declare}){
                        $declare=$method->{declare};
                    }
                    else{
                        $declare=$method->{_name};
                    }
                }
                if(!$declare){
                    if($method_name=~/^\w+_/){
                        my $ret_type=get_c_type($method_name);
                        $declare="- ($ret_type)$method_name";
                    }
                    else{
                        $declare="- (void)$method_name";
                    }
                }
                if($tail=~/^\((.*)\)/){
                    my @plist=split /,\s*/, $1;
                    for(my $i=0; $i<@plist; $i++){
                        my $type=get_c_type($plist[$i]);
                        if($i>0){
                            $declare.=" p$i";
                        }
                        $declare.=":($type)$plist[$i]";
                    }
                }
                my $fidx=open_closure("$declare {", "}");
                my $prop=$cur_class->{properties};
                foreach my $v (keys %$prop){
                    declare_var($v, $prop->{$v});
                }
                my @method_block;
                push @method_block, "OPEN_FUNC_$fidx";
                push @method_block, "SOURCE_INDENT";
                if($method->{pre}){
                    my $tempout=$MyDef::compileutil::out;
                    $MyDef::compileutil::out=\@method_block;
                    $out=\@method_block;
                    if(!ref($method->{pre})){
                        MyDef::compileutil::parseblock([$method->{pre}]);
                    }
                    else{
                        MyDef::compileutil::parseblock($method->{pre}->{_list});
                    }
                    $MyDef::compileutil::out=$tempout;
                    $out=$tempout;
                }
                push @method_block, "INCLUDE_BLOCK METHOD$method_idx";
                if($method->{post}){
                    my $tempout=$MyDef::compileutil::out;
                    $MyDef::compileutil::out=\@method_block;
                    $out=\@method_block;
                    if(!ref($method->{post})){
                        MyDef::compileutil::parseblock([$method->{post}]);
                    }
                    else{
                        MyDef::compileutil::parseblock($method->{post}->{_list});
                    }
                    $MyDef::compileutil::out=$tempout;
                    $out=$tempout;
                }
                push @method_block, "SOURCE_DEDENT";
                push @{$cur_class->{methods}}, \@method_block;
                push @{$cur_class->{declares}}, $declare;
                $method_idx++;
                my $tempout=$MyDef::compileutil::out;
                $MyDef::compileutil::out=$block;
                $out=$block;
                if($a eq "on_init" and $need_init){
                    MyDef::compileutil::parseblock($initlist);
                    $need_init=0;
                }
                MyDef::compileutil::call_sub("$name\_$a");
                $MyDef::compileutil::out=$tempout;
                $out=$tempout;
                $cur_function=pop @cur_method_stack;
            }
        }
        if($need_init){
            push @cur_method_stack, $cur_function;
            my $block=[];
            my $method_name="on_init";
            $method_hash{"METHOD$method_idx"}=$block;
            my $declare;
            my $method=$cur_class->{field}->{$method_name};
            if(!ref($method)){
                $declare=$method;
            }
            else{
                if($method->{declare}){
                    $declare=$method->{declare};
                }
                else{
                    $declare=$method->{_name};
                }
            }
            if(!$declare){
                if($method_name=~/^\w+_/){
                    my $ret_type=get_c_type($method_name);
                    $declare="- ($ret_type)$method_name";
                }
                else{
                    $declare="- (void)$method_name";
                }
            }
            if($tail=~/^\((.*)\)/){
                my @plist=split /,\s*/, $1;
                for(my $i=0; $i<@plist; $i++){
                    my $type=get_c_type($plist[$i]);
                    if($i>0){
                        $declare.=" p$i";
                    }
                    $declare.=":($type)$plist[$i]";
                }
            }
            my $fidx=open_closure("$declare {", "}");
            my $prop=$cur_class->{properties};
            foreach my $v (keys %$prop){
                declare_var($v, $prop->{$v});
            }
            my @method_block;
            push @method_block, "OPEN_FUNC_$fidx";
            push @method_block, "SOURCE_INDENT";
            if($method->{pre}){
                my $tempout=$MyDef::compileutil::out;
                $MyDef::compileutil::out=\@method_block;
                $out=\@method_block;
                if(!ref($method->{pre})){
                    MyDef::compileutil::parseblock([$method->{pre}]);
                }
                else{
                    MyDef::compileutil::parseblock($method->{pre}->{_list});
                }
                $MyDef::compileutil::out=$tempout;
                $out=$tempout;
            }
            push @method_block, "INCLUDE_BLOCK METHOD$method_idx";
            if($method->{post}){
                my $tempout=$MyDef::compileutil::out;
                $MyDef::compileutil::out=\@method_block;
                $out=\@method_block;
                if(!ref($method->{post})){
                    MyDef::compileutil::parseblock([$method->{post}]);
                }
                else{
                    MyDef::compileutil::parseblock($method->{post}->{_list});
                }
                $MyDef::compileutil::out=$tempout;
                $out=$tempout;
            }
            push @method_block, "SOURCE_DEDENT";
            push @{$cur_class->{methods}}, \@method_block;
            push @{$cur_class->{declares}}, $declare;
            $method_idx++;
            my $tempout=$MyDef::compileutil::out;
            $MyDef::compileutil::out=$block;
            $out=$block;
            MyDef::compileutil::parseblock($initlist);
            $MyDef::compileutil::out=$tempout;
            $out=$tempout;
            $cur_function=pop @cur_method_stack;
        }
        $cur_class=pop @cur_class_stack;
    }
    return $cur_view;
}
sub res_get_str {
    my ($view, $l)=@_;
    my @tlist=split /(\$\w+)/, $l;
    my $i=0;
    foreach my $t (@tlist){
        if($t=~/\$(\w+)/){
            if($view->{$1}){
                $tlist[$i]=$view->{$1};
            }
            else{
                return undef;
            }
        }
        $i++;
    }
    return join("", @tlist);
}
1;
