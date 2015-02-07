use strict;
package MyDef::output_matlab;
our $debug;
our $out;
our $mode;
our $page;
our $case_if="if";
our $case_elif="elseif";
our @case_stack;
our $case_state;
our $case_wrap;
our @func_input;
our $func_varargin;
our @func_return;
our $func_varargout;

sub get_interface {
    my $interface_type="matlab";
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout, $interface_type);
}
sub init_page {
    my ($t_page)=@_;
    $page=$t_page;
    MyDef::set_page_extension("m");
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
        push @$out, "$case $cond";
        push @$out, "INDENT";
        push @$out, "BLOCK";
        push @$out, "DEDENT";
        if($case eq "if"){
            if(!$case_wrap){
                $case_wrap=[];
            }
            push @$case_wrap, "end";
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
            my $pos=MyDef::compileutil::curfile_curline();
            print "[$pos]Dangling \$else \n";
        }
        push @$out, "else";
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
            push @$out, "$case $cond";
            push @$out, "INDENT";
            push @$out, "BLOCK";
            push @$out, "DEDENT";
            if($case eq "if"){
                if(!$case_wrap){
                    $case_wrap=[];
                }
                push @$case_wrap, "end";
            }
        }
        else{
            my $case=$case_elif;
            my $cond=$1;
            push @$out, "$case $cond";
            push @$out, "INDENT";
            push @$out, "BLOCK";
            push @$out, "DEDENT";
            if($case eq "if"){
                if(!$case_wrap){
                    $case_wrap=[];
                }
                push @$case_wrap, "end";
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
    if($l=~/^\s*\$(\w+)\s*(.*)$/){
        my $func=$1;
        my $param=$2;
        if($func =~ /^(while|for)$/){
            return single_block("$1 $param", "end");
        }
        elsif($func=~/^input/){
            if($param=~/^\s*varargin(.*)/){
                $func_varargin=1;
                $param=$1;
                $param=~s/^\s*[:,]?\s*//;
            }
            if($param){
                @func_input=split /,\s*/, $param;
            }
            return 0;
        }
        elsif($func=~/^return/){
            if($param=~/^\s*varargout(.*)/){
                $func_varargout=1;
                $param=$1;
                $param=~s/^\s*[:,]?\s*//;
            }
            if($param){
                push @func_return, split /,\s*/, $param;
            }
            return 0;
        }
    }
    if($l=~/^\s*$/){
    }
    elsif($l=~/(for|while|if|elseif)\s*\(.*\)\s*$/){
    }
    elsif($l!~/[,:\(\[\{;]\s*$/){
        $l.=";";
    }
    else{
    }
    push @$out, $l;
    return 0;
}
sub dumpout {
    my ($f, $out, $pagetype)=@_;
    my $dump={out=>$out,f=>$f};
    parsecode("NOOP");
    my ($input, $return, @vararg);
    if(@func_return){
        if(!@func_input){
            $input="varargin";
        }
        else{
            my $idx=0;
            my (@arg_1, @arg_2, @arg_v);
            my $flag_varargin;
            foreach my $a (@func_input){
                $idx++;
                if(!$flag_varargin){
                    if($a=~/(\w+)=/){
                        $flag_varargin=$idx;
                        push @arg_1, "varargin";
                    }
                    else{
                        push @arg_1, $a;
                    }
                }
                if($flag_varargin){
                    if($a=~/(\w+)=(.*)/){
                        push @arg_2, $1;
                        push @arg_v, $2;
                    }
                    else{
                        push @arg_2, $a;
                        push @arg_v, "0";
                    }
                }
            }
            $input=join(", ", @arg_1);
            for(my $i=0; $i <@arg_2; $i++){
                my $var=$arg_2[$i];
                my $val=$arg_v[$i];
                my $i1=$i+1;
                my $i2=$i+$flag_varargin;
                push @vararg, "if nargin>=$i2\n";
                push @vararg, "    $var=varargin\{$i1\};\n";
                push @vararg, "else\n";
                push @vararg, "    $var=$val;\n";
                push @vararg, "end\n";
            }
        }
        if($func_varargout){
            $return="varargout";
        }
        elsif(@func_return>1){
            $return="[".join(", ", @func_return)."]";
        }
        else{
            $return=$func_return[0];
        }
        my $fline="function $return=".$page->{pagename}."($input)";
        push @$f, "$fline\n\n";
        if(@vararg){
            push @$f, @vararg;
            push @$f, "\n";
        }
    }
    if($func_varargout){
        push @$out, "\n";
        push @$out, "if nargout<=1\n";
        push @$out, "    varargout{1}=[".join(", ", @func_return)."];\n";
        push @$out, "else\n";
        for(my $i=0; $i <@func_return; $i++){
            my $idx=$i+1;
            push @$out, "    varargout{$idx}=$func_return[$i];\n";
        }
        push @$out, "end\n";
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
1;
