use strict;
package MyDef::output_www;
our $debug;
our $out;
our $mode;
our $page;
our $style;
our @style_key_list;
our $style_sheets;
our %php_globals;
our @php_globals;
our %js_globals;
our @js_globals;
our @mode_stack;
our $cur_mode="html";
our %plugin_statement;
our %plugin_condition;

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

use Term::ANSIColor qw(:constants);
sub get_interface {
    my $interface_type="general";
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout, $interface_type);
}
sub init_page {
    my ($t_page)=@_;
    $page=$t_page;
    MyDef::set_page_extension("html");
    my $init_mode="html";
    $style={};
    @style_key_list=();
    $style_sheets=[];
    if($page->{pageext} eq "js"){
        $init_mode="js";
    }
    %php_globals=();
    @php_globals=();
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
    if($mode eq $cur_mode or $mode eq "sub"){
        goto modeswitch_done;
    }
    if($cur_mode eq "PRINT"){
        $cur_mode=pop @mode_stack;
        if($mode eq $cur_mode){
            goto modeswitch_done;
        }
    }
    if($mode eq "PRINT"){
        push @mode_stack, $cur_mode;
        $cur_mode=$mode;
        goto modeswitch_done;
    }
    if($cur_mode eq "php"){
        if($out->[-1] eq "<?php\n"){
            pop @$out;
        }
        else{
            push @$out, "?>\n";
        }
        $cur_mode=pop @mode_stack;
        if($mode eq $cur_mode){
            goto modeswitch_done;
        }
    }
    if($mode eq "php"){
        push @$out, "<?php\n";
        push @mode_stack, $cur_mode;
        $cur_mode=$mode;
        goto modeswitch_done;
    }
    if($cur_mode eq "js"){
        push @$out, "<\/script>\n";
        $cur_mode=pop @mode_stack;
        if($mode eq $cur_mode){
            goto modeswitch_done;
        }
    }
    if($mode eq "js"){
        push @$out, "<script type=\"text/javascript\">\n";
        push @mode_stack, $cur_mode;
        $cur_mode=$mode;
        goto modeswitch_done;
    }
    modeswitch_done:
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
            print "eval error: [$@] package [", __PACKAGE__, "]\n";
        }
        return;
    }
    if($MyDef::compileutil::cur_mode eq "PRINT"){
        if($l=~/^(SUBBLOCK|SOURCE)/){
            push @$out, $l;
        }
        else{
            my $P="PRINT-".$mode_stack[-1];
            if($P eq "PRINT-html"){
                $l=~s/</&lt;/g;
                $l=~s/>/&gt;/g;
                push @$out, "$P $l";
            }
            else{
                push @$out, $l;
            }
        }
        return 0;
    }
    if($l=~/^CSS:\s*(.*)/){
        my $t=$1;
        if($t=~/(.*?)\s*\{(.*)\}/){
            if($style->{$1}){
                $style->{$1}.=";$2";
            }
            else{
                $style->{$1}=$2;
                push @style_key_list, $1;
            }
        }
        elsif($t=~/(\S*\.css)/){
            push @$style_sheets, $1;
        }
        return;
    }
    elsif($l=~/^\s*\$(title|charset)\s+(.*)/){
        $page->{$1}=$2;
        return;
    }
    elsif($l=~/^\s*PRINT\s+(.*)/){
        my $P="PRINT-$cur_mode";
        push @$out, "$P $1";
        return;
    }
    elsif($cur_mode eq "js" && $l=~/^(\S+)\s*=\s*"(.*\$\w+.*)"\s*$/){
        push @$out, "$1=". js_string($2);
        return;
    }
    elsif($l=~/^\s*\$(\w+)\((.*?)\)\s+(.*)$/){
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
        if($cur_mode eq "js"){
        }
        elsif($cur_mode eq "php"){
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
                my $P="PRINT-$cur_mode";
                if($func=~ /img|input/){
                    push @$out, "$P <$func$attr>";
                }
                elsif(defined $quick_content){
                    push @$out, "$P <$func$attr>$quick_content</$func>";
                }
                elsif($func eq "pre"){
                    my @pre=("$P <$func$attr>", "PUSHDENT");
                    my @post=("POPDENT", "$P </$func>");
                    return single_block_pre_post(\@pre, \@post);
                }
                else{
                    return single_block("$P <$func$attr>", "$P </$func>");
                }
                return 0;
            }
            if($func eq "script"){
                MyDef::compileutil::modepush("js");
                push @$out, "SOURCE_INDENT";
                push @$out, "BLOCK";
                push @$out, "SOURCE_DEDENT";
                push @$out, "PARSE:\$script_end";
                return "NEWBLOCK";
            }
            elsif($func eq "script_end"){
                MyDef::compileutil::modepop();
                return;
            }
            elsif($cur_mode eq "js"){
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
                elsif($func =~ /^(if|while|switch)$/){
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
            }
            elsif($cur_mode eq "php"){
                if($func =~/^if(\w*)/){
                    if($1){
                        $param=test_var($param, $1 eq 'z');
                    }
                    return single_block("if($param){", "}");
                }
                elsif($func =~ /^(el|els|else)if(\w*)$/){
                    if($1){
                        $param=test_var($param, $1 eq 'z');
                    }
                    return single_block("elseif($param){", "}");
                }
                elsif($func eq "else"){
                    return single_block("else{", "}");
                }
                elsif($func eq "for"){
                    if($param=~/(.*);(.*);(.*)/){
                        single_block("for($param){", "}");
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
                            $step= "+=$step";
                        }
                        if(!$var){
                            $var="\$i";
                        }
                        elsif($var=~/^(\w+)/){
                            $var='$'.$var;
                        }
                        $param="$var=$i0; $var $i1; $var$step";
                        single_block("for($param){", "}");
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
                    return 0;
                }
            }
            elsif($cur_mode eq "html"){
                if($func eq "include"){
                    if(open my $in, $param){
                        my $omit=0;
                        while(<$in>){
                            if(/<!-- start omit -->/){
                                $omit=1;
                            }
                            elsif($omit){
                                if(/<!-- end omit -->/){
                                    $omit=0;
                                }
                                next;
                            }
                            elsif(/(.*)<call>(\w+)<\/call>(.*)/){
                                my ($a, $b, $c)=($1, $2, $3);
                                push @$out, $a;
                                print "    call $b\n";
                                MyDef::compileutil::call_sub($b);
                                push @$out, $c;
                            }
                            elsif(/^\s*<\/HEAD>/i){
                                push @$out, "DUMP_STUB meta";
                                push @$out, $_;
                            }
                            else{
                                push @$out, $_;
                            }
                        }
                        close $in;
                    }
                    else{
                        warn " Can't open [$param]\n";
                    }
                }
            }
        }
    }
    if($cur_mode eq "php"){
        if($l!~/[\{\};]\s*$/){
            $l.=";";
        }
    }
    elsif($cur_mode eq "js"){
        if($l!~/[:\(\{\};,]\s*$/){
            $l.=';';
        }
    }
    elsif($cur_mode eq "html"){
    }
    push @$out, $l;
}
sub dumpout {
    my ($f, $out, $pagetype)=@_;
    my $dump={out=>$out,f=>$f, module=>"output_www"};
    $dump->{custom}=\&custom_dump;
    if($MyDef::page->{type} eq "css"){
        foreach my $k (@style_key_list){
            my %attr;
            my @attr;
            my @tlist=split /;/, $style->{$k};
            foreach my $t (@tlist){
                if($t=~/([^ :]+):\s*(.*)/){
                    if(!defined $attr{$1}){
                        push @attr, $1;
                    }
                    $attr{$1}=$2;
                }
            }
            @tlist=();
            foreach my $a (@attr){
                push @tlist, "$a: $attr{$a}";
                if($a=~/(transition|user-select)/){
                    foreach my $prefix (("moz", "webkit", "ms", "o")){
                        push @tlist, "-$prefix-$a: $attr{$a}";
                    }
                }
                if($attr{$a}=~/^\s*(linear-gradient)/){
                    foreach my $prefix (("moz", "webkit", "ms", "o")){
                        push @tlist, "$a: -$prefix-$attr{$a}";
                    }
                }
            }
            push @$out, "$k {". join('; ', @tlist)."}\n";
        }
    }
    else{
        my $metablock=MyDef::compileutil::get_named_block("meta");
        my $charset=$page->{charset};
        if(!$charset){
            $charset="utf-8";
        }
        my $title=$page->{title};
        if(!$title){
            $title=$page->{pagename};
        }
        push @$metablock, "<meta charset=\"$charset\">";
        push @$metablock, "<title>$title</title>\n";
        my %sheet_hash;
        foreach my $s (@$style_sheets){
            if(!$sheet_hash{$s}){
                $sheet_hash{$s}=1;
                push @$metablock, "<link rel=\"stylesheet\" type=\"text/css\" href=\"$s\" />\n";
            }
        }
        if(@style_key_list){
            push @$metablock, "<style>\n";
            foreach my $k (@style_key_list){
                my %attr;
                my @attr;
                my @tlist=split /;/, $style->{$k};
                foreach my $t (@tlist){
                    if($t=~/([^ :]+):\s*(.*)/){
                        if(!defined $attr{$1}){
                            push @attr, $1;
                        }
                        $attr{$1}=$2;
                    }
                }
                @tlist=();
                foreach my $a (@attr){
                    push @tlist, "$a: $attr{$a}";
                    if($a=~/(transition|user-select)/){
                        foreach my $prefix (("moz", "webkit", "ms", "o")){
                            push @tlist, "-$prefix-$a: $attr{$a}";
                        }
                    }
                    if($attr{$a}=~/^\s*(linear-gradient)/){
                        foreach my $prefix (("moz", "webkit", "ms", "o")){
                            push @tlist, "$a: -$prefix-$attr{$a}";
                        }
                    }
                }
                push @$metablock, "    $k {". join('; ', @tlist)."}\n";
            }
            push @$metablock, "</style>\n";
        }
    }
    if(@php_globals){
        push @$f, "<?php\n";
        foreach my $v (@php_globals){
            push @$f, "$v;\n";
        }
        push @$f, "?>\n";
    }
    my $block=MyDef::compileutil::get_named_block("js_init");
    foreach my $v (@js_globals){
        push @$block, "var $v;\n";
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
sub custom_dump {
    my ($f, $rl)=@_;
    if($$rl=~/\\span_(\w+)\{([^}]*)\}/){
        my $t="<span class=\"$1\">$2</span>";
        $$rl=$`.$t.$';
    }
    if($$rl=~/PRINT-(\w+) (.*)/){
        my $mode=$1;
        my $t=$2;
        if($mode eq "php"){
            $$rl=echo_php($t);
        }
        elsif($mode eq "js"){
            $$rl="PRINT $t";
        }
        else{
            if($t!~/</){
                if($t=~/".*?"/){
                    my @plist=split /(".*?")/, $t;
                    my @tlist;
                    foreach my $p (@plist){
                        if($p=~/^".*?"$/){
                            push @tlist, "<span class=\"mydef-quote\">$p</span>";
                        }
                        else{
                            push @tlist, $p;
                        }
                    }
                    $t=join('', @tlist);
                }
                if($t=~/\$\(.*?\)/){
                    my @plist=split /(\$\(.*?\))/, $t;
                    my @tlist;
                    foreach my $p (@plist){
                        if($p=~/^\$\(.*?\)$/){
                            push @tlist, "<span class=\"mydef-macro\">$p</span>";
                        }
                        else{
                            push @tlist, $p;
                        }
                    }
                    $t=join('', @tlist);
                }
            }
            if($t=~/^(\s*)((#|&#35;).*)/){
                $t="$1<span class=\"mydef-comment\">$2</span>";
            }
            elsif($t=~/(.*)(\s(#|&#35;)\s.*)/){
                $t="$1<span class=\"mydef-comment\">$2</span>";
            }
            elsif($t=~/^(\s*)(page|\w+code)(:.?\s*)(\w+)(.*)/){
                $t="$1<span class=\"mydef-label\">$2</span>$3<span class=\"mydef-label\">$4</span>$5";
            }
            elsif($t=~/^(\s*)(\$call|\$map|\&call)\s*(\S+)(.*)/){
                $t="$1<span class=\"mydef-keyword\">$2</span> <strong>$3</strong>$4";
            }
            elsif($t=~/^(\s*)(CSS|include):\s*(.*)/){
                $t="$1<span class=\"mydef-preproc\">$2</span>: <span class=\"mydef-preproc\">$3</span>";
            }
            elsif($t=~/^(\s*)\$(if|while|switch|for|elif|elsif|else|function)\b(.*)/){
                $t="$1<span class=\"mydef-keyword\">\$$2</span>$3";
            }
            $$rl="PRINT $t";
        }
    }
    return 0;
}
sub echo_php {
    my ($t, $ln)=@_;
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
    my ($param, $z)=@_;
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
sub js_string {
    my ($t)=@_;
    my @parts=split /(\$\w+)/, $t;
    if($parts[0]=~/^$/){
        shift @parts;
    }
    for(my $i=0; $i <@parts; $i++){
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
sub sql_value {
    my ($varname, $colname)=@_;
    my $type=MyDef::compileutil::get_def("$varname"."_type");
    if(!$type){
        $type=getfieldtype($colname);
    }
    if($type =~/^(int|uint|boolean)$/){
        push @$out, "if(is_numeric(\$$varname)){";
        push @$out, "    \$t_$varname=\$$varname;";
        push @$out, "}else{";
        push @$out, "    \$t_$varname=\"NULL\";";
        push @$out, "}";
        return "\$t_$varname";
    }
    elsif($type eq 'date'){
        push @$out, "if(\$$varname){";
        push @$out, "    \$t_$varname=\"'\".\$$varname.\"'\";";
        push @$out, "}else{";
        push @$out, "    \$t_$varname=\"NULL\";";
        push @$out, "}";
        return "\$t_$varname";
    }
    elsif($type eq 'now'){
        return "NOW()";
    }
    elsif($type eq 'today' or $type eq 'curdate'){
        return "CURDATE()";
    }
    else{
        my $null=MyDef::compileutil::get_def("$varname"."_null");
        if($null){
            push @$out, "if(\$$varname){";
            push @$out, "    \$t_$varname=\"'\".addslashes(\$$varname).\"'\";";
            push @$out, "}";
            push @$out, "else{";
            push @$out, "    \$t_$varname='NULL';";
            push @$out, "}";
            return "\$t_$varname";
        }
        else{
            push @$out, "\$t_$varname=addslashes(\$$varname);";
            return "'\$t_$varname'";
        }
    }
}
sub getfieldtype {
    my ($colname)=@_;
    my $type;
    if($colname=~/_id$/){
        $type="uint";
    }
    elsif($colname=~/_date$/ or $colname=~/^date_/){
        $type="date";
    }
    elsif($colname eq "time_inserted" or $colname eq "time_in" or $colname eq "time_out"){
        $type="now";
    }
    elsif($colname eq "date_inserted"){
        $type="today";
    }
    elsif($colname=~/_flag$/ or $colname=~/^flag_/){
        $type="boolean";
    }
    elsif($colname=~/_quantity$/){
        $type="int";
    }
    elsif($colname=~/^number_/){
        $type="int";
    }
    elsif($colname eq "password"){
        $type="password";
    }
    elsif($colname =~/phone/){
        $type="phone";
    }
    elsif($colname eq 'city'){
        $type='city';
    }
    elsif($colname eq 'state'){
        $type='state';
    }
    elsif($colname =~ /zip(code)?/){
        $type='zip';
    }
    elsif($colname =~ /email/){
        $type='email';
    }
    elsif($colname =~ /city_state_zip/){
        $type='city_state_zip';
    }
    return $type;
}
1;
