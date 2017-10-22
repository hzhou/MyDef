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
our @future;
our %future;
our $re_index=0;
our %re_cache;
our $fn_block=[];
our %stub;

sub add_import {
    my ($t) = @_;
    if(!$imports{$t}){
        $imports{$t}=1;
        push @imports, $t;
    }
}

sub future_import {
    my ($t) = @_;
    if(!$future{$t}){
        $future{$t}=1;
        push @future, $t;
    }
}

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

sub fmt_string {
    my ($str, $add_newline) = @_;
    if(!$str){
        if($add_newline){
            return (0, '"\n"');
        }
        else{
            return (0, '""');
        }
    }
    $str=~s/\s*$//;
    my @pre_list;
    if($str=~/^\s*\"(.*)\"\s*,\s*(.*)$/){
        $str=$1;
        @pre_list=MyDef::utils::proper_split($2);
    }
    elsif($str=~/^\s*\"(.*)\"\s*$/){
        $str=$1;
    }
    if($add_newline and $str=~/(.*)-$/){
        $add_newline=0;
        $str=$1;
    }
    my %colors=(red=>31,green=>32,yellow=>33,blue=>34,magenta=>35,cyan=>36);
    my @fmt_list;
    my @arg_list;
    my $missing = 0;
    my @group;
    my $flag_hyphen=0;
    while(1){
        if($str=~/\G$/sgc){
            last;
        }
        elsif($str=~/\G%/sgc){
            if($str=~/\G%/sgc){
                push @fmt_list, '%%';
            }
            elsif($str=~/\G[-+ #]*[0-9]*(\.\d+)?[sbcdoxXneEfFgGn]/sgc){
                if(!@pre_list){
                    $missing++;
                }
                push @arg_list, shift @pre_list;
                push @fmt_list, "%$&";
            }
            else{
                push @fmt_list, '%%';
            }
        }
        elsif($str=~/\G\$/sgc){
            if($str=~/\G(red|green|yellow|blue|magenta|cyan)/sgc){
                push @fmt_list, "\\x1b[$colors{$1}m";
                if($str=~/\G\{/sgc){
                    push @group, $1;
                }
            }
            elsif($str=~/\Greset/sgc){
                push @fmt_list, "\\x1b[0m";
            }
            elsif($str=~/\Gclear/sgc){
                push @fmt_list, "\\x1b[H\\x1b[J";
            }
            elsif($str=~/\G(\w+)/sgc){
                my $v=$1;
                if($str=~/\G(\[.*?\])/sgc){
                    $v.=$1;
                }
                elsif($str=~/\G(\{.*?\})/sgc){
                    $v.=$1;
                    $v=check_expression($v);
                }
                push @fmt_list, "%s";
                push @arg_list, $v;
                if($str=~/\G-/sgc){
                }
            }
            elsif($str=~/\G\{(.*?)\}/sgc){
                push @arg_list, $1;
                push @fmt_list, get_var_fmt($1, 1);
            }
            else{
                push @fmt_list, '$';
            }
        }
        elsif($str=~/\G\\\$/sgc){
            push @fmt_list, '$';
        }
        elsif($str=~/\G\}/sgc){
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
        elsif($str=~/\G[^%\$\}]+/sgc){
            push @fmt_list, $&;
        }
        else{
            die "parse_loop: nothing matches! [$str]\n";
        }
    }
    if(@pre_list){
        my $s = join(', ', @pre_list);
        my $curfile=MyDef::compileutil::curfile_curline();
        print "[$curfile]\x1b[33m Extra fmt arg list: $s\n\x1b[0m";
    }
    elsif($missing>0){
        my $curfile=MyDef::compileutil::curfile_curline();
        print "[$curfile]\x1b[33m Missing $missing fmt arguments\n\x1b[0m";
    }
    if($add_newline){
        my $tail=$fmt_list[-1];
        if($tail=~/(.*)-$/){
            $fmt_list[-1]=$1;
        }
        elsif($tail!~/\\n$/){
            push @fmt_list, "\\n";
        }
    }
    if(!@arg_list){
        return (0, '"'.join('',@fmt_list).'"');
    }
    else{
        my $vcnt=@arg_list;
        my $f = join('', @fmt_list);
        my $a = join(', ', @arg_list);
        return ($vcnt, "\"$f\" % ($a)");
    }
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
    @future=();
    %future=();
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
        elsif($func eq "import"){
            add_import($param);
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
        elsif($func=~/^(for)$/){
            if($param =~/^(\w+)=(.*)/){
                my ($v, $t) =($1, $2);
                if($t=~/^0:([^:]+)$/){
                    $t=$1;
                }
                else{
                    $t=~s/:/,/g;
                }
                push @$out, "for $v in range($t):";
            }
            else{
                push @$out, "$func $param:";
            }
            return 0;
        }
        elsif($func=~/^def$/){
            if($param=~/^\w+$/){
                $param.="()";
            }
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
            if(!$param){
                push @$out, "print('')";
            }
            else{
                future_import("print_function");
                my ($n, $fmt)=fmt_string($param, 1);
                my $add_newline = 1;
                if($fmt=~/^"(.*)\\n"(.*)/){
                    $fmt = "\"$1\"$2";
                }
                else{
                    $add_newline = 0;
                }
                my $print_to = MyDef::compileutil::get_macro_word("print_to", 1);
                if($print_to){
                    if($add_newline){
                        push @$out, "print($fmt, file=$print_to)";
                    }
                    else{
                        push @$out, "print($fmt, end='', file=$print_to)";
                    }
                }
                else{
                    if($add_newline){
                        push @$out, "print($fmt)";
                    }
                    else{
                        push @$out, "print($fmt, end='')";
                    }
                }
            }
            return 0;
        }
        elsif($func eq "if_match"){
            my $n=0;
            if(length($param)==1 and $param!~/\w/){
                return single_block_pre_post(["if src_pos<src_len and src[src_pos]=='$param':", "INDENT", "src_pos+=1"],["DEDENT"]);
            }
            if($param=~/^([^*|?+()\[\]{}'"]+)$/){
                $param="r\"$param\\b\"";
            }
            add_import("re");
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
    elsif($l=~/^DUMP_STUB\s+(\w+)/){
        $stub{$1}++;
    }
    push @$out, $l;
    return 0;
}
sub dumpout {
    my ($f, $out)=@_;
    my $dump={out=>$out,f=>$f};
    if(@future){
        push $f, "from __future__ import ".join(', ', @future)."\n";
        push @$f, "\n";
    }
    if(@imports){
        foreach my $t (@imports){
            if($t=~/(.*)\s+(from\s+\w+)$/){
                push @$f, "$2 import $1\n";
            }
            else{
                push @$f, "import $t\n";
            }
        }
        push @$f, "\n";
    }
    if(@globals){
        foreach my $t (@globals){
            push @$f, "$t\n";
        }
        push @$f, "\n";
    }
    if(!$stub{"regex_compile"}){
        unshift @$out, "DUMP_STUB regex_compile";
    }
    if(@$fn_block){
        $dump->{fn_block}=$fn_block;
        unshift @$out, "INCLUDE_BLOCK fn_block";
    }
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
