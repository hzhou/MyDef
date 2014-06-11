use strict;
package MyDef::output_perl;
our $case_flag="\$b_flag_case";
our $case_flag_set="my \$b_flag_case=1;";
our $case_flag_reset="\$b_flag_case=0;";
our $case_if="if";
our $case_elif="elsif";
our @case_stack;
our $case_state;
our $case_wrap;
use MyDef::dumpout;
use MyDef::utils;
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
        my $case;
        if($1 eq "if"){
            $case=$case_if;
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
        push @$out, "$case($cond){";
        push @$out, "INDENT";
        push @$out, "BLOCK";
        push @$out, "DEDENT";
        push @$out, "}";
        push @$out, "PARSE:CASEPOP";
        push @case_stack, {state=>"if", wrap=>$case_wrap};
        undef $case_state;
        undef $case_wrap;
        if($debug eq "case"){
            my $level=@case_stack;
            print "Entering case [$level]: $l\n";
        }
        return "NEWBLOCK";
    }
    elsif($l=~/^\&case\s+(.*)/){
        if(!$case_state){
            push @$out, $case_flag_set;
            MyDef::compileutil::call_sub($1, "\$call");
            push @$out, "if($case_flag){";
            push @$out, "INDENT";
            push @$out, "BLOCK";
            push @$out, "DEDENT";
            push @$out, "}";
        }
        else{
            push @$out, "else{";
            push @$out, "INDENT";
            push @$out, $case_flag_set;
            MyDef::compileutil::call_sub($1, "\$call");
            push @$out, "if($case_flag){";
            push @$out, "INDENT";
            push @$out, "BLOCK";
            push @$out, "DEDENT";
            push @$out, "}";
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
        return "NEWBLOCK";
    }
    elsif($l=~/^\$else/){
        if(!$case_state and $l!~/NoWarn/i){
            my $pos=MyDef::compileutil::curfile_curline();
            print "[$pos]Dangling \$else \n";
        }
        push @$out, "else{";
        push @$out, "INDENT";
        push @$out, "BLOCK";
        push @$out, "DEDENT";
        push @$out, "}";
        push @$out, "PARSE:CASEPOP";
        push @case_stack, {state=>undef, wrap=>$case_wrap};
        undef $case_state;
        undef $case_wrap;
        if($debug eq "case"){
            my $level=@case_stack;
            print "Entering case [$level]: $l\n";
        }
        return "NEWBLOCK";
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
            push @$out, $case_flag_reset;
            return 0;
        }
    }
    if($case_wrap and !$case_state){
        push @$out, @$case_wrap;
        undef $case_wrap;
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
        elsif($func =~ /^(while)$/){
            return single_block("$1($param){", "}");
        }
        elsif($func eq "sub"){
            if($param=~/^(\w+)\((.*)\)/){
                return single_block_pre_post(["sub $1 {", "INDENT", "my ($2)=\@_;"], ["DEDENT", "}"]);
            }
            else{
                return single_block("sub $param {", "}");
            }
        }
        elsif($func eq "for" or $func eq "foreach"){
            if($param=~/(\$\w+)=(.*?):(.*?)(:.*)?$/){
                my ($var, $i0, $i1, $step)=($1, $2, $3, $4);
                my $stepclause;
                if($step){
                    my $t=substr($step, 1);
                    if($t eq "-1"){
                        $stepclause="my $var=$i0;$var>$i1;$var--";
                    }
                    elsif($t=~/^-/){
                        $stepclause="my $var=$i0;$var>$i1;$var=$var$t";
                    }
                    else{
                        $stepclause="my $var=$i0;$var<$i1;$var+=$t";
                    }
                }
                else{
                    if($i1 eq "0"){
                        $stepclause="my $var=$i0-1;$var>=0;$var--";
                    }
                    elsif($i1=~/^-?\d+/ and $i0=~/^-?\d+/ and $i1<$i0){
                        $stepclause="my $var=$i0;$var>$i1;$var--";
                    }
                    else{
                        $stepclause="my $var=$i0;$var<$i1;$var++";
                    }
                }
                return single_block("for($stepclause){", "}")
            }
            elsif($param=~/(\$\w+)\s+(in\s+)?(.*)/){
                my ($var, $list)=($1, $3);
                if($list!~/^(@|keys|sort)/ and $list!~/,/){
                    warn "  foreach ($list) -- does not look like an array\n";
                }
                return single_block("foreach my $var ($list){", "}");
            }
            else{
                return single_block("$func($param){", "}");
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
    my ($t1, $t2)=@_;
    push @$out, "$t1";
    push @$out, "INDENT";
    push @$out, "BLOCK";
    push @$out, "DEDENT";
    push @$out, "$t2";
    return "NEWBLOCK";
}
sub single_block_pre_post {
    my ($pre, $post)=@_;
    if($pre){
        push @$out, @$pre;
    }
    push @$out, "BLOCK";
    if($post){
        push @$out, @$post;
    }
    return "NEWBLOCK";
}
1;
