use strict;
package MyDef::output_php;
use MyDef::compileutil;
use Term::ANSIColor qw(:constants);
my $php;
my @style_key_list;
my $style;
my $style_sheets;
my $cur_mode="html";
my $in_js=0;
use MyDef::dumpout;
our $debug;
our $mode;
our $page;
our $out;
sub get_interface {
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout);
}
sub init_page {
    ($page)=@_;
    my $ext="php";
    if($MyDef::var->{filetype}){
        $ext=$MyDef::var->{filetype};
    }
    if($page->{type}){
        $ext=$page->{type};
    }
    my $cur_mode="html";
    $php={};
    $style={};
    @style_key_list=();
    $style_sheets=[];
    $page->{pageext}=$ext;
    my $init_mode=$page->{init_mode};
    return ($ext, $init_mode);
}
sub set_output {
    $out = shift;
}
sub modeswitch {
    my ($mode, $in)=@_;
    if($mode eq "sub"){
        $mode="php";
    }
    if($mode ne $cur_mode){
        if($cur_mode eq "php"){
            if($out->[-1]=~/^<\?php/){
                pop @$out;
            }
            else{
                push @$out, "?>\n";
            }
        }
        if($in_js and !($mode eq "php" and $in) and ($mode ne "js")){
            push @$out, "</script>\n";
            $in_js=0;
        }
        if($mode eq "php"){
            if($out->[-1]=~/^\?>/){
                pop @$out;
            }
            else{
                push @$out, "<?php\n";
            }
        }
        if(!$in_js and $mode eq "js"){
            push @$out, "<script type=\"text/javascript\">\n";
            $in_js=1;
        }
        $cur_mode=$mode;
    }
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
    elsif($l=~/^NOOP/){
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
    if($l=~/^\s*CSS: (.*)\s*\{(.*)\}/){
        if($style->{$1}){
            $style->{$1}.=";$2";
        }
        else{
            $style->{$1}=$2;
            push @style_key_list, $1;
        }
    }
    elsif($l=~/^\s*PRINT/){
        push @$out, $l;
    }
    elsif($l=~/^\s*\$(\w+)(.*)$/){
        my $func=$1;
        my $param=$2;
        $param=~s/^\s+//;
        $param=~s/:?\s*$//;
        if($func eq "php"){
            $l=$param;
            if($l!~/[\{\};]\s*$/){
                $l.=";";
            }
            push @$out, $l;
        }
        elsif($func=~/^(img)$/){
            my @tt_list=split /,\s*/, $param;
            my $is_empty_tag=0;
            my $t="";
            if($func eq "tag" and @tt_list){
                $func=shift @tt_list;
            }
            if($func eq "script"){
                $t= " type=\"text/javascript\"";
            }
            foreach my $tt (@tt_list){
                if($tt eq "/"){
                    $is_empty_tag=1;
                }
                elsif($tt=~/^#(\S+)$/){
                    $t.=" id=\"$1\"";
                }
                elsif($tt=~/^(\S+?):"(.*)"/){
                    $t.=" $1=\"$2\"";
                }
                elsif($tt=~/^(\S+?):(.*)/){
                    $t.=" $1=\"$2\"";
                }
                elsif($tt=~/^"(.*)"/){
                    $t.=" class=\"$1\"";
                }
                else{
                    $t.=" class=\"$tt\"";
                }
            }
            if($func eq "form"){
                if($t!~/action=/){
                    $t.=" action={\$_SERVER['PHP_SELF']}";
                }
                if($t!~/method=/){
                    $t.=" method=\"post\"";
                }
            }
            push @$out, "PRINTLN <$func$t />";
        }
        elsif($func =~ /^(tag|div|span|center|ol|ul|li|table|tr|td|th|b|script|style|p|h[1-5]|center|pre|html|head|body|a|form|label|fieldset|button|textarea)$/){
            my @tt_list=split /,\s*/, $param;
            my $is_empty_tag=0;
            my $t="";
            if($func eq "tag" and @tt_list){
                $func=shift @tt_list;
            }
            if($func eq "script"){
                $t= " type=\"text/javascript\"";
            }
            foreach my $tt (@tt_list){
                if($tt eq "/"){
                    $is_empty_tag=1;
                }
                elsif($tt=~/^#(\S+)$/){
                    $t.=" id=\"$1\"";
                }
                elsif($tt=~/^(\S+?):"(.*)"/){
                    $t.=" $1=\"$2\"";
                }
                elsif($tt=~/^(\S+?):(.*)/){
                    $t.=" $1=\"$2\"";
                }
                elsif($tt=~/^"(.*)"/){
                    $t.=" class=\"$1\"";
                }
                else{
                    $t.=" class=\"$tt\"";
                }
            }
            if($func eq "form"){
                if($t!~/action=/){
                    $t.=" action={\$_SERVER['PHP_SELF']}";
                }
                if($t!~/method=/){
                    $t.=" method=\"post\"";
                }
            }
            if($is_empty_tag){
                push @$out, "PRINTLN <$func$t></$func>";
            }
            else{
                return single_block("PRINTLN <$func$t>", "PRINTLN </$func>");
            }
        }
        elsif($func eq 'hidden'){
            my @p=split /,\s*/, $param;
            foreach my $n(@p){
                push @$out, "print \"<input type=\\\"hidden\\\" name=\\\"$n\\\" value=\\\"\$$n\\\" />\";";
            }
        }
        elsif($func eq 'use_css'){
            push @$style_sheets, $param;
        }
        elsif($func eq 'include'){
            if(open my $in, $param){
                MyDef::compileutil::modepush("html");
                my $omit=0;
                while(<$in>){
                    if(/<!-- start omit -->/){
                        $omit=1;
                    }
                    elsif(/<!-- end omit -->/){
                        $omit=0;
                    }
                    elsif($omit){
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
                        push @$out, "HTML_HEAD_STUFF";
                        push @$out, $_;
                    }
                    elsif(/<\/body>/i){
                        MyDef::compileutil::call_sub("js_ga");
                        push @$out, $_;
                    }
                    else{
                        push @$out, $_;
                    }
                }
                close $in;
                MyDef::compileutil::modepop();
            }
            else{
                print STDERR " Can't open [$param]\n";
            }
        }
        elsif($func eq 'loadoptlist'){
            my @flist=split /,\s*/, $param;
            foreach my $f(@flist){
                loadoptlist($out, $f);
            }
        }
        elsif($func eq 'redirect'){
            push @$out, "header('Location: $param.php');";
            push @$out, "exit();";
        }
        elsif($func eq 'setvar'){
            if($param=~/(.*), (.*)/){
                push @$out, "\$$1 = '$2';";
            }
        }
        elsif($func eq 'sqlruncache'){
            sqlrun($out, $param, 1);
        }
        elsif($func eq 'sqlrunusedb'){
            $MyDef::var->{usedb}=$param;
        }
        elsif($func eq 'sqlrun'){
            sqlrun($out, $param);
        }
        elsif($func =~ /tablelistfull(.*)/){
            tablelist($out, $param, 'full', $1);
        }
        elsif($func =~ /tablelist(.*)/){
            tablelist($out, $param, "", $1);
        }
        elsif($func =~ /csvlistfull(.*)/){
            csvlist($out, $param, 'full', $1);
        }
        elsif($func =~ /csvlist(.*)/){
            csvlist($out, $param, "", $1);
        }
        elsif($func=~/^(post|get|cookie)var$/){
            my $group='$_'.uc($1);
            my @tlist=split /,\s*/, $param;
            foreach my $p (@tlist){
                push @$out, "\$$p=$group\['$p'\];";
            }
        }
        elsif($func eq "if"){
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
        elsif($func eq 'field_label'){
            field_label($param);
        }
        elsif($func eq 'button'){
            formbutton($out, $param);
        }
        elsif($func eq 'makeiconmenu'){
            my @items=split /,\s*/, $param;
            push @$out, "PRINT <table class=\"menutable\">";
            my $j=0;
            my $col=6;
            foreach my $i(@items){
                if($i eq '|'){
                    if($j>0){push @$out, "PRINT </tr>"; $j=0;};
                    push @$out, "PRINT <tr><td colspan=$col><hr /></td></tr>";
                    $j=0;
                }
                else{
                    my $ii=$MyDef::def->{menuitems}->{$i};
                    my $l=$ii->{href};
                    if($l!~/\.(php|html)$/){
                        $l=$l.".php";
                    }
                    my $icon=$ii->{icon};
                    my $label=$ii->{label};
                    if($j==0){push @$out, "PRINT <tr>";};
                    push @$out, "PRINT <td align=center>";
                    push @$out, "PRINT <a href=\"$l\"><img src=\"$icon\" width=100 height=100></a><br />";
                    push @$out, "PRINT <a href=\"$l\">$label</a>";
                    push @$out, "PRINT </td>";
                    $j++;
                    if($j==$col){push @$out, "PRINT </tr>"; $j=0;};
                }
            }
            push @$out, "PRINT </table>";
        }
        elsif($func eq 'makelistmenu'){
            my @items=split /,\s*/, $param;
            push @$out, "PRINT <ul class=\"menulist\">";
            foreach my $i(@items){
                push @$out, "PRINT <li>";
                if($i eq '|'){
                    push @$out, "PRINT <hr>";
                }
                else{
                    my $ii=$MyDef::def->{menuitems}->{$i};
                    my $l=$ii->{href};
                    if($l!~/\.(php|html)$/){
                        $l=$l.".php";
                    }
                    my $icon=$ii->{icon};
                    my $label=$ii->{label};
                    push @$out, "PRINT <a href=\"$l\">$label</a>";
                }
                push @$out, "PRINT </li>";
            }
            push @$out, "PRINT </ul>";
        }
        else{
            if($cur_mode eq "js" and $l=~/\$jq/){
                $l=~s/\$jq\(/\$\(/g;
                $MyDef::var->{use_jquery}=1;
            }
            elsif($cur_mode eq "js" or $cur_mode eq "html"){
                print STDERR "Function \$$func Not Defined.\n";
            }
            else{
                if($l!~/[\{\};]\s*$/){
                    $l.=";";
                }
                push @$out, $l;
            }
        }
    }
    else{
        if($cur_mode ne 'html' and $cur_mode ne 'js'){
            if($l!~/[\{\};]\s*$/){
                $l.=";";
            }
        }
        else{
            $l=~s/(\$\w+)/<?php echo \1 ?>/g;
        }
        push @$out, $l;
    }
}
sub dumpout {
    my ($f, $out, $pagetype)=@_;
    my $dump={out=>$out,f=>$f};
    my $cur_mode;
    my $metablock=MyDef::compileutil::get_named_block("meta");
    dumpmeta($metablock);
    $dump->{custom}=\&custom_dump;
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
sub dumpstyle {
    my ($f, $style)=@_;
    if(@style_key_list){
        if($MyDef::page->{type} ne "css"){
            push @$f, "<style>\n";
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
                if($a eq "background-image" and $attr{$a}=~/linear-gradient\((\w+),\s*(\S+),\s*(\S+)\)/){
                    foreach my $prefix (("moz", "webkit", "ms", "o")){
                        push @tlist, "$a: -$prefix-linear-gradient($1, $2, $3)";
                    }
                }
            }
            push @$f, "    $k {". join('; ', @tlist)."}\n";
        }
        if($MyDef::page->{type} ne "css"){
            push @$f, "</style>\n";
        }
    }
}
sub dumpmeta {
    my ($f)=@_;
    if($MyDef::page->{title}){
        push @$f, "<title>$MyDef::page->{title}</title>\n";
    }
    dumpstyle($f, $style);
    my %sheet_hash;
    foreach my $s (@$style_sheets){
        if(!$sheet_hash{$s}){
            $sheet_hash{$s}=1;
            push @$f, "<link rel=\"stylesheet\" type=\"text/css\" href=\"$s\" />\n";
        }
    }
}
sub tablelist {
    my ($out, $listname, $full, $suffix)=@_;
    my $fields=$MyDef::def->{fields};
    my $table=$MyDef::def->{fieldsets}->{$listname};
    my $flist;
    if(!$table){
        @$flist=split /,\s*/, $listname;
    }
    else{
        $flist=$table->{fields};
    }
    push @$out, "PRINT <table class=\"tablelist$suffix\" cellspacing=2>";
    my $use_paritycolumn;
    if($full){
        push @$out, "PRINT <tr>";
        foreach my $f (@$flist){
            my $parity;
            if($f=~/^parity-(.*)/){
                $f=$1;
                $parity=1;
            }
            if($f=~/(.*)\((.*)\)/){
                $f=$1;
            }
            my $ff=$fields->{$f};
            if($parity){
                $use_paritycolumn=$f;
            }
            my $title=$f;
            if($ff->{title}){$title=$ff->{title};};
            my $width="";
            if($ff->{width}){$width=" width=\"$ff->{width}\"";};
            if($ff->{sort}){
                $title="<a href=\"{\$_SERVER['PHPSELF']}?$ff->{sort}\">$title<\/a>";
            }
            push @$out, "PRINT <th $width align=center>$title</th>";
        }
        push @$out, "PRINT </tr>";
    }
    push @$out, "\$j$suffix=0;";
    if($use_paritycolumn){
        push @$out, "\$cur_parity=\"\";";
    }
    push @$out, "foreach(\$itemlist$suffix as \$i$suffix){";
    if($use_paritycolumn){
        push @$out, "   \$cur_parity=\$i$suffix\['$use_paritycolumn'];";
        push @$out, "   if(!isset(\$old_parity)){\$old_parity=\$cur_parity;}";
        push @$out, "    if(\$cur_parity!=\$old_parity){\$old_parity=\$cur_parity; \$j$suffix++;}";
    }
    else{
        push @$out, "    \$j$suffix++;";
    }
    push @$out, "    if(\$j$suffix%2){\$tdclass=\"even$suffix\";}";
    push @$out, "    else{\$tdclass=\"odd$suffix\";}";
    my $rlink=$MyDef::compileutil::deflist->[-1]->{rlink};
    my $attr="class=\\\"\$tdclass\\\"";
    if($rlink){
        $rlink=~s/\$\[(.*?)\]/{\$i$suffix\['\1']}/g;
        $attr.=" onclick=\\\"window.location.href='$rlink'\\\"";
    }
    push @$out, "    print \"<tr $attr>\";";
    foreach my $f (@$flist){
        my $ff=$fields->{$f};
        my $align="center";
        if($ff->{align}){
            $align=$ff->{align};
        }
        my $width="";
        if($ff->{width}){$width=" width=\\\"$ff->{width}\\\"";};
        push @$out, "    print \"<td align=$align $width>\";";
        display_list_field($out, $f, $fields, $suffix);
        push @$out, "    print \"</td>\";";
    }
    push @$out, "    print \"</tr>\";";
    push @$out, "}";
    push @$out, "PRINT </table>";
}
sub script_selectother {
    my ($name)=@_;
    my @lines;
    push @lines, "function selectother_$name(e){";
    push @lines, "    if(e.value=='other'){";
    push @lines, "        document.getElementById('other_$name').style.display='block';";
    push @lines, "    }";
    push @lines, "    else{";
    push @lines, "        document.getElementById('other_$name').style.display='none';";
    push @lines, "    }";
    push @lines, "}";
    $MyDef::def->{scripts}->{"selectother_$name"}=\@lines;
}
sub loadoptlist {
    my ($out, $f)=shift;
    my $ff=$MyDef::def->{fields}->{$f};
    if(!$ff){print "loadoptlist: $f not defined.\n";};
    if($ff->{list} and $ff->{type} ne 'boolean'){
        my $listname="$f"."_optlist";
        my @list;
        if($ff->{list}=~/^\s*(\d+)-(\d+)\s*$/){
            for(my $j=$1; $j<=$2; $j++){
                push @list, "\"$j\"=>\"$j\"";
            }
        }
        else{
            my @opts=split /,\s*/, $ff->{list};
            foreach my $o(@opts){
                if($o=~/(.*):(.*)/){
                    push @list, "\"$1\"=>\"$2\"";
                }
                else{
                    push @list, "\"$o\"=>\"$o\"";
                }
            }
        }
        push @$out, "\$$listname=array(".join(', ', @list).");";
    }
}
sub formpreloadselection {
    my ($out, $formname)=@_;
    my $form=$MyDef::def->{fieldsets}->{$formname};
    my $fields=$MyDef::def->{fields};
    my $flist=$form->{fields};
    foreach my $f (@$flist){
        my $ff=$fields->{$f};
        if($ff->{list}){
            my $listname="$f"."_optlist";
            my @opts=split /,\s*/, $ff->{list};
            my @list;
            foreach my $o(@opts){
                push @list, "\"$o\"=>\"$o\"";
            }
            push @$out, "\$$listname=array(".join(', ', @list).");";
        }
    }
}
sub getfieldsize {
    my ($ff, $type) =@_;
    my $size=$ff->{size};
    if(!$size){
        if($type eq "year"){
            $size=4;
        }
        elsif($type eq "date"){
            $size=10;
        }
        elsif($type eq "money"){
            $size=10;
        }
        elsif($type eq "zip"){
            $size=5;
        }
        elsif($type eq "int"){
            $size=5;
        }
        elsif($type eq "phone"){
            $size=15;
        }
        elsif($type eq "email"){
            $size=25;
        }
        elsif($type eq "usdollar"){
            $size=12;
        }
        else{
            $size=50;
        }
    }
    return $size;
}
sub getfieldlistname {
    my ($ff, $f)=@_;
    if($ff->{listname}){
        return $ff->{listname};
    }
    elsif($ff->{list}){
        return $f.'_optlist';
    }
}
sub getfieldlabel {
    my ($ff, $f) =@_;
    my $title=$f;
    if($ff->{title}){$title=$ff->{title};};
    return "$title";
}
sub formbutton {
    my ($out, $param)=@_;
    my @bb=split /,\s*/, $param;
    push @$out, "PRINT &nbsp;";
    my $MODE;
    if($bb[1]){
        $MODE="onclick=\\\"this.form.MODE.value='$bb[1]'; return true;\\\"";
    }
    push @$out, "print \"<input class=\\\"formbutton\\\" type=\\\"submit\\\" value=\\\"$bb[0]\\\" onmouseover=\\\"this.style.borderColor='silver';\\\" onmouseout=\\\"this.style.borderColor='gray';\\\" $MODE>\";";
    push @$out, "PRINT &nbsp;";
}
1;
sub custom_dump {
    my ($f, $rl)=@_;
    if($$rl=~/^<\?php/){
        $cur_mode="php";
        push @$f, "<?php\n";
    }
    elsif($$rl=~/^\?>/){
        $cur_mode="html";
        push @$f, "?>\n";
    }
    elsif($$rl=~/^\s*HTML_START\s*(.*)/){
        push @$f, "<!DOCTYPE html>\n";
        push @$f, "<html><head>\n";
        dumpmeta($f);
        push @$f, "</head>\n";
        push @$f, "<body $1>\n";
        return 1;
    }
    elsif($$rl=~/^\s*HTML_HEAD_START/){
        push @$f, "<!DOCTYPE html>\n";
        push @$f, "<html><head>\n";
        return 1;
    }
    elsif($$rl=~/^\s*HTML_HEAD_STUFF/){
        dumpmeta($f);
        return 1;
    }
    elsif($$rl=~/^\s*HTML_STYLE/){
        dumpstyle($f, $style);
        return 1;
    }
    elsif($$rl=~/^\s*HTML_BODY_START\s*(.*)/){
        push @$f, "</head>\n";
        push @$f, "<body $1>\n";
        return 1;
    }
    elsif($$rl=~/^\s*HTML_END/){
        push @$f, "</body></html>\n";
        return 1;
    }
    else{
        if($$rl=~/\\span_(\w+)\{([^}]*)\}/){
            my $t="<span class=\"$1\">$2</span>";
            $$rl=$`.$t.$';
        }
        if($$rl=~/PRINT(LN)? (.*)/){
            my $ln=$1;
            my $t=$2;
            if($cur_mode eq "php"){
                $t=~s/\\/\\\\/g;
                $t=~s/"/\\"/g;
                if($ln){
                    $$rl="echo \"$t\\n\";";
                }
                else{
                    $$rl="echo \"$t\";";
                }
            }
            else{
                $$rl=$t;
            }
        }
        return 0;
    }
}
sub dumpstyle {
    my ($f, $style)=@_;
    if(@style_key_list){
        if($MyDef::page->{type} ne "css"){
            push @$f, "<style>\n";
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
                if($a eq "background-image" and $attr{$a}=~/linear-gradient\((\w+),\s*(\S+),\s*(\S+)\)/){
                    foreach my $prefix (("moz", "webkit", "ms", "o")){
                        push @tlist, "$a: -$prefix-linear-gradient($1, $2, $3)";
                    }
                }
            }
            push @$f, "    $k {". join('; ', @tlist)."}\n";
        }
        if($MyDef::page->{type} ne "css"){
            push @$f, "</style>\n";
        }
    }
}
sub dumpmeta {
    my ($f)=@_;
    if($MyDef::page->{title}){
        push @$f, "<title>$MyDef::page->{title}</title>\n";
    }
    dumpstyle($f, $style);
    my %sheet_hash;
    foreach my $s (@$style_sheets){
        if(!$sheet_hash{$s}){
            $sheet_hash{$s}=1;
            push @$f, "<link rel=\"stylesheet\" type=\"text/css\" href=\"$s\" />\n";
        }
    }
}
sub tablelist {
    my ($out, $listname, $full, $suffix)=@_;
    my $fields=$MyDef::def->{fields};
    my $table=$MyDef::def->{fieldsets}->{$listname};
    my $flist;
    if(!$table){
        @$flist=split /,\s*/, $listname;
    }
    else{
        $flist=$table->{fields};
    }
    push @$out, "PRINT <table class=\"tablelist$suffix\" cellspacing=2>";
    my $use_paritycolumn;
    if($full){
        push @$out, "PRINT <tr>";
        foreach my $f (@$flist){
            my $parity;
            if($f=~/^parity-(.*)/){
                $f=$1;
                $parity=1;
            }
            if($f=~/(.*)\((.*)\)/){
                $f=$1;
            }
            my $ff=$fields->{$f};
            if($parity){
                $use_paritycolumn=$f;
            }
            my $title=$f;
            if($ff->{title}){$title=$ff->{title};};
            my $width="";
            if($ff->{width}){$width=" width=\"$ff->{width}\"";};
            if($ff->{sort}){
                $title="<a href=\"{\$_SERVER['PHPSELF']}?$ff->{sort}\">$title<\/a>";
            }
            push @$out, "PRINT <th $width align=center>$title</th>";
        }
        push @$out, "PRINT </tr>";
    }
    push @$out, "\$j$suffix=0;";
    if($use_paritycolumn){
        push @$out, "\$cur_parity=\"\";";
    }
    push @$out, "foreach(\$itemlist$suffix as \$i$suffix){";
    if($use_paritycolumn){
        push @$out, "   \$cur_parity=\$i$suffix\['$use_paritycolumn'];";
        push @$out, "   if(!isset(\$old_parity)){\$old_parity=\$cur_parity;}";
        push @$out, "    if(\$cur_parity!=\$old_parity){\$old_parity=\$cur_parity; \$j$suffix++;}";
    }
    else{
        push @$out, "    \$j$suffix++;";
    }
    push @$out, "    if(\$j$suffix%2){\$tdclass=\"even$suffix\";}";
    push @$out, "    else{\$tdclass=\"odd$suffix\";}";
    my $rlink=$MyDef::compileutil::deflist->[-1]->{rlink};
    my $attr="class=\\\"\$tdclass\\\"";
    if($rlink){
        $rlink=~s/\$\[(.*?)\]/{\$i$suffix\['\1']}/g;
        $attr.=" onclick=\\\"window.location.href='$rlink'\\\"";
    }
    push @$out, "    print \"<tr $attr>\";";
    foreach my $f (@$flist){
        my $ff=$fields->{$f};
        my $align="center";
        if($ff->{align}){
            $align=$ff->{align};
        }
        my $width="";
        if($ff->{width}){$width=" width=\\\"$ff->{width}\\\"";};
        push @$out, "    print \"<td align=$align $width>\";";
        display_list_field($out, $f, $fields, $suffix);
        push @$out, "    print \"</td>\";";
    }
    push @$out, "    print \"</tr>\";";
    push @$out, "}";
    push @$out, "PRINT </table>";
}
sub script_selectother {
    my ($name)=@_;
    my @lines;
    push @lines, "function selectother_$name(e){";
    push @lines, "    if(e.value=='other'){";
    push @lines, "        document.getElementById('other_$name').style.display='block';";
    push @lines, "    }";
    push @lines, "    else{";
    push @lines, "        document.getElementById('other_$name').style.display='none';";
    push @lines, "    }";
    push @lines, "}";
    $MyDef::def->{scripts}->{"selectother_$name"}=\@lines;
}
sub loadoptlist {
    my ($out, $f)=shift;
    my $ff=$MyDef::def->{fields}->{$f};
    if(!$ff){print "loadoptlist: $f not defined.\n";};
    if($ff->{list} and $ff->{type} ne 'boolean'){
        my $listname="$f"."_optlist";
        my @list;
        if($ff->{list}=~/^\s*(\d+)-(\d+)\s*$/){
            for(my $j=$1; $j<=$2; $j++){
                push @list, "\"$j\"=>\"$j\"";
            }
        }
        else{
            my @opts=split /,\s*/, $ff->{list};
            foreach my $o(@opts){
                if($o=~/(.*):(.*)/){
                    push @list, "\"$1\"=>\"$2\"";
                }
                else{
                    push @list, "\"$o\"=>\"$o\"";
                }
            }
        }
        push @$out, "\$$listname=array(".join(', ', @list).");";
    }
}
sub formpreloadselection {
    my ($out, $formname)=@_;
    my $form=$MyDef::def->{fieldsets}->{$formname};
    my $fields=$MyDef::def->{fields};
    my $flist=$form->{fields};
    foreach my $f (@$flist){
        my $ff=$fields->{$f};
        if($ff->{list}){
            my $listname="$f"."_optlist";
            my @opts=split /,\s*/, $ff->{list};
            my @list;
            foreach my $o(@opts){
                push @list, "\"$o\"=>\"$o\"";
            }
            push @$out, "\$$listname=array(".join(', ', @list).");";
        }
    }
}
sub getfieldsize {
    my ($ff, $type) =@_;
    my $size=$ff->{size};
    if(!$size){
        if($type eq "year"){
            $size=4;
        }
        elsif($type eq "date"){
            $size=10;
        }
        elsif($type eq "money"){
            $size=10;
        }
        elsif($type eq "zip"){
            $size=5;
        }
        elsif($type eq "int"){
            $size=5;
        }
        elsif($type eq "phone"){
            $size=15;
        }
        elsif($type eq "email"){
            $size=25;
        }
        elsif($type eq "usdollar"){
            $size=12;
        }
        else{
            $size=50;
        }
    }
    return $size;
}
sub getfieldlistname {
    my ($ff, $f)=@_;
    if($ff->{listname}){
        return $ff->{listname};
    }
    elsif($ff->{list}){
        return $f.'_optlist';
    }
}
sub getfieldlabel {
    my ($ff, $f) =@_;
    my $title=$f;
    if($ff->{title}){$title=$ff->{title};};
    return "$title";
}
sub formbutton {
    my ($out, $param)=@_;
    my @bb=split /,\s*/, $param;
    push @$out, "PRINT &nbsp;";
    my $MODE;
    if($bb[1]){
        $MODE="onclick=\\\"this.form.MODE.value='$bb[1]'; return true;\\\"";
    }
    push @$out, "print \"<input class=\\\"formbutton\\\" type=\\\"submit\\\" value=\\\"$bb[0]\\\" onmouseover=\\\"this.style.borderColor='silver';\\\" onmouseout=\\\"this.style.borderColor='gray';\\\" $MODE>\";";
    push @$out, "PRINT &nbsp;";
}
