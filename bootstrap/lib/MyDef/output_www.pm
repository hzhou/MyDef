use strict;
package MyDef::output_www;
our $style;
our @style_key_list;
our @mode_stack;
our $cur_mode="html";
our %plugin_statement;
our %plugin_condition;
use MyDef::dumpout;
use MyDef::utils;
our $debug;
our $mode;
our $page;
our $out;
use MyDef::compileutil;
use Term::ANSIColor qw(:constants);
my $php;
my $style_sheets;
our @js_globals;
our %js_globals;
sub get_interface {
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout);
}
sub init_page {
    ($page)=@_;
    my $ext="html";
    if($MyDef::var->{filetype}){
        $ext=$MyDef::var->{filetype};
    }
    if($page->{type}){
        $ext=$page->{type};
    }
    $php={};
    $style_sheets=[];
    $style={};
    @style_key_list=();
    $page->{pageext}=$ext;
    my $init_mode=$page->{init_mode};
    return ($ext, $init_mode);
}
sub set_output {
    $out = shift;
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
        push @$out, "?>\n";
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
    if($l=~/^\s*CSS: (.*)\s*\{(.*)\}/){
        if($style->{$1}){
            $style->{$1}.=";$2";
        }
        else{
            $style->{$1}=$2;
            push @style_key_list, $1;
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
        if($plugin_statement{$func}){
            my $codename=$plugin_statement{$func};
            my $t=MyDef::compileutil::eval_sub($codename);
            eval $t;
            if($@){
                print "plugin - $func\n";
                print "[$t]\n";
                print "eval error: [$@]\n";
            }
            return;
        }
    }
    elsif($l=~/^\s*\$(\w+)\s*(.*)$/){
        my ($func, $param)=($1, $2);
        if($param !~ /^=/){
            if($func =~ /^(tag|div|span|ol|ul|li|table|tr|td|th|h[1-5]|p|pre|html|head|body|form|label|fieldset|button|input|textarea|select|option|img|a|center|b|style)$/){
                my @tt_list=split /,\s*/, $param;
                my $is_empty_tag=0;
                if($func eq "tag" and @tt_list){
                    $func=shift @tt_list;
                }
                my $t="";
                my $quick_content;
                foreach my $tt (@tt_list){
                    if($tt eq "/"){
                        $is_empty_tag=1;
                    }
                    elsif($tt=~/^#(\S+)$/){
                        $t.=" id=\"$1\"";
                    }
                    elsif($tt=~/^(\S+?)[:=]"(.*)"/){
                        $t.=" $1=\"$2\"";
                    }
                    elsif($tt=~/^(\S+?)[:=](.*)/){
                        $t.=" $1=\"$2\"";
                    }
                    elsif($tt=~/^"(.*)"/){
                        $quick_content=$1;
                    }
                    else{
                        $t.=" class=\"$tt\"";
                    }
                }
                if($func eq "input"){
                    if($t !~ /type=/){
                        $t.=" type=\"text\"";
                    }
                    if($quick_content){
                        $t.=" placeholder=\"$quick_content\"";
                    }
                }
                elsif($func eq "form"){
                    if($t !~ /action=/){
                        $t.=" action=\"<?=\$PHP_SELF ?>\"";
                    }
                    if($t !~ /method=/){
                        $t.=" method=\"POST\"";
                    }
                }
                my $P="PRINT-$cur_mode";
                if($func=~ /img|input/){
                    push @$out, "$P <$func$t>";
                }
                elsif($is_empty_tag or defined $quick_content){
                    push @$out, "$P <$func$t>$quick_content</$func>";
                }
                elsif($func eq "pre"){
                    my @pre=("$P <$func$t>", "PUSHDENT");
                    my @post=("POPDENT", "$P </$func>");
                    return single_block_pre_post(\@pre, \@post);
                }
                else{
                    return single_block("$P <$func$t>", "$P </$func>");
                }
                return 0;
            }
            if($func eq "script"){
                MyDef::compileutil::modepush("js");
                push @$out, "SOURCE_INDENT";
                push @$out, "BLOCK";
                push @$out, "SOURCE_DEDENT";
                return "NEWBLOCK-\$script_end";
            }
            elsif($func eq "script_end"){
                MyDef::compileutil::modepop();
                return;
            }
            elsif($cur_mode eq "js"){
                my $param1="";
                my $param2=$param;
                if($func eq "global"){
                    my @tlist=split /,\s+/, $param;
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
                    return single_block("else if($param){", "}")
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
                        return single_block("for($stepclause){", "}")
                    }
                    else{
                        return single_block("$func($param){", "}");
                    }
                }
            }
            elsif($cur_mode eq "php"){
                if($func eq "if"){
                    return single_block("if($param){", "}")
                }
                elsif($func eq "ifz"){
                    if($param=~/(\$\w+)\[(^[\]]*)\]/){
                        return single_block("if(!(array_key_exists($2, $1) and $param)){", "}")
                    }
                    else{
                        return single_block("if(empty($param)){", "}")
                    }
                }
                elsif($func eq "ifnz"){
                    if($param=~/(\$\w+)\[(^[\]]*)\]/){
                        return single_block("if((array_key_exists($2, $1) and $param)){", "}")
                    }
                    else{
                        return single_block("if(!empty($param)){", "}")
                    }
                }
                elsif($func =~ /^(el|els|else)if$/){
                    if($cur_mode eq 'html' or $cur_mode eq 'js'){
                        return single_block("else if($param){", "}")
                    }
                    else{
                        return single_block("elseif($param){", "}")
                    }
                }
                elsif($func eq "else"){
                    return single_block("else{", "}");
                }
                elsif($func eq "foreach" or $func eq "for" or $func eq "while"){
                    return single_block("$func ($param){", "}");
                }
                elsif($func eq "function"){
                    return single_block("function $param {", "}");
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
            if($plugin_statement{$func}){
                my $codename=$plugin_statement{$func};
                my $t=MyDef::compileutil::eval_sub($codename);
                eval $t;
                if($@){
                    print "plugin - $func\n";
                    print "[$t]\n";
                    print "eval error: [$@]\n";
                }
                return;
            }
        }
    }
    if($cur_mode eq "php"){
        if($l!~/[\{\};]\s*$/){
            $l.=";";
        }
    }
    elsif($cur_mode eq "js"){
    }
    push @$out, $l;
}
sub dumpout {
    my ($f, $out, $pagetype)=@_;
    my $dump={out=>$out,f=>$f};
    $dump->{custom}=\&custom_dump;
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
    if(@style_key_list){
        if($MyDef::page->{type} ne "css"){
            push @$metablock, "<style>\n";
        }
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
        if($MyDef::page->{type} ne "css"){
            push @$metablock, "</style>\n";
        }
    }
    my %sheet_hash;
    foreach my $s (@$style_sheets){
        if(!$sheet_hash{$s}){
            $sheet_hash{$s}=1;
            push @$metablock, "<link rel=\"stylesheet\" type=\"text/css\" href=\"$s\" />\n";
        }
    }
    my $block=MyDef::compileutil::get_named_block("js_init");
    foreach my $v (@js_globals){
        push @$block, "var $v;\n";
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
        foreach my $l (@$pre){
            push @$out, $l;
        }
    }
    push @$out, "BLOCK";
    if($post){
        foreach my $l (@$post){
            push @$out, $l;
        }
    }
    return "NEWBLOCK";
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
            elsif($t=~/^(\s*)(page|CSS|\w+code):(.*)/){
                $t="$1<span class=\"mydef-label\">$2</span>:$3";
            }
            elsif($t=~/^(\s*)\$(call|map|if|while|switch|for|elif|elsif|else|function)\b(.*)/){
                $t="$1<span class=\"mydef-keyword\">\$$2</span>$3";
            }
            elsif($t=~/^(\s*)\&(call)(.*)/){
                $t="$1<span class=\"mydef-keyword\">\&$2</span>$3";
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
sub js_string {
    my ($t)=@_;
    my @parts=split /(\$\w+)/, $t;
    if($parts[0]=~/^$/){
        shift @parts;
    }
    for(my $i=0;$i<@parts;$i++){
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
    my $fields=$MyDef::def->{fields};
    my $ff=$fields->{varname};
    my $type=getfieldtype($ff, $colname);
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
        if($ff->{null_on_empty}){
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
    my ($ff, $colname)=@_;
    my $type;
    if($ff->{type}){
        return $ff->{type};
    }
    elsif($colname=~/_id$/){
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
    $ff->{type}=$type;
    return $type;
}
1;
