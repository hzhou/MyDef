use strict;
package MyDef::output_sh;

our $debug=0;
our $out;
our $mode;
our $page;
our $case_if="if";
our $case_elif="elif";
our @case_stack;
our $case_state;

sub get_interface {
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout);
}

sub init_page {
    my ($t_page)=@_;
    $page=$t_page;
    MyDef::set_page_extension("sh");
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

    if($l=~/^\$warn (.*)/){
        my $curfile=MyDef::compileutil::curfile_curline();
        print "[$curfile]\x1b[33m $1\n\x1b[0m";
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
    if($l!~/;\s*$/){

        if($debug eq "case"){
            my $level=@case_stack;
            print "        $level:[$case_state]$l\n";
        }

        if($l=~/^\x24(if|elif|elsif|elseif|case)\s+(.*)$/){
            my $cond=$2;
            my $case=$case_if;
            if($1 eq "if"){
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
            if($case eq $case_if){
                push @src, "if $cond; then";
                push @src, "INDENT";
                push @src, "BLOCK";
                push @src, "DEDENT";
                push @src, "fi";
            }
            else{
                if($out->[-1] ne "fi"){
                    my $curfile=MyDef::compileutil::curfile_curline();
                    print "[$curfile]\x1b[33m case: else missing fi - [$out->[-1]]\n\x1b[0m";
                }
                pop @$out;
                push @src, "elif $cond; then";
                push @src, "INDENT";
                push @src, "BLOCK";
                push @src, "DEDENT";
                push @src, "fi";
            }
            push @src, "PARSE:CASEPOP";
            push @case_stack, {state=>"if"};

            undef $case_state;
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
            if($out->[-1] ne "fi"){
                my $curfile=MyDef::compileutil::curfile_curline();
                print "[$curfile]\x1b[33m case: else missing fi - [$out->[-1]]\n\x1b[0m";
            }
            pop @$out;
            push @src, "else";
            push @src, "INDENT";
            push @src, "BLOCK";
            push @src, "DEDENT";
            push @src, "fi";
            push @src, "PARSE:CASEPOP";
            push @case_stack, {state=>undef};

            undef $case_state;
            if($debug eq "case"){
                my $level=@case_stack;
                print "Entering case [$level]: $l\n";
            }
            MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
            return "NEWBLOCK-else";
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
                }
                return 0;
            }
        }

        if($l=~/^\$for(?:each)?\s+(\w+)\s+in\s+(.+)/){
            return single_block("for $1 in $2; do", "done");
        }
        elsif($l=~/^\$switch\s+(.+)/){
            return single_block("case $1 in", "esac");
        }
        elsif($l=~/^\$of\s*(.+)/){
            my @src;
            push @src, "$1)";
            push @src, "INDENT";
            push @src, "BLOCK";
            push @src, ";;";
            push @src, "DEDENT";
            MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
            return "NEWBLOCK-of";
        }
        elsif($l=~/^\$print\s*(.*)/){
            push @$out, "echo $1";
            return;
        }
        if($l=~/^(\w+)(\s*=\s*)(.*)/){
            my ($v, $eq, $t) = ($1, $2, $3);
            if($eq ne "="){
                $l = "$v=$t";
            }
        }
    }
    push @$out, $l;
    return 0;
}

sub dumpout {
    my ($f, $out)=@_;
    my $dump={out=>$out,f=>$f};
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

# ---- subroutines --------------------------------------------
sub parse_condition {
    my ($cond) = @_;
    my @tlist;
    if($cond=~/^!\s*(.*)/){
        push @tlist, "test", "!";
        goto next_test;
    }

    my ($test, $t) = shift_test($cond);
    if(!defined $test){
        return $cond;
    }
    else{
        push @tlist, "test", $test;
    }

    while(1){
        if($t=~/^\s*(&&|\|\||-a|-o)\s*(.*)/){
            my $op=$1;
            $t=$2;
            if($op eq "&&"){
                $op = "-a";
            }
            elsif($op eq "||"){
                $op = "-o";
            }
            push @tlist, $op;
        }
        else{
            if($t){
                my $curfile=MyDef::compileutil::curfile_curline();
                print "[$curfile]\x1b[33m error parsing condition [...$t]\n\x1b[0m";
                push @tlist, $t;
            }
            last;
        }

        next_test:
        ($test, $t) = shift_test($t);
        if(!defined $test){
            my $curfile=MyDef::compileutil::curfile_curline();
            print "[$curfile]\x1b[33m error parsing condition, not a test [$cond]\n\x1b[0m";
            return $cond;
        }
        else{
            push @tlist, $test;
        }
    }

    return join(' ', @tlist);
}

sub shift_arg {
    my ($t) = @_;
    $t=~s/^\s+//;
    if($t=~/^"([^"\\]|\\.)*"/){
        return ($&, $');
    }
    if($t=~/^'([^'\\]|\\.)*'/){
        return ($&, $');
    }
    if($t=~/^`([^`\\]|\\.)*`/){
        return ($&, $');
    }
    if($t=~/^\$\([^)]*\)/){
        return ($&, $');
    }
    if($t=~/^\$\{[^)]*\}/){
        return ($&, $');
    }
    if($t=~/^([^\s\\]|\\.)+/){
        return ($&, $');
    }
    return $t;
}

sub shift_test {
    my ($t) = @_;
    if($t=~/^\s*-(\w)\s+(.*)/){
        my ($o, $t) = ($1, $2);
        my ($arg, $t)=shift_arg($t);
        return ("-$o $arg", $t);
    }
    if($t=~/^("(?:[^"\\]|\\.)*")(.*)/){
        my ($a, $t) = ($1, $2);
        if($t=~/^\s*([><=!]+|-[no]t\b)(.*)/){
            my ($op, $t) = ($1, $2);
            my ($b, $t) = shift_arg($t);
            if($op =~/=/){
                if($a=~/\$\w+/){
                    $a = "x$a";
                    $b = "x$b";
                }
            }
            return ("$a $op $b", $t);
        }
        else{
            return undef;
        }
    }
    if($t=~/^('(?:[^'\\]|\\.)*')(.*)/){
        my ($a, $t) = ($1, $2);
        if($t=~/^\s*([><=!]+|-[no]t\b)(.*)/){
            my ($op, $t) = ($1, $2);
            my ($b, $t) = shift_arg($t);
            if($op =~/=/){
                if($a=~/\$\w+/){
                    $a = "x$a";
                    $b = "x$b";
                }
            }
            return ("$a $op $b", $t);
        }
        else{
            return undef;
        }
    }
    if($t=~/^(\$\w+)(.*)/){
        my ($a, $t) = ($1, $2);
        if($t=~/^\s*([><=!]+|-[no]t\b)(.*)/){
            my ($op, $t) = ($1, $2);
            my ($b, $t) = shift_arg($t);
            if($op =~/=/){
                if($a=~/\$\w+/){
                    $a = "x$a";
                    $b = "x$b";
                }
            }
            return ("$a $op $b", $t);
        }
        else{
            return undef;
        }
    }
    return undef;
}

sub count_args {
    my ($t) = @_;
    my $cnt=0;
    while(length($t)>0){
        my $arg;
        ($arg, $t)=shift_arg($t);
        $cnt++;
    }

    return $cnt;
}

1;
