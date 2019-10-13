use strict;
package MyDef::output_php;
our $debug=0;
our $out;
our $mode;
our $page;
our %php_globals;
our @php_globals;
our %plugin_statement;
our %plugin_condition;

sub php_print {
    my ($s) = @_;
    $s=~s/"/\\"/g;
    return "echo \"$s\";";
}

sub echo_php {
    my ($t, $ln) = @_;
    $t=~s/\\/\\\\/g;
    $t=~s/"/\\"/g;
    if($ln){
        return "echo \"$t\\n\";";
    }
    else{
        return "echo \"$t\";";
    }
}

sub test_var {
    my ($param, $z) = @_;
    if($param=~/(\$\w+)\[(^[\]]*)\]/){
        if(!$z){
            return "array_key_exists($2, $1) and $param";
        }
        else{
            return "!(array_key_exists($2, $1) and $param)";
        }
    }
    else{
        if($z){
            return "empty($param)";
        }
        else{
            return "!empty($param)";
        }
    }
}

sub parse_tag_attributes {
    my ($tt_list) = @_;
    my $func=shift @$tt_list;
    my $attr="";
    my $quick_content;
    foreach my $tt (@$tt_list){
        if($tt eq "/"){
            $quick_content="";
        }
        elsif($tt=~/^#(\S+)$/){
            $attr.=" id=\"$1\"";
        }
        elsif($tt=~/^(\S+?)[:=]"(.*)"/){
            $attr.=" $1=\"$2\"";
        }
        elsif($tt=~/^(\S+?)[:=](.*)/){
            $attr.=" $1=\"$2\"";
        }
        elsif($tt=~/^"(.*)"/){
            $quick_content=$1;
        }
        else{
            $attr.=" class=\"$tt\"";
        }
    }
    if($func eq "input"){
        if($attr !~ /type=/){
            $attr.=" type=\"text\"";
        }
        if($quick_content){
            $attr.=" placeholder=\"$quick_content\"";
        }
    }
    elsif($func eq "form"){
        if($attr !~ /action=/){
            $attr.=" action=\"<?=\$_SERVER['PHP_SELF'] ?>\"";
        }
        if($attr !~ /method=/){
            $attr.=" method=\"POST\"";
        }
    }
    return ($func, $attr, $quick_content);
}

sub get_interface {
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout);
}
sub init_page {
    my ($t_page)=@_;
    $page=$t_page;
    MyDef::set_page_extension("php");
    my $init_mode="sub";
    %php_globals=();
    @php_globals=();
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
    elsif($l=~/^CSS:\s*(.*)/){
        return MyDef::output_www::parse_css($1);
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
            if($func =~ /^(tag|div|span|ol|ul|li|table|tr|td|th|h[1-5]|p|pre|html|head|body|form|label|fieldset|button|input|textarea|select|option|img|a|center|b|style)$/){
                my @tt_list=split /,\s*/, $param;
                if($func ne "tag"){
                    unshift @tt_list, $func;
                }
                my ($func, $attr, $quick_content)= parse_tag_attributes(\@tt_list);
                if($func=~ /img|input/){
                    push @$out, php_print("<$func$attr />");
                }
                elsif(defined $quick_content){
                    push @$out, php_print("<$func$attr>$quick_content</$func>");
                }
                elsif($func eq "pre"){
                    my @src;
                    push @src, php_print("<$func$attr>");
                    push @src, "PUSHDENT";
                    push @src, "BLOCK";
                    push @src, "POPDENT";
                    push @src, php_print("</$func>");
                    MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                    return "NEWBLOCK-pre";
                }
                else{
                    my @src;
                    push @src, php_print("<$func$attr>");
                    push @src, "INDENT";
                    push @src, "BLOCK";
                    push @src, "DEDENT";
                    push @src, php_print("</$func>");
                    MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                    return "NEWBLOCK-tag";
                }
                return 0;
            }
            if($func =~/^echo/){
                push @$out, php_print($param);
                return;
            }
            elsif($func =~/^if(\w*)/){
                if($1 and $param!~/^!/){
                    $param=test_var($param, $1 eq 'z');
                }
                return single_block("if($param){", "}");
            }
            elsif($func =~ /^(el|els|else)if(\w*)$/){
                if($2 and $param!~/^!/){
                    $param=test_var($param, $2 eq 'z');
                }
                return single_block("elseif($param){", "}");
            }
            elsif($func eq "else"){
                return single_block("else{", "}");
            }
            elsif($func eq "for"){
                if($param=~/(.*);(.*);(.*)/){
                    my @src;
                    push @src, "for($param){";
                    push @src, "INDENT";
                    push @src, "BLOCK";
                    push @src, "DEDENT";
                    push @src, "}";
                    MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                    return "NEWBLOCK-for";
                }
                else{
                    my $var;
                    if($param=~/^(\S+)\s*=\s*(.*)/){
                        $var=$1;
                        $param=$2;
                    }
                    my @tlist=split /:/, $param;
                    my ($i0, $i1, $step);
                    if(@tlist==1){
                        $i0="0";
                        $i1="<$param";
                        $step="1";
                    }
                    elsif(@tlist==2){
                        if($tlist[1] eq "0"){
                            $i0="$tlist[0]-1";
                            $i1=">=$tlist[1]";
                            $step="-1";
                        }
                        elsif($tlist[1]=~/^[-0-9]+$/ && $tlist[0]=~/^[-0-9]+$/ && $tlist[0]>$tlist[1]){
                            $i0=$tlist[0];
                            $i1=">=$tlist[1]";
                            $step="-1";
                        }
                        else{
                            $i0=$tlist[0];
                            $i1="<$tlist[1]";
                            $step="1";
                        }
                    }
                    elsif(@tlist==3){
                        $i0=$tlist[0];
                        $step=$tlist[2];
                        if($step=~/^-/){
                            $i1=">=$tlist[1]";
                        }
                        else{
                            $i1="<$tlist[1]";
                        }
                    }
                    if($step eq "1"){
                        $step="++";
                    }
                    elsif($step eq "-1"){
                        $step="--";
                    }
                    else{
                        $step="+=$step";
                    }
                    my $my="";
                    if(!$var){
                        $var="\$i";
                    }
                    elsif($var=~/^(\w+)/){
                        $var='$'.$var;
                    }
                    $param="$my$var=$i0; $var$i1; $var$step";
                    my @src;
                    push @src, "for($param){";
                    push @src, "INDENT";
                    push @src, "BLOCK";
                    push @src, "DEDENT";
                    push @src, "}";
                    MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                    return "NEWBLOCK-for";
                }
            }
            elsif($func eq "foreach" or $func eq "for" or $func eq "while"){
                return single_block("$func ($param){", "}");
            }
            elsif($func eq "function"){
                return single_block("function $param {", "}");
            }
            elsif($func eq "global"){
                $param=~s/\s*;\s*$//;
                my @tlist=MyDef::utils::proper_split($param);
                foreach my $v (@tlist){
                    if(!$php_globals{$v}){
                        $php_globals{$v}=1;
                        push @php_globals, $v;
                    }
                    $v=~s/=.*//;
                    push @$out, "global $v;";
                }
                return;
            }
            elsif($func eq "print"){
                my $str=$param;
                if($str=~/^\s*\"(.*)\"\s*$/){
                    $str=$1;
                }
                push @$out, php_print($str);
                return;
            }
        }
    }
    elsif($l=~/^CALLBACK\s+(\w+)\s*(.*)/){
        my ($func, $param)=($1, $2);
        my $codelist=$MyDef::compileutil::named_blocks{"last_grab"};
        return;
    }
    if($l!~/[\{\};]\s*$/){
        $l.=";";
    }
    push @$out, $l;
}
sub dumpout {
    my ($f, $out)=@_;
    my $dump={out=>$out,f=>$f};
    if(@php_globals){
        foreach my $v (@php_globals){
            push @$f, "$v;\n";
        }
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
