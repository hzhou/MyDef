use strict;
package MyDef::output_js;
our $debug=0;
our $out;
our $mode;
our $page;
our %js_globals;
our @js_globals;
our %plugin_statement;
our %plugin_condition;

sub dump_js_globals {
    my $block=MyDef::compileutil::get_named_block("js_init");
    foreach my $v (@js_globals){
        push @$block, "var $v;\n";
    }
}

sub js_string {
    my ($t) = @_;
    my @parts=split /(\$\w+)/, $t;
    if($parts[0]=~/^$/){
        shift @parts;
    }
    for(my $i=0; $i<@parts; $i++){
        if($parts[$i]=~/^\$(\w+)/){
            $parts[$i]=$1;
            while($parts[$i+1]=~/^(\[.*?\])/){
                $parts[$i].=$1;
                $parts[$i+1]=$';
            }
        }
        else{
            $parts[$i]= "\"$parts[$i]\"";
        }
    }
    return join(' + ', @parts);
}

sub find_var {
    my ($v) = @_;
    return {direct=>"\"+$v+\""};
}

sub get_var_fmt {
    my ($v, $warn) = @_;
    return '%s';
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
            elsif($str=~/\G[-+ #]*[0-9]*(\.\d+)?[s]/sgc){
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
                my $var=find_var($v);
                if($var->{direct}){
                    push @fmt_list, $var->{direct};
                }
                elsif($var->{strlen}){
                    push @fmt_list, "%.*s";
                    push @arg_list, $var->{strlen};
                    push @arg_list, $v;
                }
                else{
                    push @fmt_list, get_var_fmt($v, 1);
                    push @arg_list, $v;
                }
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
        return ($vcnt, "\"$f\", $a");
    }
}

sub get_interface {
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout);
}
sub init_page {
    my ($t_page)=@_;
    $page=$t_page;
    MyDef::set_page_extension("js");
    my $init_mode="sub";
    %js_globals=();
    @js_globals=();
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
    if($l=~/^DUMP_STUB\s/){
        push @$out, $l;
    }
    elsif($l=~/^(\S+)\s*=\s*"(.*\$\w+.*)"\s*$/){
        push @$out, "$1=". js_string($2);
        return;
    }
    elsif($l=~/^\s*\$(\w+)\((.*?)\)\s+(.*?)\s*$/){
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
    }
    elsif($l=~/^\s*\$(\w+)\s*(.*)$/){
        my ($func, $param)=($1, $2);
        if($param !~ /^=/){
            if($plugin_statement{$func}){
                my $codename=$plugin_statement{$func};
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
            my $param1="";
            my $param2=$param;
            if($func eq "global"){
                $param=~s/\s*;\s*$//;
                my @tlist=MyDef::utils::proper_split($param);
                foreach my $v (@tlist){
                    if(!$js_globals{$v}){
                        $js_globals{$v}=1;
                        push @js_globals, $v;
                    }
                }
                return;
            }
            elsif($func =~ /^(function)$/){
                return single_block("$1 $param\{", "}");
            }
            elsif($func =~ /^(if|while|switch|with)$/){
                return single_block("$1($param){", "}");
            }
            elsif($func =~ /^(el|els|else)if$/){
                return single_block("else if($param){", "}");
            }
            elsif($func eq "else"){
                return single_block("else{", "}");
            }
            elsif($func eq "for" or $func eq "foreach"){
                if($param=~/(\w+)=(.*?):(.*?)(:.*)?$/){
                    my ($var, $i0, $i1, $step)=($1, $2, $3, $4);
                    my $stepclause;
                    if($step){
                        my $t=substr($step, 1);
                        if($t eq "-1"){
                            $stepclause="var $var=$i0;$var>$i1;$var--";
                        }
                        elsif($t=~/^-/){
                            $stepclause="var $var=$i0;$var>$i1;$var=$var$t";
                        }
                        else{
                            $stepclause="var $var=$i0;$var<$i1;$var+=$t";
                        }
                    }
                    else{
                        if($i1 eq "0"){
                            $stepclause="var $var=$i0-1;$var>=0;$var--";
                        }
                        elsif($i1=~/^-?\d+/ and $i0=~/^-?\d+/ and $i1<$i0){
                            $stepclause="var $var=$i0;$var>$i1;$var--";
                        }
                        else{
                            $stepclause="var $var=$i0;$var<$i1;$var++";
                        }
                    }
                    return single_block("for($stepclause){", "}");
                }
                elsif($param=~/^(\S+)$/){
                    MyDef::compileutil::set_current_macro("item", "$1\[i]");
                    return single_block("for(i=0;i<$1.length;i++){", "}");
                }
                else{
                    return single_block("$func($param){", "}");
                }
            }
            elsif($func eq "print"){
                $param=~s/^\s+//;
                my ($n, $fmt)=fmt_string($param, 0);
                my $print_to = MyDef::compileutil::get_macro_word("print_to", 1);
                if(!$print_to){
                    push @$out, "console.log($fmt)";
                }
                else{
                    push @$out, "console.$print_to($fmt)";
                }
                return;
            }
            elsif($func eq "dump"){
                push @$out, "console.log($param)";
                return;
            }
        }
    }
    if($l!~/[:\(\{\};,]\s*$/){
        $l.=';';
    }
    push @$out, $l;
}
sub dumpout {
    my ($f, $out)=@_;
    my $dump={out=>$out,f=>$f};
    dump_js_globals();
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
