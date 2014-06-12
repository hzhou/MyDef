use strict;
package MyDef::output_perl;
our $case_if="if";
our $case_elif="elsif";
our @case_stack;
our $case_state;
our $case_wrap;
our $case_flag="\$b_flag_case";
our $debug;
our $mode;
our $page;
our $out;
our @globals;
our %globals;
sub get_interface {
    my $interface_type="perl";
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout, $interface_type);
}
sub init_page {
    ($page)=@_;
    my $ext="pl";
    if($MyDef::var->{filetype}){
        $ext=$MyDef::var->{filetype};
    }
    if($page->{type}){
        $ext=$page->{type};
    }
    if($page->{package} and !$page->{type}){
        $page->{type}="pm";
        $ext="pm";
    }
    elsif(!$page->{package} and $page->{type} eq "pm"){
        $page->{package}=$page->{pagename};
    }
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
            push @$out, "my \$b_flag_case=1;";
            MyDef::compileutil::call_sub($1, "\$call");
            single_block("if($case_flag){", "}");
        }
        else{
            push @$out, "else{";
            push @$out, "INDENT";
            push @$out, "my \$b_flag_case=1;";
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
            push @$out, "my \$b_flag_case=0;";
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
        if($func =~ /^global$/){
            $param=~s/\s*;\s*$//;
            my @tlist=MyDef::utils::proper_split($param);
            foreach my $v (@tlist){
                if(!$globals{$v}){
                    $globals{$v}=1;
                    push @globals, $v;
                }
            }
            return 0;
        }
        elsif($func eq "sub"){
            if($param=~/^(\w+)\((.*)\)/){
                return single_block_pre_post(["sub $1 {", "INDENT", "my ($2)=\@_;"], ["DEDENT", "}"], "sub");
            }
            else{
                return single_block("sub $param {", "}", "sub");
            }
        }
        elsif($func =~ /^(while)$/){
            return single_block("$1($param){", "}");
        }
        elsif($func eq "for"){
            if($param=~/(.*);(.*);(.*)/){
                single_block("for($param){", "}");
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
                if($var=~/^(\w+)/){
                    $var='$'.$var;
                }
                $param="my $var=$i0; $var $i1; $var$step";
                single_block("for($param){", "}");
                return "NEWBLOCK-for";
            }
        }
        elsif($func eq "foreach"){
            if($param=~/(\S+)\s+in\s+(.*)/){
                my ($var, $list)=($1, $2);
                if($var=~/^(\w+)/){
                    $var='$'.$var;
                }
                return single_block("foreach my $var ($list){", "}", "foreach");
            }
        }
    }
    if($l=~/^\s*$/){
    }
    elsif($l=~/^\s*(break|continue);?\s*$/){
        if($1 eq "break"){
            $l="last;";
        }
        elsif($l eq "continue"){
            $l="next;";
        }
    }
    elsif($l=~/^\s*(for|while|if|else if)\s*\(.*\)\s*$/){
    }
    elsif($l=~/^\s*}/){
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
    if(!defined $pagetype or $pagetype eq "pl"){
        push @$f, "#!/usr/bin/perl\n";
    }
    push @$f, "use strict;\n";
    if($MyDef::page->{package}){
        push @$f, "package ".$MyDef::page->{package}.";\n";
    }
    foreach my $v (@globals){
        push @$f, "our $v;\n";
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
