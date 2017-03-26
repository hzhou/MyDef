use strict;
package MyDef::output_fortran;
our $debug=0;
our $out;
our $mode;
our $page;
our $label_index;
our $case_if="IF";
our $case_elif="ELSEIF";
our @case_stack;
our $case_state;
our $case_wrap;
our $global_hash={};
our $global_list=[];
our $cur_function;
our @function_list;

sub get_label {
    $label_index++;
    return sprintf("%d", $label_index*10);
}

sub fortran_break_line {
    my ($l) = @_;
    my $limit = 72-6;
    my @line_list;
    my $len = length($l);
    my $i = 0;
    while($i<$len){
        my $j = $i+$limit-1;
        if($j>$len){
            $j=$len;
        }
        else{
            my $last_type;
            for(my $k=0; $k <10; $k++){
                my $type;
                my $c = substr($l, $j-$k, 1);
                if($c eq ' '){
                    $type=1;
                }
                elsif($c =~/[\(\[\{\}\]\)]/){
                    $type=3;
                }
                elsif($c=~/\w/){
                    $type=2;
                }
                else{
                    $type=4;
                }
                if($last_type && $type != $last_type){
                    $j=$j-$k+1;
                    last;
                }
                $last_type = $type;
            }
        }
        push @line_list, substr($l, $i, $j-$i);
        $i=$j;
    }
    return \@line_list;
}

sub open_function {
    my ($name, $param) = @_;
    my $func={param_list=>[], var_list=>[], var_hash=>{}, init=>[], finish=>[]};
    $func->{name}=$name;
    $cur_function=$func;
    if($param){
        my $param_list = $func->{param_list};
        my $var_hash = $func->{var_hash};
        my @plist = split /,\s*/, $param;
        foreach my $p (@plist){
            my ($type, $name, $dim)=parse_var($p);
            $var_hash->{$name}={name=>$name, type=>$type, dim=>$dim};
            push @$param_list, $name;
        }
    }
    return $func;
}

sub parse_var {
    my ($p) = @_;
    my ($type, $name, $dim);
    if($p=~/(\S.*)\s+(\S+)\s*$/){
        ($type, $name)=($1, $2);
    }
    else{
        $name=$p;
        if($p=~/^f/i){
            $type="REAL";
        }
        elsif($p=~/^d/i){
            $type="DOUBLE PRECISION";
        }
        elsif($p=~/^s/i){
            $type="CHARACTER";
        }
        elsif($p=~/^[ijklmn]/i){
            $type="INTEGER";
        }
        else{
            $type="REAL";
        }
    }
    if($name=~/(\w+)\((.*)\)/){
        $name=$1;
        $dim =$2;
    }
    return ($type, $name, $dim);
}

sub process_function {
    my ($func) = @_;
    my $name=$func->{name};
    my $open = $func->{openblock};
    my $pre = $func->{preblock};
    my $post = $func->{postblock};
    my $close = $func->{closeblock};
    my $ret_type = $func->{ret_type};
    my $param_list = $func->{param_list};
    my $param = join(', ', @$param_list);
    if(!$ret_type){
        push @$open, "SUBROUTINE $name($param)";
    }
    else{
        push @$open, "$ret_type FUNCTION $name($param)";
    }
    my $var_hash=$func->{var_hash};
    my $var_list=$func->{var_list};
    my %type_list;
    foreach my $p (@$param_list, @$var_list){
        my $type=$var_hash->{$p}->{type};
        my $name=$p;
        if($var_hash->{$p}->{dim}){
            $name.="(".$var_hash->{$p}->{dim}.")";
        }
        if(!$type_list{$type}){
            $type_list{$type}=[];
        }
        push @{$type_list{$type}}, $name;
    }
    while (my ($k, $v) = each %type_list){
        push @$pre, "$k ".join(", ", @$v);
    }
    push @$close, "END";
}

sub parse_fmt {
    my ($s_fmt, $s_vlist) = @_;
    my @fmt_list;
    my @segs = split /(%[0-9\.]*[fgd])/, $s_fmt;
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
        }
        else{
            push @fmt_list, "'$s'";
        }
    }
    return (join(",", @fmt_list), $s_vlist);
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
    return ($func, \@block);
}

sub get_interface {
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout);
}
sub init_page {
    my ($t_page)=@_;
    $page=$t_page;
    MyDef::set_page_extension("f");
    my $init_mode="sub";
    $label_index=0;
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
    if($l=~/^\x24(if|elif|elsif|elseif|case)\s+(.*)$/){
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
        push @$out, "$case ($cond) THEN";
        push @$out, "INDENT";
        push @$out, "BLOCK";
        push @$out, "DEDENT";
        if($case eq "IF"){
            if(!$case_wrap){
                $case_wrap=[];
            }
            push @$case_wrap, "ENDIF";
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
    elsif($l=~/^\$else/){
        if(!$case_state and $l!~/NoWarn/i){
            my $curfile=MyDef::compileutil::curfile_curline();
            print "[$curfile]\x1b[33m Dangling \$else\n\x1b[0m";
        }
        push @$out, "ELSE";
        push @$out, "INDENT";
        push @$out, "BLOCK";
        push @$out, "DEDENT";
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
            my $case=$case_if;
            my $cond=$1;
            push @$out, "$case ($cond) THEN";
            push @$out, "INDENT";
            push @$out, "BLOCK";
            push @$out, "DEDENT";
            if($case eq "IF"){
                if(!$case_wrap){
                    $case_wrap=[];
                }
                push @$case_wrap, "ENDIF";
            }
        }
        else{
            my $case=$case_elif;
            my $cond=$1;
            push @$out, "$case ($cond) THEN";
            push @$out, "INDENT";
            push @$out, "BLOCK";
            push @$out, "DEDENT";
            if($case eq "IF"){
                if(!$case_wrap){
                    $case_wrap=[];
                }
                push @$case_wrap, "ENDIF";
            }
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
            return 0;
        }
    }
    if(!$case_state){
        if($case_wrap){
            push @$out, @$case_wrap;
            undef $case_wrap;
        }
    }
    if($l=~/^\$(\w+)\s*(.*?)\s*$/){
        my ($func, $param)=($1, $2);
        if($func eq "while"){
            if($param eq "1"){
                return single_block("DO", "END DO");
            }
            else{
                return single_block("DO WHILE ($param)", "END DO");
            }
        }
        elsif($func eq "for"){
            return single_block("DO $param", "END DO");
        }
        elsif($func =~/^(return_type|parameter|lexical)$/){
            if($cur_function){
                my $func=$cur_function;
                if($1 eq "return_type"){
                    $func->{ret_type}=$param;
                }
                elsif($1 eq "parameter"){
                    my $param_list = $func->{param_list};
                    my $var_hash = $func->{var_hash};
                    my @plist = split /,\s*/, $param;
                    foreach my $p (@plist){
                        my ($type, $name, $dim)=parse_var($p);
                        $var_hash->{$name}={name=>$name, type=>$type, dim=>$dim};
                        push @$param_list, $name;
                    }
                }
            }
            return;
        }
        elsif($func =~/^(global|local)$/){
            my ($var_hash, $var_list);
            if($1 eq "global"){
                $var_hash=$global_hash;
                $var_list=$global_list;
            }
            elsif($cur_function){
                $var_hash=$cur_function->{var_hash};
                $var_list=$cur_function->{var_list};
            }
            my @plist=split /,\s*/, $param;
            foreach my $p (@plist){
                my ($type, $name, $dim)=parse_var($p);
                if(!$var_hash->{$name}){
                    $var_hash->{$name}={name=>$name, type=>$type, dim=>$dim};
                    push @$var_list, $name;
                }
            }
        }
        elsif($func eq "print"){
            if($param=~/^"(.*)",(.*)/){
                my ($fmt, $vlist)=parse_fmt($1, $2);
                my $label = get_label();
                push @$out, "Print $label, $vlist";
                push @$out, "LABEL $label";
                push @$out, "Format ($fmt)";
                return;
            }
        }
    }
    elsif($l=~/^NOOP POST_MAIN/){
        push @$out, "END";
        push @$out, "NEWLINE";
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
                my $codename=$name;
                my $funcname=$name;
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
                        if($funcname eq "n_main" or $funcname eq "main2"){
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
                                MyDef::compileutil::list_sub($codelib);
                                if($out->[-1]=~/^return/){
                                    $$func->{return}=pop @$out;
                                }
                                @case_stack=();
                                undef $case_state;
                                if($case_wrap){
                                    push @$out, @$case_wrap;
                                    undef $case_wrap;
                                }
                            }
                            else{
                                push @$out, $l;
                            }
                        }
                    }
                }
            }
        }
        return 0;
    }
    push @$out, $l;
    return 0;
}
sub dumpout {
    my ($f, $out, $pagetype)=@_;
    my $dump={out=>$out,f=>$f, module=>"output_fortran"};
    foreach my $func (@function_list){
        process_function($func);
    }
    my @out2;
    $dump->{f}=\@out2;
    push @out2, "PROGRAM $page->{pagename}";
    my %type_list;
    foreach my $p (@$global_list){
        my $type=$global_hash->{$p}->{type};
        my $name=$p;
        if($global_hash->{$p}->{dim}){
            $name.="(".$global_hash->{$p}->{dim}.")";
        }
        if(!$type_list{$type}){
            $type_list{$type}=[];
        }
        push @{$type_list{$type}}, $name;
    }
    while (my ($k, $v) = each %type_list){
        push @out2, "$k ".join(", ", @$v);
    }
    MyDef::dumpout::dumpout($dump);
    my $label;
    foreach my $l (@out2){
        chomp $l;
        if($l=~/^\s*LABEL\s+(\d+)/){
            $label=sprintf("%5d ", $1);
        }
        else{
            my $prefix;
            if($label){
                $prefix=$label;
                undef $label;
            }
            else{
                $prefix=' ' x 6;
            }
            if(length($l)>72-6){
                my $line_list = fortran_break_line($l);
                foreach my $l2 (@$line_list){
                    push @$f, "$prefix$l2\n";
                    $prefix = '     &';
                }
            }
            else{
                push @$f, "$prefix$l\n";
            }
        }
    }
    return;
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
1;
