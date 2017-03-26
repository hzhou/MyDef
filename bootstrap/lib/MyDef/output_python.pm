use strict;
package MyDef::output_python;
our $debug=0;
our $out;
our $mode;
our $page;
our @globals;
our %globals;
our @imports;
our %imports;
our $re_index=0;
our %re_cache;
our $fn_block=[];

sub parse_function {
    my ($name, $code) = @_;
    my $pline;
    my $params=$code->{params};
    if($#$params>=0){
        $pline=join(", ", @$params);
    }
    push @$out, "def $name($pline):";
    push @$out, "INDENT";
    my $codes=$code->{codes};
    my $cnt=0;
    my $macro={};
    if($code->{macros}){
        while (my ($k, $v) = each %{$code->{macros}}){
            $macro->{$k}=$v;
        }
    }
    if($code->{codes}){
        $macro->{"codes"}=$code->{codes};
    }
    push @{$MyDef::compileutil::deflist}, $macro;
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
                parse_function($name, $code);
                $cnt++;
            }
        }
    }
    pop @{$MyDef::compileutil::deflist};
    if($cnt>0){
        push @$out, "NEWLINE";
    }
    $code->{scope}="list_sub";
    MyDef::compileutil::list_sub($code);
    push @$out, "DEDENT";
    push @$out, "NEWLINE";
}

sub get_interface {
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout);
}
sub init_page {
    my ($t_page)=@_;
    $page=$t_page;
    MyDef::set_page_extension("py");
    my $init_mode="sub";
    @globals=();
    %globals=();
    @imports=();
    %imports=();
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
    elsif($l=~/^\$template\s*(.*)/){
        open In, $1 or die "Can't open template $1\n";
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
    if($l=~/^\$(\w+)\s*(.*?)\s*$/){
        my ($func, $param)=($1, $2);
        if($func eq "global"){
            my @tlist = MyDef::utils::proper_split($param);
            foreach my $v (@tlist){
                my $t_name=$v;
                if($v=~/^(\S+)\s*=/){
                    $t_name=$1;
                }
                if(!$globals{$t_name}){
                    $globals{$t_name}=1;
                    push @globals, $v;
                }
            }
            return 0;
        }
        elsif($func eq "import"){
            my $t_name=$param;
            if($param=~/^(\S+)\s*=/){
                $t_name=$1;
            }
            if(!$imports{$t_name}){
                $imports{$t_name}=1;
                push @imports, $param;
            }
            return 0;
        }
        elsif($func eq "list"){
            my @tlist=split /,\s*/, $param;
            foreach my $name (@tlist){
                my $code = $MyDef::def->{codes}->{$name};
                parse_function($name, $code);
                $code->{_listed}=1;
            }
            return 0;
        }
        elsif($func=~/^(if|elif|while)$/){
            push @$out, "$func $param:";
            return 0;
        }
        elsif($func=~/^(def|for)$/){
            push @$out, "$func $param:";
            return 0;
        }
        elsif($func=~/^do$/){
            push @$out, "while 1: # \$do";
            push @$out, "INDENT";
            push @$out, "BLOCK";
            push @$out, "break";
            push @$out, "DEDENT";
            return "NEWBLOCK-do";
        }
        elsif($func eq "else"){
            push @$out, "else:";
            return 0;
        }
        elsif($func eq "print"){
            my $str=$param;
            my $need_escape;
            if($str=~/^\s*\"(.*)\"\s*$/){
                $str=$1;
            }
            else{
                $need_escape=1;
            }
            my %colors=(red=>31,green=>32,yellow=>33,blue=>34,magenta=>35,cyan=>36);
            my @fmt_list;
            my @seg_list;
            my @group;
            my $n_escape=0;
            while(1){
                if($str=~/\G$/gc){
                    last;
                }
                elsif($str=~/\G\$/gc){
                    if($str=~/\G(red|green|yellow|blue|magenta|cyan)/gc){
                        push @fmt_list, "\\x1b[$colors{$1}m";
                        $n_escape++;
                        if($str=~/\G\{/gc){
                            push @group, $1;
                        }
                    }
                    elsif($str=~/\G(\w+)/gc){
                        if(@fmt_list){
                            my $t = join('', @fmt_list);
                            @fmt_list=();
                            push @seg_list, "\"$t\"";
                        }
                        push @seg_list, $1;
                    }
                    else{
                        push @fmt_list, '$';
                    }
                }
                elsif($str=~/\G(\\.)/gc){
                    push @fmt_list, $1;
                }
                elsif($str=~/\G"/gc){
                    if($need_escape){
                        push @fmt_list, "\\\"";
                    }
                    else{
                        push @fmt_list, "\"";
                    }
                }
                elsif($str=~/\G\}/gc){
                    if(@group){
                        pop @group;
                        if(!@group){
                            push @fmt_list, "\\x1b[0m";
                            $n_escape=0;
                        }
                        else{
                            my $c=$group[-1];
                            push @fmt_list, "\\x1b[$colors{$c}m";
                            $n_escape++;
                        }
                    }
                    else{
                        push @fmt_list, '}';
                    }
                }
                elsif($str=~/\G[^\$\}"]+/gc){
                    push @fmt_list, $&;
                }
            }
            if(@fmt_list){
                my $t = join('', @fmt_list);
                @fmt_list=();
                push @seg_list, "\"$t\"";
            }
            my $tail=$fmt_list[-1];
            if($tail=~/(.*)-$/){
                $fmt_list[-1]=$1;
            }
            elsif($tail!~/\\n$/){
                push @fmt_list, "\\n";
            }
            if($n_escape){
                push @fmt_list, "\\x1b[0m";
            }
            my $p = "print";
            push @$out, "$p(".join(', ',@seg_list).");";
            return;
        }
        elsif($func eq "if_match"){
            my $n=0;
            if(length($param)==1 and $param!~/\w/){
                return single_block_pre_post(["if src_pos<src_len and src[src_pos]=='$param':", "INDENT", "src_pos+=1"],["DEDENT"]);
            }
            if($param=~/^([^*|?+()\[\]{}'"]+)$/){
                $param="r\"$param\\b\"";
            }
            my $t_name="re";
            if("re"=~/^(\S+)\s*=/){
                $t_name=$1;
            }
            if(!$imports{$t_name}){
                $imports{$t_name}=1;
                push @imports, "re";
            }
            my $re;
            if($param!~/^r['"]/){
                $param = "r\"$param\"";
            }
            if(!$re_cache{$param}){
                $re_index++;
                my $blk=MyDef::compileutil::get_named_block("regex_compile");
                push @$blk, "re$re_index = re.compile($param)\n";
                $re="re$re_index";
                $re_cache{$param}=$re;
            }
            else{
                $re=$re_cache{$param};
            }
            return single_block_pre_post(["# $param", "m = $re.match(src, src_pos)","if m:", "INDENT", "src_pos=m.end()"],["DEDENT"]);
            return 0;
        }
    }
    elsif($l=~/^NOOP POST_MAIN/){
        my $mainfunc = $MyDef::def->{codes}->{main};
        if($mainfunc){
            $mainfunc->{index}=-1;
        }
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
                    parse_function($name, $code);
                }
            }
        }
        MyDef::compileutil::set_output($old_out);
        return 0;
    }
    if($l=~/^(def|if|elif|else|while|for)\b(.*?):?\s*$/){
        $l="$1$2:";
    }
    elsif($l=~/^([\w\.]+):\s*(.*)$/){
        $l="$1($2)";
    }
    elsif($l=~/^(print)\s+(.*)$/){
        $l="$1($2)";
    }
    push @$out, $l;
    return 0;
}
sub dumpout {
    my ($f, $out, $pagetype)=@_;
    my $dump={out=>$out,f=>$f, module=>"output_python"};
    if(@imports){
        foreach my $t (@imports){
            push @$f, "import $t\n";
        }
        push @$f, "\n";
    }
    if(@globals){
        foreach my $t (@globals){
            push @$f, "$t\n";
        }
        push @$f, "\n";
    }
    unshift @$out, "DUMP_STUB regex_compile";
    if(@$fn_block){
        $dump->{fn_block}=$fn_block;
        unshift @$out, "INCLUDE_BLOCK fn_block";
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
