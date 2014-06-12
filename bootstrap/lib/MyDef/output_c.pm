use strict;
package MyDef::output_c;
our %misc_vars;
our %type_name;
our %type_prefix;
our %fntype;
our %stock_functions;
our %lib_include;
our %type_include;
our %text_include;
our @scope_stack;
our $cur_scope;
our $global_hash;
our $global_list;
our %functions;
our $cur_function;
our @extern_binary;
our %includes;
our %objects;
our $define_id_base;
our @define_list;
our %defines;
our @typedef_list;
our %typedef_hash;
our %enums;
our @enum_list;
our @function_declare_list;
our @declare_list;
our %structs;
our @struct_list;
our @initcodes;
our %h_hash;
our @function_stack;
our $case_if="if";
our $case_elif="else if";
our @case_stack;
our $case_state;
our $case_wrap;
our $case_flag="b_flag_case";
our @list_function_list;
our %plugin_statement;
our %plugin_condition;
our $autoload;
our $autoload_h;
our %lamda_functions;
our %list_function_hash;
our $dump_classes;
our %protected_var;
our $debug;
our $mode;
our $page;
our $out;
my $cur_indent;
our $except;
our $anonymous_count=0;
our $print_type=1;
use File::stat;
sub get_mtime {
    my ($fname)=@_;
    my $st=stat($fname);
    return $st->[9];
}
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
    v=>"unsigned char *",
    f=>"float",
    d=>"double",
    "time"=>"time_t",
    "file"=>"FILE *",
    "strlen"=>"STRLEN",
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
    ($page)=@_;
    my $ext="c";
    if($MyDef::var->{filetype}){
        $ext=$MyDef::var->{filetype};
    }
    if($page->{type}){
        $ext=$page->{type};
    }
    if($MyDef::def->{"macros"}->{"use_double"}){
        $type_name{f}="double";
        $type_prefix{f}="double";
    }
    MyDef::dumpout::init_funclist();
    @scope_stack=();
    $global_hash={};
    $global_list=[];
    $cur_scope={var_list=>$global_list, var_hash=>$global_hash, name=>"global"};
    %functions=();
    undef $cur_function;
    @extern_binary=();
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
    @declare_list=();
    %structs=();
    @struct_list=();
    @initcodes=();
    %h_hash=();
    @function_stack=();
    $page->{pageext}=$ext;
    my $init_mode=$page->{init_mode};
    return ($ext, $init_mode);
}
sub set_output {
    $out = shift;
}
sub modeswitch {
    my ($mode, $in)=@_;
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
    elsif($l=~/^\$eval\s+(\w+)(.*)/){
        my ($codename, $param)=($1, $2);
        $param=~s/^\s*,\s*//;
        my $t=MyDef::compileutil::eval_sub($codename);
        eval $t;
        if($@){
            print "Error [$l]: $@\n";
            print "  $t\n";
        }
        return;
    }
    if($debug eq "case"){
        my $level=@case_stack;
        print "        $level:[$case_state]$l\n";
    }
    if($l=~/^\$(if|elif|elsif|elseif|case)\s+(.*)$/){
        my $cond=$2;
        my $case=$case_if;
        if($1 eq "if"){
            if($case_wrap){
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
        single_block("$case($cond){", "}");
        push @$out, "PARSE:CASEPOP";
        push @case_stack, {state=>"if", wrap=>$case_wrap};
        undef $case_state;
        undef $case_wrap;
        if($debug eq "case"){
            my $level=@case_stack;
            print "Entering case [$level]: $l\n";
        }
        return "NEWBLOCK-if";
    }
    elsif($l=~/^\$else/){
        if(!$case_state and $l!~/NoWarn/i){
            my $pos=MyDef::compileutil::curfile_curline();
            print "[$pos]Dangling \$else \n";
        }
        single_block("else{", "}");
        push @$out, "PARSE:CASEPOP";
        push @case_stack, {state=>undef, wrap=>$case_wrap};
        undef $case_state;
        undef $case_wrap;
        if($debug eq "case"){
            my $level=@case_stack;
            print "Entering case [$level]: $l\n";
        }
        return "NEWBLOCK-else";
    }
    elsif($l=~/^\&case\s+(.*)/){
        if(!$case_state){
            global_add_var($case_flag);
            push @$out, "b_flag_case=1;";
            MyDef::compileutil::call_sub($1, "\$call");
            single_block("if($case_flag){", "}");
        }
        else{
            push @$out, "else{";
            push @$out, "INDENT";
            global_add_var($case_flag);
            push @$out, "b_flag_case=1;";
            MyDef::compileutil::call_sub($1, "\$call");
            single_block("if($case_flag){", "}");
            push @$out, "DEDENT";
            if(!$case_wrap){
                $case_wrap=[];
            }
            push @$case_wrap, "}";
        }
        push @$out, "PARSE:CASEPOP";
        push @case_stack, {state=>"if", wrap=>$case_wrap};
        undef $case_state;
        undef $case_wrap;
        if($debug eq "case"){
            my $level=@case_stack;
            print "Entering case [$level]: $l\n";
        }
        return "NEWBLOCK-if";
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
                $case_wrap=$t_case->{wrap};
            }
            return 0;
        }
        elsif($l=~/^CASEEXIT/){
            push @$out, "b_flag_case=0;";
            return 0;
        }
    }
    if(!$case_state){
        if($case_wrap){
            push @$out, @$case_wrap;
            undef $case_wrap;
        }
    }
    if($MyDef::compileutil::cur_mode eq "PRINT"){
        push @$out, $l;
        return 0;
    }
    if($l=~/^SUBBLOCK BEGIN (\d+) (.*)/){
        my ($blk, $scope)=($1, $2);
        push @$out, "DUMP_STUB SUBBLOCK_$blk";
        open_scope("SUBBLOCK_$blk", $scope);
        return;
    }
    elsif($l=~/^SUBBLOCK END (\d+) (.*)/){
        my ($blk, $scope)=($1, $2);
        close_scope("SUBBLOCK_$blk");
        return;
    }
    elsif($l=~/^NOOP POST_MAIN/){
        while(my $f=shift @list_function_list){
            my $funcname=$f;
            if($lamda_functions{$funcname}){
                my $block=$lamda_functions{$funcname};
                push @$out, @$block;
            }
            else{
                my ($paramline, $codename);
                $codename=$f;
                if($codename=~/(\w+)\((\w+)\)/){
                    $codename=$1;
                    $funcname=$2;
                }
                $funcname=~s/^@//;
                my $params=MyDef::compileutil::get_sub_param_list($codename);
                if(defined $params){
                    $paramline=join(",", @$params);
                    if($funcname eq "n_main" or $funcname eq "main2"){
                        $funcname="main";
                    }
                }
                if(defined $paramline){
                    push @function_stack, $cur_function;
                    my $fidx=open_function($funcname, $paramline);
                    push @scope_stack, $cur_scope;
                    $cur_scope=$cur_function;
                    push @$out, "OPEN_FUNC_$fidx";
                    $cur_indent=1;
                    push @$out, "SOURCE_INDENT";
                    MyDef::compileutil::set_current_macro("FunctionName", $funcname);
                    MyDef::compileutil::call_sub($codename, "\$list");
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
                    push @$out, "SOURCE_DEDENT";
                }
            }
        }
        @list_function_list=();
        %list_function_hash=();
        return;
    }
    elsif($l=~/^print\b(.*)$/i){
        my $t=$1;
        if(!$t){
            push @$out, "puts(\"\");";
        }
        else{
            $t=~s/^\s+//;
            if($t=~/usesub:\s*(\w+)/){
                $print_type=$1;
            }
            else{
                my ($n, $fmt)=fmt_string($t);
                if($print_type==1){
                    push @$out, "printf($fmt);";
                }
                elsif($print_type){
                    MyDef::compileutil::call_sub("$print_type, $fmt");
                }
            }
        }
        return;
    }
    elsif($l=~/^\s*\$(\w+)\((.*?)\)\s+(.*)$/){
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
            debug_dump($param2, $param1, $out);
            return;
        }
        elsif($func eq "register_prefix"){
            $param2=~s/^\s+//;
            $param2=~s/\s+$//;
            $type_prefix{$param1}=$param2;
            return;
        }
        elsif($func eq "register_name"){
            $param2=~s/^\s+//;
            $param2=~s/\s+$//;
            $type_name{$param1}=$param2;
            return;
        }
        elsif($func eq "register_include"){
            $param2=~s/^\s+//;
            $param2=~s/\s+$//;
            if($type_include{$param1}){
                $type_include{$param1}.=",$param2";
            }
            else{
                $type_include{$param1}.="$param2";
            }
            return;
        }
        elsif($func eq "get_type"){
            my $type=get_var_type($param2);
            MyDef::compileutil::set_current_macro($param1, $type);
            return;
        }
        elsif($func eq "get_pointer_type"){
            my $type=pointer_type(get_var_type($param2));
            MyDef::compileutil::set_current_macro($param1, $type);
            return;
        }
        elsif($func eq "get_struct_var_prefix"){
            my $type=get_var_type($param2);
            if($type=~/struct (\w+)\s*\*/){
                MyDef::compileutil::set_current_macro($param1, "$param2->");
            }
            elsif($type=~/struct (\w+)/){
                MyDef::compileutil::set_current_macro($param1, "$param2.");
            }
            else{
                die "get_var_type: $param2 returns type $type\n";
            }
            return;
        }
        elsif($func eq "struct"){
            declare_struct($param1, $param2);
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
                if($param1=~/^,\s*(\w+)/){
                    global_add_symbol("int $1");
                }
            }
            return;
        }
        elsif($func eq "enumbase"){
            my $base=0;
            if($param1=~/(\w*),\s*(\d+)/){
                $param1=$1;
                $base=$2;
            }
            if($param1){
                $param1.="_";
            }
            my @plist=split /,\s+/, $param2;
            foreach my $t (@plist){
                add_define("$param1$t", $base);
                $base++;
            }
            return;
        }
        elsif($func eq "enumbit"){
            my $base=0;
            if($param1=~/(\w*),\s*(\d+)/){
                $param1=$1;
                $base=$2;
            }
            if($param1){
                $param1.="_";
            }
            my @plist=split /,\s+/, $param2;
            foreach my $t (@plist){
                add_define("$param1$t",0x1<<$base);
                $base++;
            }
            return;
        }
        elsif($func eq "write_h"){
            my $tlist=$h_hash{$param1};
            if(!$tlist){
                $tlist=[];
                $h_hash{$param1}=$tlist;
            }
            push @$tlist, split(/,\s*/, $param2);
            return;
        }
        elsif($func eq "allocate"){
            allocate($param1, $param2);
            return;
        }
        elsif($func eq "local_allocate"){
            local_allocate($param1, $param2);
            return;
        }
        if($plugin_statement{$func}){
            my $codename=$plugin_statement{$func};
            my $t=MyDef::compileutil::eval_sub($codename);
            eval $t;
            if($@){
                print "plugin - $func\n";
                print "[$t]\n";
                print "eval error: [$@]\n";
            }
            return;
        }
    }
    elsif($l=~/^\s*\$(\w+)\s*(.*)$/){
        my ($func, $param)=($1, $2);
        if($param !~ /^=/){
            if($func eq "block"){
                return single_block("$param\{", "}", "block");
            }
            elsif($func =~/^except/){
                return single_block("$except\{", "}", "else");
            }
            elsif($func =~ /^(while|switch)$/){
                my $name=$1;
                $param=parse_condition($param);
                return single_block("$name($param){", "}");
            }
            elsif($func =~/^dowhile/){
                $param=parse_condition($param);
                return single_block("do{", "}while($param);");
            }
            elsif($func eq "pack"){
                data_pack($param);
                return;
            }
            elsif($func eq "unpack"){
                data_unpack($param);
                return;
            }
            elsif($func eq "include"){
                my @flist=split /,\s*/, $param;
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
                    else{
                        $key="<$f.h>";
                    }
                    $includes{$key}=1;
                    if($autoload){
                        push @$autoload, "include-$key";
                    }
                }
                return;
            }
            elsif($func eq "declare"){
                push @declare_list, $param;
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
                my @flist=split /,\s+/, $param;
                foreach my $f (@flist){
                    $objects{"lib$f"}=1;
                    if($lib_include{$f}){
                        my @flist=split /,\s*/, $lib_include{$f};
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
                            else{
                                $key="<$f.h>";
                            }
                            $includes{$key}=1;
                            if($autoload){
                                push @$autoload, "include-$key";
                            }
                        }
                    }
                }
                return;
            }
            elsif($func eq "fntype"){
                if($param=~/^.*?\(\s*\*\s*(\w+)\s*\)/){
                    $fntype{$1}=$param;
                }
                return;
            }
            elsif($func eq "debug_mem"){
                push @$out, "debug_mem=1;";
                $misc_vars{"debug_mem"}=1;
                return;
            }
            elsif($func eq "typedef"){
                add_typedef($param);
                return;
            }
            elsif($func eq "dump"){
                debug_dump($param, undef, $out);
                return;
            }
            elsif($func eq "push"){
                if($param=~/(\w+),\s*(.*)/){
                    list_push($out, $1, $2);
                }
                return;
            }
            elsif($func eq "unshift"){
                if($param=~/(\w+),\s*(.*)/){
                    list_unshift($out, $1, $2);
                }
                return;
            }
            elsif($func eq "pop"){
                if($param=~/(\w+)/){
                    list_pop($out, $1);
                }
                return;
            }
            elsif($func eq "shift"){
                if($param=~/(\w+)/){
                    list_shift($out, $1);
                }
                return;
            }
            elsif($func eq "return_type"){
                $cur_function->{ret_type}=$param;
                return;
            }
            elsif($func eq "parameter"){
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
                return;
            }
            elsif($func eq "global" or $func eq "symbol" or $func eq "auto_global"){
                if($func eq "auto_global"){
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
                    $func eq "global";
                }
                else{
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
                }
                if($func eq "global" and $autoload_h){
                    $func="symbol";
                }
                $param=~s/\s*;\s*$//;
                my @vlist=MyDef::utils::proper_split($param);
                foreach my $v (@vlist){
                    if($func eq "global"){
                        my $name=global_add_var($v);
                        if($autoload){
                            push @$autoload, "global-$name";
                        }
                    }
                    elsif($func eq "symbol"){
                        global_add_symbol($v);
                    }
                }
                return;
            }
            elsif($func eq "local" or $func eq "my"){
                $param=~s/\s*;\s*$//;
                my @vlist=MyDef::utils::proper_split($param);
                foreach my $v (@vlist){
                    if($func eq "my" and !$page->{disable_scope}){
                        my_add_var($v);
                    }
                    else{
                        func_add_var($v);
                    }
                }
                return;
            }
            elsif($func eq "temp"){
                $param=~s/\s*;\s*$//;
                my @vlist=MyDef::utils::proper_split($param);
                foreach my $v (@vlist){
                    temp_add_var($v);
                }
                return;
            }
            elsif($func eq "protect_var"){
                protect_var($param);
                return;
            }
            elsif($func eq "unprotect_var"){
                $protected_var{$param}--;
                return;
            }
            elsif($func eq "function"){
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
                if(!$autoload_h and $param=~/(\w+)(.*)/){
                    my ($fname, $paramline)=($1, $2);
                    if($paramline=~/\((.*)\)/){
                        $paramline=$1;
                    }
                    elsif($paramline=~/^\s*,\s*(.*)/){
                        $paramline=$1;
                    }
                    my $name=MyDef::utils::uniq_name($fname, \%list_function_hash);
                    if($autoload){
                        push @$autoload, "function-$name";
                    }
                    my $block=[];
                    my $fidx=open_function($name, $paramline);
                    push @$block, "OPEN_FUNC_$fidx";
                    push @$block, "SOURCE_INDENT";
                    push @$block, "BLOCK";
                    push @$block, "SOURCE_DEDENT";
                    push @$block, "PARSE:\$function_end";
                    $lamda_functions{$name}=$block;
                    if(!$list_function_hash{$name}){
                        $list_function_hash{$name}=1;
                        push @list_function_list, $name;
                        if($autoload){
                            push @$autoload, "function-$name";
                        }
                    }
                    else{
                        $list_function_hash{$name}++;
                    }
                    MyDef::compileutil::set_current_macro("lamda", $name);
                    return $block;
                }
                else{
                    return "SKIPBLOCK";
                }
                return;
            }
            elsif($func eq "function_end"){
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
                return;
            }
            elsif($func eq "list"){
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
                    my @tlist=split /,\s*/, $param;
                    foreach my $f (@tlist){
                        if(!$list_function_hash{$f}){
                            $list_function_hash{$f}=1;
                            push @list_function_list, $f;
                            if($autoload){
                                push @$autoload, "function-$f";
                            }
                        }
                        else{
                            $list_function_hash{$f}++;
                        }
                    }
                }
                return;
            }
            elsif($func eq "fcall"){
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
                if($param=~/(\w+)\(/){
                    if(!$list_function_hash{$1}){
                        $list_function_hash{$1}=1;
                        push @list_function_list, $1;
                        if($autoload){
                            push @$autoload, "function-$1";
                        }
                    }
                    else{
                        $list_function_hash{$1}++;
                    }
                    $l=$param;
                }
                elsif($param=~/^(\w+)\s*$/){
                    if(!$list_function_hash{$1}){
                        $list_function_hash{$1}=1;
                        push @list_function_list, $1;
                        if($autoload){
                            push @$autoload, "function-$1";
                        }
                    }
                    else{
                        $list_function_hash{$1}++;
                    }
                    $l="$1()";
                }
            }
            elsif($func eq "allocate"){
                allocate(1, $param);
                return;
            }
            elsif($func eq "for"){
                if($param=~/(.*);(.*);(.*)/){
                    return single_block("for($param){", "}", "for");
                    return "NEWBLOCK-for";
                }
                else{
                    my $var="i";
                    if($param=~/^(\S+)\s*=\s*(.*)/){
                        $var=$1;
                        $param=$2;
                    }
                    my @tlist=split /:/, $param;
                    my ($i0, $i1, $step);
                    if(@tlist==1){
                        $i0="0";
                        $i1="< $param";
                        $step="1";
                    }
                    elsif(@tlist==2){
                        if($tlist[1] eq "0"){
                            $i0="$tlist[0]-1";
                            $i1=">= $tlist[1]";
                            $step="-1";
                        }
                        else{
                            $i0=$tlist[0];
                            $i1="< $tlist[1]";
                            $step="1";
                        }
                    }
                    elsif(@tlist==3){
                        $i0=$tlist[0];
                        $step=$tlist[2];
                        if($step=~/^-/){
                            $i1=">= $tlist[1]";
                        }
                        else{
                            $i1="< $tlist[1]";
                        }
                    }
                    if($step eq "1"){
                        $step="++";
                    }
                    elsif($step eq "-1"){
                        $step="--";
                    }
                    else{
                        $step= "+=$step";
                    }
                    $var=temp_add_var($var, "int");
                    protect_var($var);
                    $param="$var=$i0; $var $i1; $var$step";
                    my $end="PARSE:\$unprotect_var $var";
                    return single_block_pre_post(["for($param){", "INDENT"], ["DEDENT", "}",$end], "for");
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
                    elsif(defined $var->{array}){
                        $dim=$var->{array};
                    }
                    print "foreach_array, $v, $var->{name}, $dim ...\n";
                    if(defined $dim){
                        my $type=pointer_type($var->{type});
                        my $i=temp_add_var("i", "int");
                        MyDef::compileutil::set_current_macro($t, "$v\[$i\]");
                        my $end="PARSE:\$unprotect_var $i";
                        return single_block_pre_post(["for($i=0;$i<$dim;$i++){", "INDENT"], ["DEDENT", "}",$end], "for");
                    }
                }
                elsif($param=~/^(\S+)\s*$/){
                    my ($t, $v)=("t", $1);
                    my $var=find_var($v);
                    my $dim;
                    if(defined $var->{dimension}){
                        $dim=$var->{dimension};
                    }
                    elsif(defined $var->{array}){
                        $dim=$var->{array};
                    }
                    print "foreach_array, $v, $var->{name}, $dim ...\n";
                    if(defined $dim){
                        my $type=pointer_type($var->{type});
                        my $i=temp_add_var("i", "int");
                        MyDef::compileutil::set_current_macro($t, "$v\[$i\]");
                        my $end="PARSE:\$unprotect_var $i";
                        return single_block_pre_post(["for($i=0;$i<$dim;$i++){", "INDENT"], ["DEDENT", "}",$end], "for");
                    }
                }
            }
            if($plugin_statement{$func}){
                my $codename=$plugin_statement{$func};
                my $t=MyDef::compileutil::eval_sub($codename);
                eval $t;
                if($@){
                    print "plugin - $func\n";
                    print "[$t]\n";
                    print "eval error: [$@]\n";
                }
                return;
            }
        }
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
    if($l=~/^(\w+)\s+(.*)$/){
        if($functions{$1} or $stock_functions{$1}){
            my $fn=$1;
            my $t=$2;
            $t=~s/;\s*$//;
            $t=~s/\s+$//;
            $l="$fn($t);";
        }
    }
    my ($assign, $left);
    my @stack;
    my @types;
    while(1){
        my $atom;
        my $op;
        if($l=~/\G$/gc){
            last;
        }
        elsif($l=~/\G("([^"\\]|\\.)*")/gc){
            $atom=$1;
        }
        elsif($l=~/\G('([^'\\]|\\.)*')/gc){
            $atom=$1;
        }
        elsif($l=~/\G(\d[0-9\.a-zA-Z]*)/gc){
            $atom=$1;
            if($stack[-1] eq "^" and $atom<10 and $atom>1){
                pop @stack;
                pop @types;
                my $primary=pop @stack;
                $atom=$primary. (" * $primary" x ($atom-1));
            }
        }
        elsif($l=~/\G(\w+)/gc){
            $atom=$1;
            if($types[-1] eq "op" && $stack[-1] eq "." or $stack[-1] eq "->"){
                if($types[-2] ne "atom"){
                }
                $atom=join(" ", splice(@stack, -2)).$atom;
                splice(@types, -2);
            }
        }
        elsif($l=~/\G([\(\[\{])/gc){
            push @stack, $1;
            push @types, undef;
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
            my @atom;
            my $n=@stack;
            my $found;
            for(my $i=$n-1; $i >= 0; $i--){
                if($stack[$i] eq $open){
                    $found=$i;
                    last;
                }
            }
            if(defined $found and $stack[$found] eq $open){
                $atom=join(" ", splice(@stack, $found+1));
                pop @stack;
                splice(@types, $found);
                if($types[-1] eq "atom" and $stack[-1]!~/^[0-9'"]/){
                    my $primary=pop @stack;
                    pop @types;
                    my $processed;
                    if($open eq '('){
                        print "fcall: $primary  $atom\n";
                    }
                    elsif($open eq '['){
                    }
                    elsif($open eq '{'){
                    }
                    if(!$processed){
                        $atom=$primary.$open.$atom.$close;
                    }
                }
                else{
                    $atom=$open.$atom.$close;
                }
            }
            else{
                print "Error checking expression $l, unbalanced brackets\n";
                $atom=join(" ", @stack);
            }
        }
        elsif($l=~/\G(\s+)/gc){
        }
        elsif($l=~/\G([=+\-\*\/%\^\&\|><\?,\.!~]+)/gc){
            $op=$1;
        }
        else{
            last;
        }
        if(!@stack){
            if($atom){
                push @stack, $atom;
                push @types, "atom";
            }
            elsif($op){
                push @stack, $op;
                push @types, "op";
            }
        }
        elsif($op){
            if($op eq "++" or $op eq "--"){
                my $exp=pop @stack;
                push @stack, "$exp $op";
                push @types, "atom";
            }
            elsif($op=~/^(.*)=$/){
                $assign=$op;
                $left=join(" ", splice(@stack));
            }
            else{
                push @stack, $op;
                push @types, "op";
            }
        }
        elsif($atom){
            if($types[-1] eq "op" && $types[-2] ne "atom"){
                my $op=pop @stack;
                push @stack, "$op $atom";
                push @types, "atom";
            }
            else{
                push @stack, $atom;
                push @types, "atom";
            }
        }
    }
    my $right=join(" ", @stack);
    if($assign){
        if($assign eq "="){
            do_assignment($left, $right);
            return;
        }
        else{
            $l="$left $assign $right";
        }
    }
    else{
        $l=$right;
    }
    if($l=~/^\s*$/){
    }
    elsif($l=~/^\s*(for|while|if|else if)\s*\(.*\)\s*$/){
    }
    elsif($l!~/[:\(\{\};,]\s*$/){
        $l.=";";
    }
    push @$out, $l;
}
sub dumpout {
    my ($f, $out, $pagetype)=@_;
    my $dump={out=>$out,f=>$f};
    my $mainfunc=$functions{"main"};
    if($mainfunc){
        $mainfunc->{skip_declare}=1;
        $mainfunc->{ret_type}="int";
        $mainfunc->{param_list}=["int argc", "char** argv"];
        unshift @{$mainfunc->{init}}, "DUMP_STUB main_init";
        push @{$mainfunc->{finish}}, "DUMP_STUB main_exit", "return 0;";
    }
    my $funclist=MyDef::dumpout::get_func_list();
    foreach my $func (@$funclist){
        if(!$func->{processed}){
            process_function_std($func);
        }
    }
    my $ofile=$page->{outdir}."/extern.o";
    my $otime=get_mtime($ofile);
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
            if(get_mtime($fname)>$otime){
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
        $objects{"extern.o"}=1;
    }
    if($mainfunc){
        my $ofile=$page->{outdir}."/Makefile";
        if(!-f $ofile or $page->{makefile}){
            print "  ---> $ofile\n";
            my @objlist;
            my @liblist;
            foreach my $i (keys %objects){
                if($i=~/^lib(.*)/){
                    push @liblist, "-l$1";
                }
                elsif($i=~/(.*\.o)/){
                    push @objlist, "$i";
                }
            }
            my $pagename=$page->{pagename};
            open Subfile, ">$ofile" or die "Can't write $ofile\n";
            if($page->{CC}){
                print Subfile "CC=$page->{CC}\n";
            }
            else{
                print Subfile "CC=gcc\n";
            }
            if($page->{CFLAGS}){
                print Subfile "CFLAGS=$page->{CFLAGS}\n";
            }
            if($page->{INC}){
                print Subfile "INC=$page->{INC}\n";
            }
            if($page->{LIB}){
                print Subfile "LIB=$page->{LIB}\n";
            }
            if($page->{makefile} eq "debug"){
                print Subfile "CFLAGS+= -g";
            }
            print Subfile "\n";
            print Subfile "$pagename: $pagename.o ".join(" ", @objlist)."\n";
            print Subfile "\t\$\(CC) \$\(LIB) ".join(" ",@liblist)." -o $pagename \$^\n";
            print Subfile "\n";
            print Subfile "%.o: %.c\n";
            print Subfile "\t\$\(CC) -c \$\(CFLAGS) \$\(INC) -o \$@ \$<\n";
            close Subfile;
        }
    }
    unshift @$out, "\n/**** END GLOBAL INIT ****/\n";
    unshift @$out, "DUMP_STUB global_init";
    if($page->{autoload} eq "h"){
        $includes{"\"autoload.h\""}=1;
    }
    my @dump_init;
    $dump->{block_init}=\@dump_init;
    unshift @$out, "INCLUDE_BLOCK block_init";
    my $outdir=$page->{outdir};
    while(my ($name, $content)=each %h_hash){
        my %ahash;
        my %ghash=("include"=>[], "define"=>[],"struct"=>[],"function"=>[],"global"=>[]);
        foreach my $t (@$content){
            if(!$ahash{$t}){
                if($t=~/^(\w+)-(.*)/){
                    push @{$ghash{$1}}, $2;
                }
                $ahash{$t}=1;
            }
        }
        my @buf;
        my $dump_out=\@buf;
        foreach my $k (@{$ghash{"include"}}){
            push @$dump_out, "#include $k\n";
        }
        foreach my $k (@{$ghash{"define"}}){
            push @$dump_out, "#define $k $defines{$k}\n";
        }
        foreach my $k (@{$ghash{"struct"}}){
            push @$dump_out, "struct $name {\n";
            my $s_list=$structs{$name}->{list};
            my $s_hash=$structs{$name}->{hash};
            my $i=0;
            foreach my $p (@$s_list){
                $i++;
                if($s_hash->{$p} eq "function"){
                    push @$dump_out, "\t".$fntype{$p}.";\n";
                }
                else{
                    push @$dump_out, "\t$s_hash->{$p} $p;\n";
                }
            }
            push @$dump_out, "};\n\n";
        }
        foreach my $k (@{$ghash{"typedef"}}){
            my $t=$typedef_hash{$k};
            if($t=~/\(\*\s*(\w+)\)/){
                push @$dump_out, "typedef $t;";
            }
            else{
                push @$dump_out, "typedef $t $k;";
            }
        }
        foreach my $k (@{$ghash{"function"}}){
            my $func=$functions{$k};
            push @$dump_out, $func->{declare}.";\n";
        }
        push @buf, "\n";
        foreach my $k (@{$ghash{"global"}}){
            my $var=$global_hash->{$k};
            my $type=$var->{type};
            if($type=~/\*$/ and $var->{array}){
                $type=~s/\s*\*$//;
                push @buf, "extern $type $k\[];\n";
            }
            else{
                push @buf, "extern $type $k;\n";
            }
        }
        my $out_h="$outdir/$name.h";
        print "  ---> $out_h\n";
        open Out, ">$out_h" or die "can't write $out_h\n";
        foreach my $l (@buf){
            print Out $l;
        }
        close Out;
    }
    my $dump_out=\@dump_init;
    my $cnt=0;
    while(my ($k, $t)=each %includes){
        push @$dump_out, "#include $k\n";
        $cnt++;
    }
    if($cnt>0){
        push @$dump_out, "\n";
    }
    my $cnt=0;
    foreach my $k (@define_list){
        push @$dump_out, "#define $k $defines{$k}\n";
        $cnt++;
    }
    if($cnt>0){
        push @$dump_out, "\n";
    }
    my $cnt=0;
    foreach my $name (@enum_list){
        my $t=$enums{$name};
        if($name=~/^ANONYMOUS/){
            push @$dump_out, "enum {$t};\n";
        }
        elsif($name=~/^,\s*(\w+)/){
            push @$dump_out, "enum {$t} $1;\n";
        }
        else{
            push @$dump_out, "enum $name {$t};\n";
        }
        $cnt++;
    }
    if($cnt>0){
        push @$dump_out, "\n";
    }
    if(@typedef_list){
        foreach my $k (@typedef_list){
            my $t=$typedef_hash{$k};
            if($t=~/\(\*\s*(\w+)\)/){
                push @$dump_out, "typedef $t;";
            }
            else{
                push @$dump_out, "typedef $t $k;";
            }
        }
        push @$dump_out, "\n";
    }
    if($dump_classes){
        foreach my $l (@$dump_classes){
            push @$dump_out, $l;
        }
    }
    foreach my $name (@struct_list){
        push @$dump_out, "struct $name {\n";
        my $s_list=$structs{$name}->{list};
        my $s_hash=$structs{$name}->{hash};
        my $i=0;
        foreach my $p (@$s_list){
            $i++;
            if($s_hash->{$p} eq "function"){
                push @$dump_out, "\t".$fntype{$p}.";\n";
            }
            else{
                push @$dump_out, "\t$s_hash->{$p} $p;\n";
            }
        }
        push @$dump_out, "};\n\n";
    }
    my $cnt=0;
    foreach my $t (@function_declare_list){
        my $func=$functions{$t};
        if(!$func->{skip_declare}){
            push @$dump_out, $func->{declare}.";\n";
            $cnt++;
        }
    }
    if($cnt>0){
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
    my $cnt=0;
    foreach my $name (@struct_list){
        my ($param, $init)=get_struct_constructor($name);
        if(defined $init){
            if(!@$param){
                push @$dump_out, "void $name\_constructor(struct $name* p){\n";
            }
            else{
                my $param_line=join(", ", @$param);
                push @$dump_out, "void $name\_constructor(struct $name* p, $param_line){\n";
            }
            foreach my $l (@$init){
                push @$dump_out, "    p->$l;\n";
            }
            push @$dump_out, "}\n";
            $cnt++;
        }
        my $s_list=$structs{$name}->{list};
        my $s_hash=$structs{$name}->{hash};
        my $s_exit=$s_hash->{"-exit"};
        if(@$s_exit){
            push @$dump_out, "void $name\_destructor(struct $name* p){\n";
            foreach my $l(@$s_exit){
                push @$dump_out, "    $l\n";
            }
            push @$dump_out, "}\n";
            $cnt++;
        }
    }
    if($cnt>0){
        push @$dump_out, "\n";
    }
    my $cnt=0;
    foreach my $name (@$global_list){
        my $v=$global_hash->{$name};
        my $decl=var_declare($v);
        if($decl){
            push @$dump_out, "$decl;\n";
        }
        $cnt++;
    }
    if($cnt>0){
        push @$dump_out, "\n";
    }
    foreach my $l (@initcodes){
        push @$dump_out, "$l\n";
    }
    if(@initcodes){
        push @$dump_out, "\n";
    }
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
            my $codename=$plugin_statement{$func};
            my $t=MyDef::compileutil::eval_sub($codename);
            eval $t;
            if($@){
                print "plugin - $func\n";
                print "[$t]\n";
                print "eval error: [$@]\n";
            }
            return $condition;
        }
    }
    while($param =~ /(\S+)\s+eq\s+"(.*?)"/){
        my ($var, $key)=($1, $2);
        my $keylen=length($key);
        $param=$`."strncmp($var, \"$key\", $keylen)==0".$';
    }
    if($param=~/(\w+)->\{(.*)\}/){
        my $t="\$"."(macro_hash_cond:$1,$2)";
        MyDef::compileutil::expand_macro_recurse(\$t);
        return $t;
    }
    elsif($param=~/^\w+\s*=\s*\w+\(.*\)\s*$/){
        return $param;
    }
    elsif($param!~/^\(.*\)$/ and $param=~/[^!><='"]=[^=]/){
        my $pre=$`;
        if($pre!~/['"]/){
            print "Assignment in [$param], possible bug? pre:[$pre]\n";
        }
        return $param;
    }
    else{
        return $param;
    }
}
sub do_assignment {
    my ($left, $right)=@_;
    if($debug eq "type"){
        print "do_assignment: $left = $right\n";
    }
    my $type;
    if($left=~/^(.*?)\s+(\S+)$/){
        $type=$1;
        $left=$2;
    }
    if($left=~/^\w+$/){
        my $var=find_var($left);
        if($var){
            push @$out, "$left=$right;";
            return;
        }
        else{
            func_add_var($left, $type, $right);
        }
    }
    else{
    }
    push @$out, "$left=$right;";
    return;
}
sub comma_split {
    my $l=shift;
    my @t;
    my $i0=0;
    my $n=length($l);
    my @wait_stack;
    my $cur_wait;
    my %pairlist=("'"=>"'", '"'=>'"', '('=>')', '['=>']', '{'=>'}');
    for(my $i=0; $i < $n; $i++){
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
sub last_exp {
    my ($l)=@_;
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
sub open_scope {
    my ($blk_name, $name)=@_;
    push @scope_stack, $cur_scope;
    $cur_scope={var_list=>[], var_hash=>{}, name=>$name};
}
sub close_scope {
    my ($blk_name)=@_;
    my $var_hash=$cur_scope->{var_hash};
    my $var_list=$cur_scope->{var_list};
    if(@$var_list){
        my $block=MyDef::compileutil::get_named_block($blk_name);
        foreach my $v (@$var_list){
            my $decl=var_declare($var_hash->{$v});
            push @$block, "$decl;";
        }
    }
    $cur_scope=pop @scope_stack;
}
sub open_function {
    my ($fname, $param)=@_;
    my $func= {param_list=>[], var_list=>[], var_hash=>{}, init=>[], finish=>[]};
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
    $cur_function=$func;
    my $fidx=MyDef::dumpout::add_function($func);
    return $fidx;
}
sub func_return {
    my ($l)=@_;
    MyDef::compileutil::trigger_block_post();
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
}
sub func_var_assign {
    my ($type, $name, $val)=@_;
    if($debug eq "type"){
        print "func_var_assign: $type $name = $val\n";
    }
    my $done_out;
    if(!$done_out){
        push @$out, "$name=$val;";
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
    my ($init, $array);
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
    if($array){
        $var->{array}=$array;
        if($type!~/\*$/ or $type_given){
            $var->{type}.="*";
        }
    }
    if($debug eq "type"){
        my $curfile=MyDef::compileutil::curfile_curline();
        print "[$curfile]", "\033[33m", "add_var: $type - $name ($array) - $init ($value)\n", "\033[m";
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
sub find_var {
    my ($name)=@_;
    if($debug eq "type"){
        print "  cur_scope\[$cur_scope->{name}]: ";
        foreach my $v (@{$cur_scope->{var_list}}){
            print "$v, ";
        }
        print "\n";
        for(my $i=$#scope_stack; $i >= 0; $i--){
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
    for(my $i=$#scope_stack; $i >= 0; $i--){
        if($scope_stack[$i]->{var_hash}->{$name}){
            return $scope_stack[$i]->{var_hash}->{$name};
        }
    }
    return undef;
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
        if($type0=~/(.*)\s*\*\s*$/){
            return get_sub_type($1, $tail);
        }
        else{
            my $curfile=MyDef::compileutil::curfile_curline();
            warn "[$curfile] error in dereferencing pointer type $type0\n";
            return "void";
        }
    }
    else{
        return $type0;
    }
}
sub protect_var {
    my ($var)=@_;
    if($protected_var{$var}){
        my $curfile=MyDef::compileutil::curfile_curline();
        print "[$curfile] Variable $var protected\n";
        $protected_var{$var}++;
    }
    else{
        $protected_var{$var}=1;
    }
}
sub hash_check {
    my ($h, $name)=@_;
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
    my $type = get_var_type($var);
    if($type=~/struct (\w+)/){
        return $1;
    }
    print "Warning: $var not a list type\n";
    return undef;
}
sub list_push {
    my ($out, $v, $val)=@_;
    my $name=get_list_type($v);
    if($name){
        func_add_var("p_$name\_node", "struct $name\_node *");
        push @$out, "p_$name\_node=$name\_push($v);";
        struct_set("$name\_node", "p_$name\_node", $val, $out);
    }
}
sub list_unshift {
    my ($out, $v, $val)=@_;
    my $name=get_list_type($v);
    if($name){
        func_add_var("p_$name\_node", "struct $name\_node *");
        push @$out, "p_$name\_node=$name\_unshift($v);";
        struct_set("$name\_node", "p_$name\_node", $val, $out);
    }
}
sub list_pop {
    my ($out, $v, $var)=@_;
    my $name=get_list_type($v);
    if($var){
        func_add_var("p_$name\_node", "struct $name\_node *");
        push @$out, "p_$name\_node=$name\_pop($v);";
        struct_get("$name\_node", "p_$name\_node", $var, $out);
    }
    else{
        push @$out, "$name\_pop($v);";
    }
}
sub list_shift {
    my ($out, $v, $var)=@_;
    my $name=get_list_type($v);
    if($var){
        func_add_var("p_$name\_node", "struct $name\_node *");
        push @$out, "p_$name\_node=$name\_shift($v);";
        struct_get("$name\_node", "p_$name\_node", $var, $out);
    }
    else{
        push @$out, "$name\_shift($v);";
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
            else{
                $key="<$f.h>";
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
            print "get_var_fmt: unhandled $v - $type\n";
        }
        return undef;
    }
}
sub fmt_string {
    my ($str)=@_;
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
    my @group;
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
            elsif($str=~/\G(\w+)/gc){
                push @arg_list, $1;
                push @fmt_list, get_var_fmt($1, 1);
                if($str=~/\G-/gc){
                }
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
    my $tail=$fmt_list[-1];
    if($tail=~/(.*)-$/){
        $fmt_list[-1]=$1;
    }
    elsif($tail!~/\\n$/){
        push @fmt_list, "\\n";
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
                if($dim!=1){
                    $var->{dimension}=$dim;
                }
            }
            my $type=pointer_type(get_var_type($p));
            if($dim == 1){
                push @$out, "$p=($type*)malloc(sizeof($type));";
            }
            else{
                push @$out, "$p=($type*)malloc($dim*sizeof($type));";
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
                if($dim!=1){
                    $var->{dimension}=$dim;
                }
            }
            my $type=pointer_type(get_var_type($p));
            if($dim == 1){
                push @$out, "$p=($type*)malloc(sizeof($type));";
            }
            else{
                push @$out, "$p=($type*)malloc($dim*sizeof($type));";
            }
            push @$post, "free($p);";
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
    if(!$func->{openblock}){
        my $declare=$func->{declare};
        if(!$declare){
            my $ret_type=$func->{ret_type};
            if(!$ret_type){$ret_type="void";};
            my $param_list=$func->{"param_list"};
            my $param=join(', ', @$param_list);
            $declare="$ret_type $name($param)";
            $func->{declare}=$declare;
        }
        $func->{openblock}=[$declare."{"];
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
    my $var_hash=$func->{var_hash};
    my $var_list=$func->{var_list};
    if(@$var_list){
        foreach my $v (@$var_list){
            if($global_hash->{$v}){
                print "  [warning] In $name: local variable $v has existing global\n";
            }
            my $decl=var_declare($var_hash->{$v});
            push @pre, "$decl;";
        }
        push @pre, "NEWLINE";
    }
    foreach my $tl (@{$func->{init}}){
        push @pre, $tl;
    }
    if(!$func->{has_return}){
        $cur_function=$func;
    }
    foreach my $tl (@{$func->{finish}}){
        push @post, $tl;
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
1;
