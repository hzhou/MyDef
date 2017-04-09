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
our $time_start = time();

sub bases {
    my ($n, @bases) = @_;
    my @t;
    foreach my $b (@bases){
        push @t, $n % $b;
        $n = int($n/$b);
        if($n<=0){
            last;
        }
    }
    if($n>0){
        push @t, $n;
    }
    return @t;
}

sub get_time {
    my $t = time()-$time_start;
    my @t;
    push @t, $t % 60;
    $t = int($t/60);
    push @t, $t % 60;
    $t = int($t/60);
    push @t, $t % 60;
    $t = int($t/60);
    if($t>0){
        push @t, $t % 24;
        $t = int($t/24);
        return sprintf("%d day %02d:%02d:%02d", $t[3], $t[2], $t[1], $t[0]);
    }
    else{
        return sprintf("%02d:%02d:%02d", $t[2], $t[1], $t[0]);
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
    if($MyDef::compileutil::cur_mode eq "PRINT"){
        push @$out, $l;
        return 0;
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
                push @$out, "console.log($param);";
                return 0;
            }
        }
    }
    if($l!~/[:\(\{\};,]\s*$/){
        $l.=';';
    }
    push @$out, $l;
}
sub dumpout {
    my ($f, $out, $pagetype)=@_;
    my $dump={out=>$out,f=>$f, module=>"output_js"};
    my $block=MyDef::compileutil::get_named_block("js_init");
    foreach my $v (@js_globals){
        push @$block, "var $v;\n";
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
sub js_string {
    my ($t)=@_;
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
1;
