use strict;
package MyDef::output_lua;

our $debug=0;
our $out;
our $mode;
our $page;
our @globals;
our %globals;
our $case_if="if";
our $case_elif="elseif";
our @case_stack;
our $case_state;
our $fn_block=[];

sub get_interface {
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout);
}

sub init_page {
    my ($t_page)=@_;
    $page=$t_page;
    MyDef::set_page_extension("lua");
    my $init_mode="sub";
    @globals=();
    %globals=();
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
            my @src;
            if($case eq $case_if){
                push @src, "if $cond then";
                push @src, "INDENT";
                push @src, "BLOCK";
                push @src, "DEDENT";
                push @src, "end";
            }
            else{
                if($out->[-1] ne "end"){
                    my $curfile=MyDef::compileutil::curfile_curline();
                    print "[$curfile]\x1b[33m case: else missing end - [$out->[-1]]\n\x1b[0m";
                }
                pop @$out;
                push @src, "elseif $cond then";
                push @src, "INDENT";
                push @src, "BLOCK";
                push @src, "DEDENT";
                push @src, "end";
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
            if($out->[-1] ne "end"){
                my $curfile=MyDef::compileutil::curfile_curline();
                print "[$curfile]\x1b[33m case: else missing end - [$out->[-1]]\n\x1b[0m";
            }
            pop @$out;
            push @src, "else";
            push @src, "INDENT";
            push @src, "BLOCK";
            push @src, "DEDENT";
            push @src, "end";
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

        if($l=~/^\$(\w+)\s*(.*?)\s*$/){
            my ($func, $param)=($1, $2);
            if($func eq "global"){
                my @tlist = MyDef::utils::proper_split($param);
                foreach my $v (@tlist){
                    if(!$globals{$v}){
                        $globals{$v}=1;
                        push @globals, $v;
                    }
                }
                return 0;
            }
            elsif($func eq "print"){
                if($param=~/^".*",.+/){
                    push @$out, "io.write(string.format($param))";
                }
                else{
                    push @$out, "print(\"$param\")";
                }
                return 0;
            }
            elsif($func eq "dump"){
                push @$out, "print($param)";
                return 0;
            }
            elsif($func eq "while"){
                return single_block("while $param do", "end", "while");
            }
            elsif($func eq "for"){
                $param =~s/:/, /g;
                return single_block("for $param do", "end", "for");
            }
        }
        elsif($l=~/^NOOP POST_MAIN/){
            my $old_out=MyDef::compileutil::set_output($fn_block);
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
                    if(!$code->{_listed}){
                        my $pline;
                        my $params=$code->{params};
                        if($#$params>=0){
                            $pline=join(", ", @$params);
                        }

                        push @$out, "function $name($pline)";
                        push @$out, "INDENT";
                        $code->{scope}="list_sub";
                        MyDef::compileutil::list_sub($code);
                        push @$out, "DEDENT";
                        push @$out, "end";
                        push @$out, "NEWLINE";
                    }
                }
            }
            MyDef::compileutil::set_output($old_out);
            return 0;
        }
    }
    if($l=~/^(.+?)\s*([\+\-\*\/])=\s*(.*)/){
        $l = "$1 = $1 $2 $3";
    }
    push @$out, $l;
    return 0;
}

sub dumpout {
    my ($f, $out)=@_;
    my $dump={out=>$out,f=>$f};
    parsecode("NOOP");
    if(@globals){
        foreach my $v (@globals){
            push @$f, "$v";
        }
        push @$f, "\n";
    }

    if(@$fn_block){
        $dump->{fn_block} = $fn_block;
        unshift @$out, "INCLUDE_BLOCK fn_block";
    }
    unshift @$out, "DUMP_STUB global_init";
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

1;
