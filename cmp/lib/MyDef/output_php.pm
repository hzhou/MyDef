use MyDef::compileutil;
use Term::ANSIColor qw(:constants);
my $php;
my $style;
my $style_sheets;
my $java_scripts;
my $inphp=0;
my  $injs=0;
use MyDef::dumpout;
package MyDef::output_php;
my $debug;
my $mode;
my $out;
sub get_interface {
    return (\&init_page, \&parsecode, \&modeswitch, \&dumpout);
}
sub init_page {
    my ($page)=@_;
    my $ext="php";
    if($page->{type}){
        $ext=$page->{type};
    }
    $php={};
    $style={};
    $style_sheets=[];
    $java_scripts=[];
    return ($ext, "html");
}
sub modeswitch {
    my $pmode;
    ($pmode, $mode, $out)=@_;
    if($mode eq "js" and $pmode ne "js"){
        if($pmode ne "html"){
            push @$out, "PHP_END";
        }
        push @$out, "JS_START";
    }
    elsif($pmode eq "js" and $mode ne "js"){
        push @$out, "JS_END";
        if($mode ne "html"){
            push @$out, "PHP_START";
        }
    }
    elsif($pmode ne "html" and $mode eq "html"){
        push @$out, "PHP_END";
    }
    elsif($pmode eq "html" and $mode ne "html"){
        push @$out, "PHP_START";
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
    if($l=~/^\s*CSS: (.*)\s*\{(.*)\}/){
        if($style->{$1}){
            $style->{$1}.=";$2";
        }
        else{
            $style->{$1}=$2;
        }
    }
    elsif($l=~/^\s*(CSS|JS):\s*(\S+)/){
        if($1 eq "CSS"){
            push @$style_sheets, $2;
        }
        elsif($1 eq "JS"){
            push @$java_scripts, $2;
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
            push @$out, terminate_php($param);
        }
        elsif($param =~ /^\s*[\[=+-\.\/\*]/){
            push @$out, '$'.$func.terminate_php($param);
        }
        elsif($func=~/^(img|input)$/)
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
                elsif($tt=~/^(\S+):"(.*)"/){
                    $t.=" $1=\"$2\"";
                }
                elsif($tt=~/^(\S+):(.*)/){
                    $t.=" $1=\"$2\"";
                }
                elsif($tt=~/^"(.*)"/){
                    $t.=" class=\"$1\"";
                }
                else{
                    $t.=" class=\"$tt\"";
                }
            }
            push @$out, "PRINTLN <$func$t />";
        }
        elsif($func =~ /^(tag|div|span|center|ol|ul|li|table|tr|td|th|b|script|style|p|h[1-5]|center|pre|html|head|body|a|form|label)$/){
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
                elsif($tt=~/^(\S+):"(.*)"/){
                    $t.=" $1=\"$2\"";
                }
                elsif($tt=~/^(\S+):(.*)/){
                    $t.=" $1=\"$2\"";
                }
                elsif($tt=~/^"(.*)"/){
                    $t.=" class=\"$1\"";
                }
                else{
                    $t.=" class=\"$tt\"";
                }
            }
            if($is_empty_tag){
                push @$out, "PRINTLN <$func$t></$func>";
            }
            else{
                simple_block("PRINTLN <$func$t>", "PRINTLN </$func>", $out);
            }
        }
        elsif($func =~ /^cell([az]*)/){
            my $t=$1;
            my $attr="";
            my ($tr_begin, $tr_end);
            if($param=~/(\d+)/){
                $attr=" colspan=$&";
            }
            elsif($param){
                $attr=" class=\"$param\"";
            }
            if($t=~/a/){
                $tr_begin="<tr valign=\"top\">";
            }
            if($t=~/z/){
                $tr_end="</tr>";
            }
            simple_block("PRINTLN $tr_begin<td$attr>", "PRINTLN </td>$tr_end", $out);
        }
        elsif($func eq 'fieldset'){
            simple_block("PRINTLN <fieldset><legend>$param</legend>", "PRINTLN </fieldset>", $out);
        }
        elsif($func eq 'jssrc'){
            push @$out, "PRINT <script type=\"text/javascript\" src='$param'></script>";
        }
        elsif($func eq 'divbox'){
            push @$out, "PRINT <div id='$param' ></div>";
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
        elsif($func eq 'error'){
            push @$out, "\$errors[]=$param;";
        }
        elsif($func eq 'formhead'){
            formhead($out, $param);
        }
        elsif($func eq 'formtail'){
            my @p=split /,\s*/, $param;
            foreach my $n(@p){
                push @$out, "if(isset(\$$n)){";
                push @$out, "    print \"<input type=\\\"hidden\\\" name=\\\"$n\\\", value=\\\"\$$n\\\" />\";";
                push @$out, "}";
                push @$out, "else{";
                push @$out, "    print \"<input type=\\\"hidden\\\" name=\\\"$n\\\", value=\\\"\\\" />\";";
                push @$out, "}";
            }
            push @$out, 'print "</form>";';
        }
        elsif($func eq 'loadoptlist'){
            my @flist=split /,\s*/, $param;
            foreach my $f(@flist){
                loadoptlist($out, $f);
            }
        }
        elsif($func eq 'forminit'){
            forminit($out, $param);
        }
        elsif($func eq 'formshow'){
            formshow($out, $param);
        }
        elsif($func eq 'hidden'){
            my @p=split /,\s*/, $param;
            foreach my $n(@p){
                push @$out, "print \"<input type=\\\"hidden\\\" name=\\\"$n\\\" value=\\\"\$$n\\\" />\";";
            }
        }
        elsif($func eq 'postloadonly'){
            foreach my $f (splitlist($param)){
                if($f=~/(\w+)\((\w+)\)/){$f=$1;};
                post_load_only($out, $f);
            }
        }
        elsif($func eq 'postload'){
            foreach my $f (splitlist($param)){
                if($f=~/(\w+)\((\w+)\)/){$f=$1;};
                post_load($out, $f);
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
            simple_block("if($param){", "}", $out);
        }
        elsif($func eq "ifz"){
            if($param=~/(\$\w+)\[(^[\]]*)\]/){
                simple_block("if(!(array_key_exists($2, $1) and $param)){", "}", $out);
            }
            else{
                simple_block("if(empty($param)){", "}", $out);
            }
        }
        elsif($func eq "ifnz"){
            if($param=~/(\$\w+)\[(^[\]]*)\]/){
                simple_block("if((array_key_exists($2, $1) and $param)){", "}", $out);
            }
            else{
                simple_block("if(!empty($param)){", "}", $out);
            }
        }
        elsif($func =~ /^(el|els|else)if$/){
            if($mode eq 'html' or $mode eq 'js'){
                simple_block("else if($param){", "}", $out);
            }
            else{
                simple_block("elseif($param){", "}", $out);
            }
        }
        elsif($func eq "else"){
            simple_block("else{", "}", $out);
        }
        elsif($func eq "foreach" or $func eq "for" or $func eq "while"){
            simple_block("$func ($param){", "}", $out);
        }
        elsif($func eq "function"){
            simple_block("function $param {", "}", $out);
        }
        elsif($func eq 'input'){
            input($out, $param);
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
            if($mode eq "js" and $l=~/\$jq/){
                $l=~s/\$jq\(/\$\(/g;
                $MyDef::var->{use_jquery}=1;
            }
            elsif($mode eq "js" or $mode eq "html"){
                print STDERR "Function \$$func Not Defined.\n";
            }
            else{
                $l=terminate_php($l);
                push @$out, $l;
            }
        }
    }
    else{
        if($mode ne 'html' and $mode ne 'js'){
            $l=terminate_php($l);
        }
        push @$out, $l;
    }
}
sub dumpout {
    my ($f, $out)=@_;
    my $dump={out=>$out,f=>$f};
    my $metablock=MyDef::compileutil::get_named_block("meta");
    dumpmeta($metablock);
    dumpstyle($metablock, $style);
    $dump->{custom}=\&custom_dump;
    MyDef::dumpout::dumpout($dump);
}
sub simple_block {
    my ($pre, $post, $out)=@_;
    push @$out, "$pre";
    push @$out, "INDENT";
    push @$out, "BLOCK";
    push @$out, "DEDENT";
    push @$out, "$post";
    return "NEWBLOCK";
}
sub terminate_php {
    my $l=shift;
    if($l!~/[\{\};]\s*$/){
        $l=$l.";";
    }
    return $l;
}
sub dumpstyle {
    my ($f, $style)=@_;
    my @keys=sort keys %$style;
    if(@keys){
        print "Dumping style: $style\n";
        print "Dump hash $style\n";
        while(my ($k, $v) = each %$style){
            print "    ", "$k: $v\n";
        }
        if($MyDef::page->{type} ne "css"){
            push @$f, "<style>\n";
        }
        foreach my $k (@keys){
            my %attr;
            my @tlist=split /;/, $style->{$k};
            foreach my $t(@tlist){
                if($t=~/(\S+):\s+(.*)/){
                    $attr{$1}=$2;
                }
            }
            @tlist=();
            foreach my $a (keys(%attr)){
                push @tlist, "$a: $attr{$a}";
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
    my %sheet_hash;
    foreach my $s (@$style_sheets){
        if(!$sheet_hash{$s}){
            $sheet_hash{$s}=1;
            push @$f, "<link rel=\"stylesheet\" type=\"text/css\" href=\"$s\" />\n";
        }
    }
    my %js_hash;
    foreach my $s (@$java_scripts){
        if(!$js_hash{$s}){
            $js_hash{$s}=1;
            push @$f, "<script type=\"text/javascript\" src=\"$s\" />\n";
        }
    }
}
sub post_load_only {
    my ($out, $f)=@_;
    my $ff=$MyDef::def->{fields}->{$f};
    my $type=get_f_type($f);
    my $name=get_f_name($f);
    my $isout=0;
    if($type eq "imagefile"){
        $isout=1;
    }
    elsif($type eq 'date' and !$ff->{optional}){
        push @$out, "\$$name=\$_POST['year_$name'].'-'.\$_POST['month_$name'].'-'.\$_POST['date_$name'];";
        $isout=1;
    }
    if(!$isout){
        push @$out, "if(array_key_exists('$name', \$_POST)){";
        push @$out, "    \$$name= stripslashes (\$_POST['$name']);";
        push @$out, "}";
        if($ff->{other}){
            if(0){
            }
            else{
                push @$out, "if(\$$name=='other'){\$$name=stripslashes(\$_POST['other_$name']);}";
            }
        }
    }
}
sub post_load {
    my ($out, $f)=@_;
    post_load_only($out, $f);
    my $ff=$MyDef::def->{fields}->{$f};
    my $type=get_f_type($f);
    my $name=get_f_name($f);
    my $title=get_f_label($f);
    if(!$ff->{optional}){
        if($type eq 'boolean'){
            push @$out, "if(\$$name != '0' and \$$name != '1'){";
            push @$out, "    \$errors[]=\"Please select $title.\";";
            push @$out, "    \$error_fields['$name']=1;";
            push @$out, "}";
        }
        elsif($type eq 'image'){
            push @$out, "if(!is_uploaded_file(\$_FILES['$name']['tmp_name'])){";
            push @$out, "    \$error_fields['$name']=1;";
            push @$out, "}";
        }
        else{
            push @$out, "if(!\$$name){";
            push @$out, "    \$errors[]=\"Please enter $title.\";";
            push @$out, "    \$error_fields['$name']=1;";
            push @$out, "}";
        }
    }
    if($type eq 'date'){
        push @$out, "if(\$$name){";
            push @$out, "if(!preg_match('/\\d\\d\\/\\d\\d\\/\\d\\d\\d\\d/', \$$name)){";
            push @$out, "    \$error_fields['$name']=1;";
            push @$out, "    \$errors[]='Please enter \"$title\" in mm/dd/yyyy format.';";
            push @$out, "}";
        push @$out, "}";
    }
    if($type eq 'email'){
        push @$out, "if(\$$name){";
            push @$out, "if(!preg_match('/\\S+\@\\S+/', \$$name)){";
            push @$out, "    \$error_fields['$name']=1;";
            push @$out, "    \$errors[]='Please enter a valid E-Mail address.';";
            push @$out, "}";
        push @$out, "}";
    }
    if($type eq 'phone'){
        push @$out, "\$$name=ereg_replace('[^0-9]', '', \$$name);";
        if(!$ff->{optional}){
            push @$out, "if(!\$$name){";
                push @$out, "    \$error_fields['$name']=1;";
                push @$out, "    \$errors[]='Please enter a valid number.';";
            push @$out, "}";
        }
    }
}
sub forminit {
    my ($out, $name)=@_;
    my $form=$MyDef::def->{fieldsets}->{$name};
    my $fields=$form->{fields};
    foreach my $f (@$fields){
        push @$out, "\$$f='';";
    }
}
sub sql_exec {
    my $out=shift;
    push @$out, "\$r=mysql_query(\$sql, \$$MyDef::var->{usedb});";
    push @$out, "if(!\$r){\$errors[]='Database Error'; \$tpage=addslashes(\$_SERVER['PHP_SELF']);\$tsql=addslashes(\$sql);mysql_query(\"INSERT INTO log_errsql (errsql,page) VALUES ('\$tsql', '\$tpage)'\", \$$MyDef::var->{usedb});}";
    push @$out, "if(!\$r){\$infos[]=\"ErrSQL: \$sql\";}";
    if($MyDef::page->{'show_sql'}){ push @$out, "\$infos[]='sql: '.\$sql;"; };
}
sub sql_parse_var {
    my $t=shift;
    my ($varname, $colname);
    if($t=~/^([^(]*)\((.*)\)$/){
        $varname=$1;
        $colname=$2;
    }
    else{
        $varname=$t;
        $colname=$t;
    }
    return ($varname, $colname);
}
sub sql_update {
    my ($out, $use_cache, $head, $param, $tail)=@_;
    my @flist=split /,\s*/, $param;
    my $fields=$MyDef::def->{fields};
    my @sqlsegs;
    foreach my $f (@flist){
        if($f=~/(.*)=(.*)/){
            push @sqlsegs, $f;
        }
        else{
            my ($varname, $colname);
            if($f=~/^(.*)\((.*)\)$/){
                $varname=$1;
                $colname=$2;
            }
            else{
                $varname=$f;
                $colname=$f;
            }
            my $ff=$fields->{$varname};
            my $type=getfieldtype($ff, $colname);
            if($type =~/^(int|uint|boolean)$/){
                push @$out, "if(is_numeric(\$$varname)){";
                push @$out, "    \$t_$varname=\$$varname;";
                push @$out, "}else{";
                push @$out, "    \$t_$varname=\"NULL\";";
                push @$out, "}";
                push @sqlsegs, "$colname=\$t_$varname";
            }
            elsif($type eq 'date'){
                push @$out, "if(\$$varname){";
                push @$out, "    \$t_$varname=\"'\".\$$varname.\"'\";";
                push @$out, "}else{";
                push @$out, "    \$t_$varname=\"NULL\";";
                push @$out, "}";
                push @sqlsegs, "$colname=\$t_$varname";
            }
            elsif($type eq 'now'){
                push @sqlsegs, "$colname=NOW()";
            }
            elsif($type eq 'today' or $type eq 'curdate'){
                push @sqlsegs, "$colname=CURDATE()";
            }
            else{
                if($ff->{null_on_empty}){
                    push @$out, "if(\$$varname){";
                    push @$out, "    \$t_$varname=\"'\".addslashes(\$$varname).\"'\";";
                    push @$out, "}";
                    push @$out, "else{";
                    push @$out, "    \$t_$varname='NULL';";
                    push @$out, "}";
                    push @sqlsegs, "$colname=\$t_$varname";
                }
                else{
                    push @$out, "\$t_$varname=addslashes(\$$varname);";
                    push @sqlsegs, "$colname='\$t_$varname'";
                }
            }
        }
    }
    push @$out, "\$sql = \"$head ".join(', ', @sqlsegs)." $tail\";";
    sql_exec($out);
}
sub sql_insert {
    my ($out, $head, $param)=@_;
    my @flist=split /,\s*/, $param;
    my $fields=$MyDef::def->{fields};
    my (@sqlnames, @sqlsegs);
    foreach my $f (@flist){
        if($f=~/(.*)=(.*)/){
            push @sqlnames, $1;
            push @sqlsegs, $2;
        }
        else{
            my ($varname, $colname);
            if($f=~/^(.*)\((.*)\)$/){
                $varname=$1;
                $colname=$2;
            }
            else{
                $varname=$f;
                $colname=$f;
            }
            if($item){
                push @$out, "\$$varname=\$i['$varname'];";
            }
            my $ff=$fields->{$varname};
            my $type=getfieldtype($ff, $colname);
            push @sqlnames, $colname;
            if($type =~/^(int|uint|boolean)$/){
                push @$out, "if(is_numeric(\$$varname)){";
                push @$out, "    \$t_$varname=\$$varname;";
                push @$out, "}else{";
                push @$out, "    \$t_$varname=\"NULL\";";
                push @$out, "}";
                push @sqlsegs, "\$t_$varname";
            }
            elsif($type eq 'date'){
                push @$out, "if(\$$varname){";
                push @$out, "    \$t_$varname=\"'\".\$$varname.\"'\";";
                push @$out, "}else{";
                push @$out, "    \$t_$varname=\"NULL\";";
                push @$out, "}";
                push @sqlsegs, "\$t_$varname";
            }
            elsif($type eq 'curdate' or $type eq 'today'){
                push @sqlsegs, "CURDATE()";
            }
            elsif($type eq 'now'){
                push @sqlsegs, "NOW()";
            }
            else{
                push @$out, "\$t_$varname=addslashes(\$$varname);";
                push @sqlsegs, "'\$t_$varname'";
            }
        }
    }
    push @$out, "\$sql = \"$head (".join(', ', @sqlnames).") VALUES (".join(', ', @sqlsegs).")\";";
    sql_exec($out);
}
sub sql_select {
    my ($out, $flist, $tail)=@_;
    my @sqlnames;
    foreach my $f (@$flist){
        my ($varname, $colname)=sql_parse_var($f);
        push @sqlnames, "$colname";
    }
    push @$out, '$sql = "SELECT '.join(', ', @sqlnames). " $tail\";";
    sql_exec($out);
}
sub sql_select_one {
    my ($out, $param, $tail)=@_;
    my $fields=$MyDef::def->{fields};
    my @flist=split /,\s*/, $param;
    my @sqlnames;
    my @assignments;
    my $varname;
    my $colname;
    my $i=0;
    foreach my $f (@flist){
        my ($varname, $colname)=sql_parse_var($f);
        $ff=$fields->{$varname};
        $type=getfieldtype($ff, $colname);
        push @sqlnames, $colname;
        push @assignments, "        \$$varname=\$row[$i];";
        $i++;
    }
    push @$out, '$sql = "SELECT '.join(', ', @sqlnames). " $tail\";";
    sql_exec($out);
    push @$out, "if(\$r){\$row=mysql_fetch_row(\$r);}";
    push @$out, "if(!\$row){\$empty=1;}";
    push @$out, "else{";
    push @$out, "    \$empty=0;";
    foreach my $l (@assignments){
        push @$out, $l;
    }
    push @$out, "}";
}
sub sql_select_count {
    my ($out, $use_cache, $param, $name)=@_;
    my $countname="count";
    if($name){$countname=$name."_count";};
    push @$out, "\$sql=\"SELECT count(*) $param\";";
    if($use_cache){
        push @$out, "\$cache_sql=\"SELECT result FROM sql_cache WHERE `sql`='\".addslashes(\$sql).\"' AND timestamp>DATE_SUB(CURDATE(), INTERVAL 1 DAY)\";";
        push @$out, "\$r=mysql_query(\$cache_sql, \$$MyDef::var->{usedb});";
        if($MyDef::page->{'show_sql'}){ push @$out, "\$infos[]='sql: '.\$cache_sql;"; };
        push @$out, "if(\$r){\$row=mysql_fetch_row(\$r);}";
        push @$out, "if(\$row){";
            push @$out, "\$$countname=\$row[0];";
        push @$out, "}";
        push @$out, "else{";
    }
    sql_exec($out);
    push @$out, "if(\$r){";
    push @$out, "\$row=mysql_fetch_row(\$r);";
    push @$out, "\$$countname=\$row[0];";
    push @$out, "}";
    if($use_cache){
        push @$out, "mysql_query(\"REPLACE INTO sql_cache (`sql`, result) VALUES ('\".addslashes(\$sql).\"', '\$$countname')\", \$$MyDef::var->{usedb});";
        push @$out, "}";
    }
}
sub sql_select_list {
    my ($out, $use_cache, $param, $tail, $suffix)=@_;
    my $fields=$MyDef::def->{fields};
    my @flist=split /,\s*/, $param;
    sql_select($out, \@flist, $tail);
    push @$out, "\$itemlist$suffix=array();";
    push @$out, "while (\$row=mysql_fetch_row(\$r)){";
    push @$out, "    \$i$suffix=array();";
    my $j=0;
    foreach my $f(@flist){
        my ($varname, $colname)=sql_parse_var($f);
        $ff=$fields->{$varname};
        $type=getfieldtype($ff, $colname);
        push @$out, "    \$i$suffix\['$varname']=\$row[$j];";
        $j++;
    }
    push @$out, "    \$itemlist$suffix\[]=\$i$suffix;";
    push @$out, "}";
}
sub sql_select_array {
    my ($out, $use_cache, $param, $tail)=@_;
    my $fields=$MyDef::def->{fields};
    my @flist=split /,\s*/, $param;
    sql_select($out, \@flist, $tail);
    my ($varname, $colname)=sql_parse_var($flist[0]);
    push @$out, "\$$varname\_list=array();";
    push @$out, "while (\$row=mysql_fetch_row(\$r)){";
    push @$out, "    \$$varname\_list[]=\$row[0];";
    push @$out, "}";
}
sub sql_select_hash {
    my ($out, $use_cache, $param, $tail)=@_;
    my $fields=$MyDef::def->{fields};
    my @flist=split /,\s*/, $param;
    sql_select($out, \@flist, $tail);
    my ($varname, $colname, $single);
    if(@flist==1){
        $single=1;
        ($varname, $colname)=sql_parse_var($flist[0]);
    }
    else{
        ($varname, $colname)=sql_parse_var($flist[1]);
    }
    push @$out, "\$$varname\_list=array();";
    push @$out, "while (\$row=mysql_fetch_row(\$r)){";
    if($single){
        push @$out, "    \$$varname\_list[\$row[0]]=\$row[0];";
    }
    else{
        push @$out, "    \$$varname\_list[\$row[0]]=\$row[1];";
    }
    push @$out, "}";
}
sub sqlrun {
    my ($out, $sql, $use_cache)=@_;
    if($sql=~/(UPDATE\s+\S+\s+SET)\s+(.*?)\s+(WHERE\s.*)/i){
        sql_update($out, $use_cache, $1, $2, $3);
    }
    elsif($sql=~/((INSERT|INSERT IGNORE|REPLACE)\s+INTO\s+\S+\s+)(.*)/i){
        sql_insert($out, $1, $3);
    }
    elsif($sql=~/SELECT_COUNT(_(\w+))? (FROM\s.*)/i){
        sql_select_count($out, $use_cache, $3, $2);
    }
    elsif($sql=~/SELECT_LIST\s+(.*?)\s+(FROM\s.*)/i){
        sql_select_list($out, $use_cache, $1, $2);
    }
    elsif($sql=~/SELECT_LIST(_\w+)\s+(.*?)\s+(FROM\s.*)/i){
        sql_select_list($out, $use_cache, $2, $3, $1);
    }
    elsif($sql=~/SELECT_ARRAY\s+(.*?)\s+(FROM\s.*)/i){
        sql_select_array($out, $use_cache, $1, $2);
    }
    elsif($sql=~/SELECT_HASH\s+(.*?)\s+(FROM\s.*)/i){
        sql_select_hash($out, $use_cache, $1, $2);
    }
    elsif($sql=~/SELECT\s+(.*?)\s+(FROM\s.*)/i){
        sql_select_one($out, $1, $2);
    }
    else{
        push @$out, "\$sql=\"$sql\";";
        sql_exec($out);
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
    elsif($colname eq "date_inserted" ){
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
sub sql_createtable {
    my ($tablename)=@_;
    my $fields=$MyDef::def->{fields};
    my $table=$MyDef::def->{fieldsets}->{$tablename};
    my $flist=$table->{fields};
    my $lastf=$$flist[-1];
    my $name=$table->{name};
    if(!$name){$name=$tablename;};
    my @out;
    push @out,  "DROP TABLE IF EXISTS $name;\n";
    push @out,  "CREATE TABLE $name (\n";
    if($table->{useid}){
        push @out,  "\tid INT UNSIGNED NOT NULL AUTO_INCREMENT,\n";
        push @out,  "\tPRIMARY KEY (id),\n";
    }
    if($table->{timestamp}){
        push @out, "\ttimestamp TIMESTAMP,\n";
    }
    my $unique;
    if($table->{unique}){
        my @list=split /,\s*/, $table->{unique};
        push @out, "\tUNIQUE (".join(", ", @list)."),\n";
    }
    if($table->{fulltext}){
        push @out, "\tFULLTEXT (".$table->{fulltext}."),\n";
    }
    if($table->{key}){
        my @list=split /,\s*/, $table->{key};
        push @out, "\tPRIMARY KEY (".join(", ", @list)."),\n";
    }
    if($table->{insertdate}){
        push @out, "\tdate_inserted DATE,\n";
    }
    foreach my $f (@$flist){
        my $size=50;
        my $type;
        my $defname=$f;
        my $colname=$f;
        if($f=~/(\w+)\((\w+)\)/){
            $defname=$1;
            $colname=$2;
        }
        elsif($f=~/$name\_(\w+)/){
            $defname=$f;
            $colname=$1;
        }
        push @out,  "\t$colname ";
        my $ff=$fields->{$defname};
        $type=getfieldtype($ff, $colname);
        $size=getfieldsize($ff, $type);
        if($type eq "password"){
            push @out,  "VARCHAR($size) BINARY";
        }
        elsif($type eq "datetime"){
            push @out,  "DATETIME";
        }
        elsif($type eq "curdate"){
            push @out,  "DATE";
        }
        elsif($type eq "money"){
            push @out,  "DECIMAL(10, 2)";
        }
        elsif($type eq "uint"){
            push @out,  "INT UNSIGNED";
        }
        elsif($type){
            push @out, uc($type);
        }
        else{
            push @out,  "VARCHAR($size)";
        }
        if($ff->{notnull}){push @out, " NOT NULL";};
        if(defined $ff->{default}){
            push @out, " DEFAULT $ff->{default}";
        }
        if($f eq $lastf){
            if($unique){
                push @out, ",\n\t$unique\n);\n";
            }
            else{
                push @out,  "\n);\n";
            }
        }
        else{
            push @out,  ",\n";
        }
    }
    if($table->{initlist}){
        my @values=split /,\s*/, $table->{initlist};
        my $f=$flist->[0];
        my $ff=$fields->{$f};
        $type=getfieldtype($ff, $colname);
        $size=getfieldsize($ff, $type);
        foreach my $v (@values){
            push @out, "INSERT INTO $name ($f) VALUES (".sql_quote($type, $v).");\n";
        }
        push @out,  "\n";
    }
    elsif($table->{init}){
        my $tlist=$table->{init};
        my $insert_a="INSERT INTO $name (". join(", ", @$flist).") VALUES ";
        foreach my $init_line (@$tlist){
            my @l=split /,\s*/, $init_line;
            push @out, $insert_a."('".join("', '", @l)."');\n";
        }
    }
    return join '', @out;
}
sub sql_quote {
    my ($type, $v)=@_;
    if($type =~/int|DATE/i){
        return $v;
    }
    else{
        return "'$v'";
    }
}
sub display_list_field {
    my ($out, $f, $fields, $suffix, $csv)=@_;
    my $colname;
    if($f=~/(.*)\((.*)\)/){
        $colname=$2;
        $f=$1;
    }
    else{
        $colname=$f;
    }
    my $ff=$fields->{$f};
    my $display;
    if($csv and $ff->{text_display}){
        $display=$ff->{text_display};
    }
    elsif($ff->{display}){
        $display=$ff->{display};
    }
    if($display){
        if($display=~/function (\w+)\((.*)\)/){
            my $t0=$1;
            my $t1=$2;
            $t1=~s/\$\(colname\)/$colname/g;
            push @$out, "    $t0($t1);";
        }
        elsif($display=~/function (\w+)/){
            push @$out, "    $1(\$i$suffix);";
        }
        elsif($display=~/call\s+(.*)/){
            MyDef::compileutil::call_sub($1);
        }
        elsif($display=~/do\s+(.*)/){
            push @$out, "    $1;";
        }
        else{
            my @tt;
            $display=~s/"/\\"/g;
            while($display=~/\$\[(.*?)\]/){
                push @tt, "\"$`\"";
                push @tt, "\$i$suffix\['$1'\]";
                $display=$';
            }
            push @tt, "\"$display\"";
            push @$out, "        print ".join('.',@tt).";";
        }
    }
    elsif($ff->{type} eq "boolean" and $ff->{list}){
        @l=split /,\s*/, $ff->{list};
        push @$out, "if(\$i$suffix\['$f']){";
        push @$out, "    print \"$l[0]\";";
        push @$out, "}else{";
        push @$out, "    print \"$l[1]\";";
        push @$out, "}";
    }
    else{
        $listname=getfieldlistname($ff, $f);
        if($listname){
            push @$out, "if(!empty(\$$listname) and array_key_exists(\$i$suffix\['$f'], \$$listname)){";
            push @$out, "    print \$$listname\[\$i$suffix\['$f']];";
            push @$out, "}else{";
            push @$out, "    print \$i$suffix\['$f'];";
            push @$out, "}";
        }
        else{
            if($f=~/^\$/){
                push @$out, "        print \$i$suffix\[$f];";
            }
            else{
                push @$out, "        print \$i$suffix\['$f'];";
            }
        }
    }
    if($csv){
        push @$out, "PRINT , ";
    }
}
sub csvlist {
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
    if($full){
        foreach my $f (@$flist){
            if($f=~/(.*)\((.*)\)/){
                $colname=$2;
                $f=$1;
            }
            my $ff=$fields->{$f};
            my $title=$f;
            if($ff->{title}){$title=$ff->{title};};
            push @$out, "PRINT $title, ";
        }
        push @$out, "PRINTLN ";
    }
    push @$out, "\$j$suffix=0;";
    push @$out, "foreach(\$itemlist$suffix as \$i$suffix){";
    foreach my $f (@$flist){
        display_list_field($out, $f, $fields, $suffix, "csv");
    }
    push @$out, "PRINTLN ";
    push @$out, "    \$j$suffix++;";
    push @$out, "}";
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
                $colname=$2;
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
    push @$out, "    print \"<tr>\";";
    foreach my $f (@$flist){
        my $ff=$fields->{$f};
        my $align="center";
        if($ff->{align}){
            $align=$ff->{align};
        }
        my $width="";
        if($ff->{width}){$width=" width=\\\"$ff->{width}\\\"";};
        push @$out, "    print \"<td class=\$tdclass align=$align $width>\";";
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
sub formhead {
    my ($out, $param)=@_;
    my @p=split /,\s*/, $param;
    my $formname=shift @p;
    my $method="post";
    my $action="{\$_SERVER['PHP_SELF']}";
    my $uploadlimit=0;
    my $onsubmit;
    foreach my $n(@p){
        if($n eq 'get' or $n eq 'post'){
            $method=$n;
        }
        elsif($n=~/\//){
            $action=$n;
        }
        elsif($n=~/\.php/){
            $action=$n;
        }
        elsif($n=~/\d+/){
            $uploadlimit=$n;
        }
        elsif($n=~/\(.*\)/){
            $onsubmit=$n;
        }
    }
    if($onsubmit){
        $onsubmit="onsubmit=\"return $onsubmit\"";
    }
    if($uploadlimit){
        push @$out, "PRINT <form method=\"$method\" action=\"$action\" name=\"$formname\" enctype=\"multipart/form-data\" $onsubmit>";
        push @$out, "PRINT <input type=\"hidden\" name=\"MAX_FILE_SIZE\" value=\"$uploadlimit\" />";
    }
    else{
        push @$out, "PRINT <form method=\"$method\" action=\"$action\" name=\"$formname\" $onsubmit>";
    }
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
sub formshow {
    my ($out, $formname)=@_;
    my $fields=$MyDef::def->{fields};
    my $form=$MyDef::def->{fieldsets}->{$formname};
    my $flist=$form->{fields};
    push @$out, "PRINT <div class=\"form\">";
    if($form->{title}){
        push @$out, "print '<h1 class=\"formtitle\">".$form->{title}."</h1>';";
    }
    push @$out, 'print "<table class=\"formtable\">";';
    my $labelalign="right";
    if($form->{align}){$labelalign=$form->{align};};
    foreach my $f (@$flist){
        my $ff=$fields->{$f};
        my $title=$f;
        if($ff->{title}){$title=$ff->{title};};
        my $prefix;
        if($ff->{optional}){
            push @$out, "if(\$$f){";
        }
        push @$out, "print \"<tr><td class=\\\"labelcolumn\\\" valign=\\\"top\\\" align=\\\"$labelalign\\\">\";";
        push @$out, 'print "<label>'.$title.':</label>";';
        push @$out, 'print "</td><td class=\"formspacer\"></td>";';
        push @$out, 'print "<td valign=\"top\" align=\"left\">";';
        my $listname;
        if($ff->{listname}){
            $listname=$ff->{listname};
        }
        elsif($ff->{list}){
            $listname=$f.'_optlist';
        }
        if($ff->{type} eq "boolean"){
            my $y="Yes";
            my $n="No";
            if($ff->{list}){
                my @l=split(/,\s*/, $ff->{list});
                $y=$l[0];
                $n=$l[1];
            }
            push @$out, "if(\$$f==1){print \"$y\";}";
            push @$out, "else{print \"$n\";}";
        }
        elsif($ff->{type} eq "file"){
        }
        elsif($ff->{type} eq "imagefile"){
        }
        elsif($ff->{type} eq "password"){
            print STDERR "    Password should not be displayed.\n";
        }
        else{
            if($listname){
                push @$out, "if(\$$listname){";
                push @$out, "    print \$$listname\[\$$f\];";
                push @$out, "}";
                push @$out, "else{";
                push @$out, "    print \$$f;";
                push @$out, "}";
            }
            else{
                push @$out, "print \$$f;";
            }
        }
        push @$out, "print \"</td></tr>\";";
        if($ff->{optional}){
            push @$out, "}";
        }
    }
    push @$out, 'print "</td></tr>";';
    push @$out, 'print "</table>";';
    push @$out, "PRINT </div>";
}
sub getfieldsize {
    my ($ff, $type) =@_;
    my $size=$ff->{size};
    if(!$size){
        if($type eq "year"){
            $size=4;
        }
        elsif($type eq "date"){
            $size=10; if($ff->{optional}){$valign="valign=\"middle\"";};
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
            $size=12;$prefix='\$';
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
sub form_twocolumn {
    my ($out, $fields, $displaylist, $inputlist, $maxsize, $id)=@_;
    $tlist=$displaylist;
    my $display=1;
    my $idstr;
    if($id){
        $idstr=" id=\\\"$id\\\"";
    }
    push @$out, "print \"<table class=\\\"formtable\\\"$idstr>\";";
FLIST:
    foreach my $f (@$tlist){
        my $ff=$fields->{$f};
        my $type=getfieldtype($ff, $f);
        $label=getfieldlabel($ff, $f);
        if(!$ff->{optional} and !$display){
            $label.="*";
        }
        my $valign="valign=\\\"top\\\"";
        push @$out, "print '<tr class=\"formrow\">';";
        push @$out, "print \"<td class=\\\"labelcolumn\\\" $valign align=\\\"$labelalign\\\">\";";
        push @$out, "print \"<label>$label</label>\";";
        if($ff->{help}){
            push @$out, "print \"<div class=\\\"formhelp\\\">$ff->{help}</div>\";";
        }
        push @$out, 'print "</td><td class=\"formspacer\"></td>";';
        push @$out, "print \"<td class=\\\"inputcolumn\\\">\\n\";";
        if($display){
            fielddisplay($out, $f, $ff);
        }
        else{
            fieldinput($out, $f, $ff, $maxsize);
        }
        push @$out, 'print "\n</td></tr>\n";';
    }
    if($display){
        $display=0;
        $tlist=$inputlist;
        goto FLIST;
    }
    push @$out, "print \"</table>\";";
}
sub form_one {
    my ($out, $fields, $displaylist, $inputlist, $maxsize)=@_;
    $tlist=$displaylist;
FLIST:
    foreach my $f (@$tlist){
        my $ff=$fields->{$f};
        my $type=getfieldtype($ff, $f);
        $label=getfieldlabel($ff, $f);
        if(!$ff->{optional} and !$display){
            $label.="*";
        }
        my $valign="valign=\"top\"";
        push @$out, "PRINT <p>";
        push @$out, 'print "<label>'.$label.'</label><br />";';
        if($display){
            fielddisplay($f, $ff);
        }
        else{
            fieldinput($f, $ff, $maxsize);
        }
    }
    if($display){
        $display=0;
        $tlist=$inputlist;
        goto FLIST;
    }
    push @$out, "PRINT </p>";
}
sub formbody {
    my ($out, $formname)=@_;
    formpreloadselection($out, $formname);
    my $fields=$MyDef::def->{fields};
    my $form=$MyDef::def->{fieldsets}->{$formname};
    my $inputlist=$form->{fields};
    my @displaylist=();
    if($form->{display}){
        @displaylist=split /,\s*/, $form->{display};
    }
    if(!$form->{layout}){
        $form->{layout}="2";
    }
    push @$out, "PRINT <div class=\"form\">";
    if($form->{title}){
        push @$out, "print '<h2 class=\"formtitle\">".$form->{title}."</h2>';";
    }
    if($form->{legend}){
        push @$out, "print \" <fieldset><legend>$form->{legend}</legend>\";";
    }
    my $maxsize=20;
    if($form->{maxsize}){
        $maxsize=$form->{maxsize};
    }
    if($form->{layout} eq "2"){
        form_twocolumn($out, $fields, $displaylist, $inputlist, $maxsize);
    }
    else{
        form_one($out, $fields, $displaylist, $inputlist, $maxsize);
    }
    my $buttons=$form->{buttons};
    if($buttons){
        push @$out, "PRINT <br>";
        foreach my $b(@$buttons){
            formbutton($out, $b);
        }
    }
    if($form->{legend}){
        push @$out, "PRINT </fieldset>";
    }
    push @$out, "PRINT </div>";
}
sub forminput {
    my ($out, $param, $id)=@_;
    @inputlist=split /,\s*/, $param;
    my $fields=$MyDef::def->{fields};
    my @displaylist=();
    my $maxsize=80;
    form_twocolumn($out, $fields, [], \@inputlist, $maxsize, $id);
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
sub input {
    my ($out, $f)=@_;
    my $ff=$MyDef::def->{fields}->{$f};
    my $type=getfieldtype($ff, $f);
    fieldinput($out, $f, $ff);
}
sub get_f_type {
    my $f=shift;
    my $ff=$MyDef::def->{fields}->{$f};
    my $type;
    if($ff->{type}){
        return $ff->{type};
    }
    elsif($f=~/_id$/){
        $type="uint";
    }
    elsif($f=~/_date$/ or $f=~/^date_/){
        $type="date";
    }
    elsif($f=~/_flag$/ or $f=~/^flag_/){
        $type="boolean";
    }
    elsif($f=~/_quantity$/){
        $type="int";
    }
    elsif($f=~/^number_/){
        $type="int";
    }
    elsif($f eq "password"){
        $type="password";
    }
    elsif($f =~/phone/){
        $type="phone";
    }
    elsif($f eq 'city'){
        $type='city';
    }
    elsif($f eq 'state'){
        $type='state';
    }
    elsif($f =~ /zip(code)?/){
        $type='zip';
    }
    elsif($f =~ /email/){
        $type='email';
    }
    elsif($f =~ /city_state_zip/){
        $type='city_state_zip';
    }
    $ff->{type}=$type;
    return $type;
}
sub get_f_name {
    my $f=shift;
    my $ff=$MyDef::def->{fields}->{$f};
    if(!$ff or !$ff->{name}) {return $f;};
    return $ff->{name};
}
sub get_f_listname {
    my $f=shift;
    my $ff=$MyDef::def->{fields}->{$f};
    if($ff->{listname}){
        return $ff->{listname};
    }
    elsif($ff->{list}){
        return $f.'_optlist';
    }
    return;
}
sub get_f_label {
    my $f=shift;
    my $ff=$MyDef::def->{fields}->{$f};
    if(!$ff){return $f;};
    if($ff->{title}){return $ff->{title};};
    if($ff->{label}){return $ff->{label};};
    return $f;
}
sub get_f_display {
    my $f=shift;
    my $ff=$MyDef::def->{fields}->{$f};
    if($ff->{display}){return;};
    my $listname=getfieldlistname($ff, $f);
    my $type=getfieldtype($ff, $f);
    if($type eq "boolean"){
        my $y="Yes";
        my $n="No";
        if($ff->{list}){
            my @l=split(/,\s*/, $ff->{list});
            $y=$l[0];
            $n=$l[1];
        }
        push @$out, "if(\$$f==1){print \"$y\";}";
        push @$out, "else{print \"$n\";}";
    }
    elsif($type eq "file"){
    }
    elsif($type eq "imagefile"){
    }
    elsif($type eq "password"){
        push @$out, "*** ***";
    }
    else{
        if($listname){
            push @$out, "if(\$$listname){";
            push @$out, "    print \$$listname\[\$$f\];";
            push @$out, "}";
            push @$out, "else{";
            push @$out, "    print \$$f;";
            push @$out, "}";
        }
        else{
            push @$out, "print \$$f;";
        }
    }
}
sub fieldinput {
    my ($out, $f, $ff, $maxsize) =@_;
    my $type=getfieldtype($ff, $f);
    my $size=getfieldsize($ff, $type);
    if($maxsize and $size>$maxsize){
        $size=$maxsize;
    }
    my $handler="";
    foreach my $k(keys %$ff){
        if($k=~/^on(.*)/){
            print "handler: $f - $k\n";
            $handler=$handler." $k=\"$ff->{$k}\"";
        }
    }
    my $disabled="";
    if($ff->{disabled}){
        $disabled=" disabled";
    }
    my $listname=getfieldlistname($ff, $f);
    my $prefix=$ff->{prefix};
    my $suffix=$ff->{suffix};
    my $isout=0;
    push @$out, "\$inputclass='input_normal';";
    push @$out, "if(isset(\$error_fields) and array_key_exists('$f', \$error_fields)){\$inputclass='input_error';}";
    my $input_style;
    if(!$ff->{size} and $ff->{width}){
        $input_style=" style=\"width: $ff->{width};\"";
    }
    if($type eq "boolean"){
        my $y="Yes";
        my $n="No";
        if($ff->{list}){
            my @l=split(/,\s*/, $ff->{list});
            my $j=0;
            foreach my $tl(@l){
                if($tl=~/(.*)(=>|:)([01])/){
                    if($3 eq "0"){
                        $n=$1;
                    }
                    else{
                        $y=$1;
                    }
                }
                else{
                    if($j==0){
                        $y=$tl;
                    }
                    else{
                        $n=$tl;
                    }
                }
                $j++;
            }
        }
        push @$out, "if(!empty(\$$f)){\$t=' checked';}else{\$t='';}";
        push @$out, "PRINT $y<input type=\"radio\" name=\"$f\" value=\"1\" \$t$handler $input_style>";
        push @$out, "PRINT &nbsp;&nbsp;";
        push @$out, "if(empty(\$$f)){\$t=' checked';}else{\$t='';}";
        push @$out, "PRINT $n<input type=\"radio\" name=\"$f\" value=\"0\" \$t$handler $input_style>";
        $isout=1;
    }
    elsif($type eq "checkbox"){
        push @$out, "if(!empty(\$$f)){\$t=' checked';}else{\$t='';}";
        push @$out, "PRINT <input type=\"checkbox\" name=\"$f\" \$t$handler $input_style>";
        push @$out, "PRINT &nbsp;&nbsp;";
        $isout=1;
    }
    elsif($listname){
        push @$out, "if (\$$listname){";
        my $sizestr;
        my $name=$f;
        if($ff->{size}=~/(\d+)/){
            $sizestr="size=$1";
        }
        if($ff->{multiple}){
            $sizestr.=" multiple=\"yes\"";
            $name.="[]";
        }
        if($ff->{other}){
            push @$out, "PRINT <select class=\"\$inputclass\" name=\"$name\" onchange=\"selectother_$f(this);\" $sizestr $input_style>";
            push @$out, '$selected=0;';
        }
        else{
            push @$out, "PRINT <select class=\"\$inputclass\" name=\"$name\" $handler $sizestr $input_style>";
        }
        if($ff->{listnoselect}){
        }
        else{
            my $void="Select";
            if($ff->{void}){$void=$ff->{void};};
            push @$out, "if (!isset(\$$f) or (\$$f=='')){print \"<option value=\\\"\\\" selected>$void</option>\"; \$selected=1;}else{print \"<option value=\\\"\\\">Select</option>\";}";
        }
        push @$out, "foreach (\$$listname as \$v=>\$o){";
        push @$out, "    if(isset(\$$f) and \$v==\$$f){";
        push @$out, "        print \"<option value=\\\"\$v\\\" selected>\$o</option>\";";
        push @$out, "        \$selected=1;";
        push @$out, "    }";
        push @$out, "    else{";
        push @$out, "        print \"<option value=\\\"\$v\\\">\$o</option>\";";
        push @$out, "    }";
        push @$out, "}";
        if($ff->{other}){
            push @$out, "if (!\$selected){print \"<option value=\\\"other\\\" selected>other</option>\";}else{print \"<option value=\\\"other\\\">other</option>\";}";
        }
        push @$out, 'print "</select>";';
        if($ff->{other}){
            push @$out, "if(\$selected){";
            push @$out, '    print "<div id=\"other_'.$f.'\" style=\"display: none; margin-top: 10px;\"><div class=\"formprompt\">Please specify '.$title.':</div><input class=\"fullinput\" type=\"text\" name=\"other_'.$f.'\" value=\"$other_'.$f.'\" /></div>";';
            push @$out, "}else{";
            push @$out, '    print "<div id=\"other_'.$f.'\" style=\"display: block; margin-top: 10px;\"><div class=\"formprompt\">Please specify '.$title.':</div><input class=\"fullinput\" type=\"text\" name=\"other_'.$f.'\" value=\"$'.$f.'\" /></div>";';
            push @$out, "}";
        }
        push @$out, "}";
        push @$out, "else{";
        if($ff->{selectonly}){
            push @$out, "PRINT $prefix<input class=\"$inputclass\" type=\"text\" name=\"$f\" value=\"\$$f\" size=\"$size\"$handler disabled $input_style>$suffix";
        }
        else{
            push @$out, "PRINT $prefix<input class=\"$inputclass\" type=\"text\" name=\"$f\" value=\"i\$$f\" size=\"$size\"$handler $input_style>$suffix";
        }
        push @$out, "}";
        $isout=1;
    }
    elsif($type eq "date"){
        if(!$ff->{optional}){
            $inputdate="inputdate_us";
            $php->{$inputdate}=1;
            $php->{inputoptionlist}=1;
            push @$out, "if(empty(\$$f)){";
            push @$out, "    $inputdate(\"$f\", '');";
            push @$out, "}";
            push @$out, "else{";
            push @$out, "    $inputdate(\"$f\", \$$f);";
            push @$out, "}";
            $isout=1;
        }
    }
    elsif($type eq "fullname"){
        push @$out, "    print \"<table>\";";
        push @$out, "    print \"<tr>\";";
        push @$out, "    print \"<td>\";";
        push @$out, "    print \"<input class=\"textinput1\" type=\\\"text\\\" name=\\\"$f\_f\\\" size=\\\"10\\\" value=\\\"\$$f\_f\\\">\";";
        push @$out, "    print \"</td>\";";
        push @$out, "    print \"<td>\";";
        push @$out, "    print \"<input class=\"textinput2\" type=\\\"text\\\" name=\\\"$f\_m\\\" size=\\\"4\\\" value=\\\"\$$f\_m\\\">\";";
        push @$out, "    print \"</td>\";";
        push @$out, "    print \"<td>\";";
        push @$out, "    print \"<input class=\"textinput1\" type=\\\"text\\\" name=\\\"$f\_l\\\" size=\\\"10\\\" value=\\\"\$$f\_l\\\">\";";
        push @$out, "    print \"</td>\";";
        push @$out, "    print \"</tr>\";";
        push @$out, "    print \"<tr>\";";
        push @$out, "    print \"<td class=\\\"formhelp\\\">\";";
        push @$out, "    print \"First\";";
        push @$out, "    print \"</td>\";";
        push @$out, "    print \"<td class=\\\"formhelp\\\">\";";
        push @$out, "    print \"M.\";";
        push @$out, "    print \"</td>\";";
        push @$out, "    print \"<td class=\\\"formhelp\\\">\";";
        push @$out, "    print \"Last\";";
        push @$out, "    print \"</td>\";";
        push @$out, "    print \"</tr>\";";
        push @$out, "    print \"</table>\";";
        $isout=1;
    }
    elsif($type eq "usaddress"){
        $php->{getstatelist_short}=1;
        $php->{inputoptionlist}=1;
        push @$out, "    print \"<table><tr><td colspan=3>\";";
        push @$out, "    print \"<input class=\\\"fullinput\\\" type=\\\"text\\\" name=\\\"address\\\" size=\\\"$size\\\" value=\\\"\$address\\\">\";";
        push @$out, "    print \"</td></tr>\";";
        push @$out, "    print \"<tr><td colspan=3 class=\\\"formhelp\\\">\";";
        push @$out, "    print \"Street\";";
        push @$out, "    print \"</td></tr>\";";
        push @$out, "    print \"<tr>\";";
        push @$out, "    print \"<td>\";";
        push @$out, "    print \"<input class=\"textinput1\" type=\\\"text\\\" name=\\\"city\\\" size=\\\"15\\\" value=\\\"\$city\\\">\";";
        push @$out, "    print \"</td>\";";
        push @$out, "    print \"<td>\";";
        push @$out, "    print \"<select name=\\\"state\\\">\";";
        push @$out, "    if(!\$state){print \"<option value=\\\"\\\" selected></option>\";}";
        push @$out, "    else{print \"<option value=\\\"\\\"></option>\";}";
        push @$out, "    inputoptionlist(getstatelist_short(), \$state);";
        push @$out, "    print \"</select>\";";
        push @$out, "    print \"</td>\";";
        push @$out, "    print \"<td>\";";
        push @$out, "    print \"<input class=\\\"textinput1\\\" type=\\\"text\\\" name=\\\"zipcode\\\" size=\\\"5\\\" value=\\\"\$zipcode\\\">\";";
        push @$out, "    print \"</td>\";";
        push @$out, "    print \"</tr>\";";
        push @$out, "    print \"<tr>\";";
        push @$out, "    print \"<td class=\\\"formhelp\\\">\";";
        push @$out, "    print \"City\";";
        push @$out, "    print \"</td>\";";
        push @$out, "    print \"<td class=\\\"formhelp\\\">\";";
        push @$out, "    print \"State\";";
        push @$out, "    print \"</td>\";";
        push @$out, "    print \"<td class=\\\"formhelp\\\">\";";
        push @$out, "    print \"Zipcode\";";
        push @$out, "    print \"</td>\";";
        push @$out, "    print \"</tr>\";";
        push @$out, "    print \"</table>\";";
        $isout=1;
    }
    elsif($type eq "blob" or $type eq "text"){
        if($size=~/(\d+)x(\d+)/){
            $sizestr="cols=\\\"$1\\\" rows=\\\"$2\\\"";
        }
        push @$out, "print \"<textarea class=\\\"\$inputclass\\\" name=\\\"$f\\\" $sizestr>\$$f</textarea>\";";
        $isout=1;
    }
    elsif($type eq "imagefile" or $type eq 'file'){
        push @$out, "print \"<input class=\\\"\$inputclass\\\" name=\\\"$f\\\" type=\\\"file\\\" size=\\\"$size\\\"$handler />\";";
        $isout=1;
    }
    if(!$isout){
        my $typestr="text";
        if($type eq "password"){
            $typestr="password";
        }
        push @$out, "if(!empty(\$$f)){\$val_clause=\"value=\\\"\$$f\\\"\";}";
        push @$out, "else{\$val_clause='';}";
        push @$out, "PRINT $prefix<input class=\"$inputclass\" type=\"$typestr\" name=\"$f\" \$val_clause size=\"$size\"$handler $disabled $input_style>$suffix";
        $isout=1;
    }
    if($ff->{suffix}){
        if($ff->{suffix}=~/\$button (.*)/){
            formbutton($out, $1);
        }
        else{
            push @$out, $ff->{tail};
        }
    }
}
sub fielddisplay {
    my ($out, $f, $ff) =@_;
    my $listname=getfieldlistname($ff, $f);
    my $type=getfieldtype($ff, $f);
    if($type eq "boolean"){
        my $y="Yes";
        my $n="No";
        if($ff->{list}){
            my @l=split(/,\s*/, $ff->{list});
            $y=$l[0];
            $n=$l[1];
        }
        push @$out, "if(\$$f==1){print \"$y\";}";
        push @$out, "else{print \"$n\";}";
    }
    elsif($type eq "file"){
    }
    elsif($type eq "imagefile"){
    }
    elsif($type eq "password"){
        push @$out, "*** ***";
    }
    else{
        if($listname){
            push @$out, "if(\$$listname){";
            push @$out, "    print \$$listname\[\$$f\];";
            push @$out, "}";
            push @$out, "else{";
            push @$out, "    print \$$f;";
            push @$out, "}";
        }
        else{
            push @$out, "print \$$f;";
        }
    }
}
1;
sub custom_dump {
    my ($f, $rl)=@_;
    if($$rl=~/^\s*PHP_START/){
        push @$f, "<?php\n";
        $$rl="INDENT";
        $inphp=1;
        return 0;
    }
    elsif($$rl=~/^\s*PHP_END/){
        if($f->[-1]=~/^<\?php/){
            pop @$f;
        }
        else{
            push @$f, "?>\n";
        }
        $$rl="DEDENT";
        $inphp=0;
        return 0;
    }
    elsif($$rl=~/^\s*JS_START/){
        push @$f, "<script type=\"text/javascript\">\n";
        $$rl="INDENT";
        $injs=1;
        return 0;
    }
    elsif($$rl=~/^\s*JS_END/){
        if($f->[-1]=~/^<script type=/){
            pop @$f;
        }
        else{
            push @$f, "</script>\n";
        }
        $$rl="DEDENT";
        $injs=0;
        return 0;
    }
    elsif($$rl=~/^\s*HTML_START\s*(.*)/){
        push @$f, '<!DOCTYPE HTML PUBLIC "-//W3C/DTD HTML 4.0//EN" "http://www.w3.org/TR/html4/strict.dtd">'."\n";
        push @$f, "<html><head>\n";
        dumpmeta($f);
        dumpstyle($f, $style);
        push @$f, "</head>\n";
        push @$f, "<body $1>\n";
        return 1;
    }
    elsif($$rl=~/^\s*HTML_HEAD_START/){
        push @$f, '<!DOCTYPE HTML PUBLIC "-//W3C/DTD HTML 4.0//EN" "http://www.w3.org/TR/html4/strict.dtd">'."\n";
        push @$f, "<html><head>\n";
        return 1;
    }
    elsif($$rl=~/^\s*HTML_HEAD_STUFF/){
        dumpmeta($f);
        dumpstyle($f, $style);
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
            if($inphp){
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
sub simple_block {
    my ($pre, $post, $out)=@_;
    push @$out, "$pre";
    push @$out, "INDENT";
    push @$out, "BLOCK";
    push @$out, "DEDENT";
    push @$out, "$post";
    return "NEWBLOCK";
}
sub terminate_php {
    my $l=shift;
    if($l!~/[\{\};]\s*$/){
        $l=$l.";";
    }
    return $l;
}
sub dumpstyle {
    my ($f, $style)=@_;
    my @keys=sort keys %$style;
    if(@keys){
        print "Dumping style: $style\n";
        print "Dump hash $style\n";
        while(my ($k, $v) = each %$style){
            print "    ", "$k: $v\n";
        }
        if($MyDef::page->{type} ne "css"){
            push @$f, "<style>\n";
        }
        foreach my $k (@keys){
            my %attr;
            my @tlist=split /;/, $style->{$k};
            foreach my $t(@tlist){
                if($t=~/(\S+):\s+(.*)/){
                    $attr{$1}=$2;
                }
            }
            @tlist=();
            foreach my $a (keys(%attr)){
                push @tlist, "$a: $attr{$a}";
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
    my %sheet_hash;
    foreach my $s (@$style_sheets){
        if(!$sheet_hash{$s}){
            $sheet_hash{$s}=1;
            push @$f, "<link rel=\"stylesheet\" type=\"text/css\" href=\"$s\" />\n";
        }
    }
    my %js_hash;
    foreach my $s (@$java_scripts){
        if(!$js_hash{$s}){
            $js_hash{$s}=1;
            push @$f, "<script type=\"text/javascript\" src=\"$s\" />\n";
        }
    }
}
sub post_load_only {
    my ($out, $f)=@_;
    my $ff=$MyDef::def->{fields}->{$f};
    my $type=get_f_type($f);
    my $name=get_f_name($f);
    my $isout=0;
    if($type eq "imagefile"){
        $isout=1;
    }
    elsif($type eq 'date' and !$ff->{optional}){
        push @$out, "\$$name=\$_POST['year_$name'].'-'.\$_POST['month_$name'].'-'.\$_POST['date_$name'];";
        $isout=1;
    }
    if(!$isout){
        push @$out, "if(array_key_exists('$name', \$_POST)){";
        push @$out, "    \$$name= stripslashes (\$_POST['$name']);";
        push @$out, "}";
        if($ff->{other}){
            if(0){
            }
            else{
                push @$out, "if(\$$name=='other'){\$$name=stripslashes(\$_POST['other_$name']);}";
            }
        }
    }
}
sub post_load {
    my ($out, $f)=@_;
    post_load_only($out, $f);
    my $ff=$MyDef::def->{fields}->{$f};
    my $type=get_f_type($f);
    my $name=get_f_name($f);
    my $title=get_f_label($f);
    if(!$ff->{optional}){
        if($type eq 'boolean'){
            push @$out, "if(\$$name != '0' and \$$name != '1'){";
            push @$out, "    \$errors[]=\"Please select $title.\";";
            push @$out, "    \$error_fields['$name']=1;";
            push @$out, "}";
        }
        elsif($type eq 'image'){
            push @$out, "if(!is_uploaded_file(\$_FILES['$name']['tmp_name'])){";
            push @$out, "    \$error_fields['$name']=1;";
            push @$out, "}";
        }
        else{
            push @$out, "if(!\$$name){";
            push @$out, "    \$errors[]=\"Please enter $title.\";";
            push @$out, "    \$error_fields['$name']=1;";
            push @$out, "}";
        }
    }
    if($type eq 'date'){
        push @$out, "if(\$$name){";
            push @$out, "if(!preg_match('/\\d\\d\\/\\d\\d\\/\\d\\d\\d\\d/', \$$name)){";
            push @$out, "    \$error_fields['$name']=1;";
            push @$out, "    \$errors[]='Please enter \"$title\" in mm/dd/yyyy format.';";
            push @$out, "}";
        push @$out, "}";
    }
    if($type eq 'email'){
        push @$out, "if(\$$name){";
            push @$out, "if(!preg_match('/\\S+\@\\S+/', \$$name)){";
            push @$out, "    \$error_fields['$name']=1;";
            push @$out, "    \$errors[]='Please enter a valid E-Mail address.';";
            push @$out, "}";
        push @$out, "}";
    }
    if($type eq 'phone'){
        push @$out, "\$$name=ereg_replace('[^0-9]', '', \$$name);";
        if(!$ff->{optional}){
            push @$out, "if(!\$$name){";
                push @$out, "    \$error_fields['$name']=1;";
                push @$out, "    \$errors[]='Please enter a valid number.';";
            push @$out, "}";
        }
    }
}
sub forminit {
    my ($out, $name)=@_;
    my $form=$MyDef::def->{fieldsets}->{$name};
    my $fields=$form->{fields};
    foreach my $f (@$fields){
        push @$out, "\$$f='';";
    }
}
sub sql_exec {
    my $out=shift;
    push @$out, "\$r=mysql_query(\$sql, \$$MyDef::var->{usedb});";
    push @$out, "if(!\$r){\$errors[]='Database Error'; \$tpage=addslashes(\$_SERVER['PHP_SELF']);\$tsql=addslashes(\$sql);mysql_query(\"INSERT INTO log_errsql (errsql,page) VALUES ('\$tsql', '\$tpage)'\", \$$MyDef::var->{usedb});}";
    push @$out, "if(!\$r){\$infos[]=\"ErrSQL: \$sql\";}";
    if($MyDef::page->{'show_sql'}){ push @$out, "\$infos[]='sql: '.\$sql;"; };
}
sub sql_parse_var {
    my $t=shift;
    my ($varname, $colname);
    if($t=~/^([^(]*)\((.*)\)$/){
        $varname=$1;
        $colname=$2;
    }
    else{
        $varname=$t;
        $colname=$t;
    }
    return ($varname, $colname);
}
sub sql_update {
    my ($out, $use_cache, $head, $param, $tail)=@_;
    my @flist=split /,\s*/, $param;
    my $fields=$MyDef::def->{fields};
    my @sqlsegs;
    foreach my $f (@flist){
        if($f=~/(.*)=(.*)/){
            push @sqlsegs, $f;
        }
        else{
            my ($varname, $colname);
            if($f=~/^(.*)\((.*)\)$/){
                $varname=$1;
                $colname=$2;
            }
            else{
                $varname=$f;
                $colname=$f;
            }
            my $ff=$fields->{$varname};
            my $type=getfieldtype($ff, $colname);
            if($type =~/^(int|uint|boolean)$/){
                push @$out, "if(is_numeric(\$$varname)){";
                push @$out, "    \$t_$varname=\$$varname;";
                push @$out, "}else{";
                push @$out, "    \$t_$varname=\"NULL\";";
                push @$out, "}";
                push @sqlsegs, "$colname=\$t_$varname";
            }
            elsif($type eq 'date'){
                push @$out, "if(\$$varname){";
                push @$out, "    \$t_$varname=\"'\".\$$varname.\"'\";";
                push @$out, "}else{";
                push @$out, "    \$t_$varname=\"NULL\";";
                push @$out, "}";
                push @sqlsegs, "$colname=\$t_$varname";
            }
            elsif($type eq 'now'){
                push @sqlsegs, "$colname=NOW()";
            }
            elsif($type eq 'today' or $type eq 'curdate'){
                push @sqlsegs, "$colname=CURDATE()";
            }
            else{
                if($ff->{null_on_empty}){
                    push @$out, "if(\$$varname){";
                    push @$out, "    \$t_$varname=\"'\".addslashes(\$$varname).\"'\";";
                    push @$out, "}";
                    push @$out, "else{";
                    push @$out, "    \$t_$varname='NULL';";
                    push @$out, "}";
                    push @sqlsegs, "$colname=\$t_$varname";
                }
                else{
                    push @$out, "\$t_$varname=addslashes(\$$varname);";
                    push @sqlsegs, "$colname='\$t_$varname'";
                }
            }
        }
    }
    push @$out, "\$sql = \"$head ".join(', ', @sqlsegs)." $tail\";";
    sql_exec($out);
}
sub sql_insert {
    my ($out, $head, $param)=@_;
    my @flist=split /,\s*/, $param;
    my $fields=$MyDef::def->{fields};
    my (@sqlnames, @sqlsegs);
    foreach my $f (@flist){
        if($f=~/(.*)=(.*)/){
            push @sqlnames, $1;
            push @sqlsegs, $2;
        }
        else{
            my ($varname, $colname);
            if($f=~/^(.*)\((.*)\)$/){
                $varname=$1;
                $colname=$2;
            }
            else{
                $varname=$f;
                $colname=$f;
            }
            if($item){
                push @$out, "\$$varname=\$i['$varname'];";
            }
            my $ff=$fields->{$varname};
            my $type=getfieldtype($ff, $colname);
            push @sqlnames, $colname;
            if($type =~/^(int|uint|boolean)$/){
                push @$out, "if(is_numeric(\$$varname)){";
                push @$out, "    \$t_$varname=\$$varname;";
                push @$out, "}else{";
                push @$out, "    \$t_$varname=\"NULL\";";
                push @$out, "}";
                push @sqlsegs, "\$t_$varname";
            }
            elsif($type eq 'date'){
                push @$out, "if(\$$varname){";
                push @$out, "    \$t_$varname=\"'\".\$$varname.\"'\";";
                push @$out, "}else{";
                push @$out, "    \$t_$varname=\"NULL\";";
                push @$out, "}";
                push @sqlsegs, "\$t_$varname";
            }
            elsif($type eq 'curdate' or $type eq 'today'){
                push @sqlsegs, "CURDATE()";
            }
            elsif($type eq 'now'){
                push @sqlsegs, "NOW()";
            }
            else{
                push @$out, "\$t_$varname=addslashes(\$$varname);";
                push @sqlsegs, "'\$t_$varname'";
            }
        }
    }
    push @$out, "\$sql = \"$head (".join(', ', @sqlnames).") VALUES (".join(', ', @sqlsegs).")\";";
    sql_exec($out);
}
sub sql_select {
    my ($out, $flist, $tail)=@_;
    my @sqlnames;
    foreach my $f (@$flist){
        my ($varname, $colname)=sql_parse_var($f);
        push @sqlnames, "$colname";
    }
    push @$out, '$sql = "SELECT '.join(', ', @sqlnames). " $tail\";";
    sql_exec($out);
}
sub sql_select_one {
    my ($out, $param, $tail)=@_;
    my $fields=$MyDef::def->{fields};
    my @flist=split /,\s*/, $param;
    my @sqlnames;
    my @assignments;
    my $varname;
    my $colname;
    my $i=0;
    foreach my $f (@flist){
        my ($varname, $colname)=sql_parse_var($f);
        $ff=$fields->{$varname};
        $type=getfieldtype($ff, $colname);
        push @sqlnames, $colname;
        push @assignments, "        \$$varname=\$row[$i];";
        $i++;
    }
    push @$out, '$sql = "SELECT '.join(', ', @sqlnames). " $tail\";";
    sql_exec($out);
    push @$out, "if(\$r){\$row=mysql_fetch_row(\$r);}";
    push @$out, "if(!\$row){\$empty=1;}";
    push @$out, "else{";
    push @$out, "    \$empty=0;";
    foreach my $l (@assignments){
        push @$out, $l;
    }
    push @$out, "}";
}
sub sql_select_count {
    my ($out, $use_cache, $param, $name)=@_;
    my $countname="count";
    if($name){$countname=$name."_count";};
    push @$out, "\$sql=\"SELECT count(*) $param\";";
    if($use_cache){
        push @$out, "\$cache_sql=\"SELECT result FROM sql_cache WHERE `sql`='\".addslashes(\$sql).\"' AND timestamp>DATE_SUB(CURDATE(), INTERVAL 1 DAY)\";";
        push @$out, "\$r=mysql_query(\$cache_sql, \$$MyDef::var->{usedb});";
        if($MyDef::page->{'show_sql'}){ push @$out, "\$infos[]='sql: '.\$cache_sql;"; };
        push @$out, "if(\$r){\$row=mysql_fetch_row(\$r);}";
        push @$out, "if(\$row){";
            push @$out, "\$$countname=\$row[0];";
        push @$out, "}";
        push @$out, "else{";
    }
    sql_exec($out);
    push @$out, "if(\$r){";
    push @$out, "\$row=mysql_fetch_row(\$r);";
    push @$out, "\$$countname=\$row[0];";
    push @$out, "}";
    if($use_cache){
        push @$out, "mysql_query(\"REPLACE INTO sql_cache (`sql`, result) VALUES ('\".addslashes(\$sql).\"', '\$$countname')\", \$$MyDef::var->{usedb});";
        push @$out, "}";
    }
}
sub sql_select_list {
    my ($out, $use_cache, $param, $tail, $suffix)=@_;
    my $fields=$MyDef::def->{fields};
    my @flist=split /,\s*/, $param;
    sql_select($out, \@flist, $tail);
    push @$out, "\$itemlist$suffix=array();";
    push @$out, "while (\$row=mysql_fetch_row(\$r)){";
    push @$out, "    \$i$suffix=array();";
    my $j=0;
    foreach my $f(@flist){
        my ($varname, $colname)=sql_parse_var($f);
        $ff=$fields->{$varname};
        $type=getfieldtype($ff, $colname);
        push @$out, "    \$i$suffix\['$varname']=\$row[$j];";
        $j++;
    }
    push @$out, "    \$itemlist$suffix\[]=\$i$suffix;";
    push @$out, "}";
}
sub sql_select_array {
    my ($out, $use_cache, $param, $tail)=@_;
    my $fields=$MyDef::def->{fields};
    my @flist=split /,\s*/, $param;
    sql_select($out, \@flist, $tail);
    my ($varname, $colname)=sql_parse_var($flist[0]);
    push @$out, "\$$varname\_list=array();";
    push @$out, "while (\$row=mysql_fetch_row(\$r)){";
    push @$out, "    \$$varname\_list[]=\$row[0];";
    push @$out, "}";
}
sub sql_select_hash {
    my ($out, $use_cache, $param, $tail)=@_;
    my $fields=$MyDef::def->{fields};
    my @flist=split /,\s*/, $param;
    sql_select($out, \@flist, $tail);
    my ($varname, $colname, $single);
    if(@flist==1){
        $single=1;
        ($varname, $colname)=sql_parse_var($flist[0]);
    }
    else{
        ($varname, $colname)=sql_parse_var($flist[1]);
    }
    push @$out, "\$$varname\_list=array();";
    push @$out, "while (\$row=mysql_fetch_row(\$r)){";
    if($single){
        push @$out, "    \$$varname\_list[\$row[0]]=\$row[0];";
    }
    else{
        push @$out, "    \$$varname\_list[\$row[0]]=\$row[1];";
    }
    push @$out, "}";
}
sub sqlrun {
    my ($out, $sql, $use_cache)=@_;
    if($sql=~/(UPDATE\s+\S+\s+SET)\s+(.*?)\s+(WHERE\s.*)/i){
        sql_update($out, $use_cache, $1, $2, $3);
    }
    elsif($sql=~/((INSERT|INSERT IGNORE|REPLACE)\s+INTO\s+\S+\s+)(.*)/i){
        sql_insert($out, $1, $3);
    }
    elsif($sql=~/SELECT_COUNT(_(\w+))? (FROM\s.*)/i){
        sql_select_count($out, $use_cache, $3, $2);
    }
    elsif($sql=~/SELECT_LIST\s+(.*?)\s+(FROM\s.*)/i){
        sql_select_list($out, $use_cache, $1, $2);
    }
    elsif($sql=~/SELECT_LIST(_\w+)\s+(.*?)\s+(FROM\s.*)/i){
        sql_select_list($out, $use_cache, $2, $3, $1);
    }
    elsif($sql=~/SELECT_ARRAY\s+(.*?)\s+(FROM\s.*)/i){
        sql_select_array($out, $use_cache, $1, $2);
    }
    elsif($sql=~/SELECT_HASH\s+(.*?)\s+(FROM\s.*)/i){
        sql_select_hash($out, $use_cache, $1, $2);
    }
    elsif($sql=~/SELECT\s+(.*?)\s+(FROM\s.*)/i){
        sql_select_one($out, $1, $2);
    }
    else{
        push @$out, "\$sql=\"$sql\";";
        sql_exec($out);
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
    elsif($colname eq "date_inserted" ){
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
sub sql_createtable {
    my ($tablename)=@_;
    my $fields=$MyDef::def->{fields};
    my $table=$MyDef::def->{fieldsets}->{$tablename};
    my $flist=$table->{fields};
    my $lastf=$$flist[-1];
    my $name=$table->{name};
    if(!$name){$name=$tablename;};
    my @out;
    push @out,  "DROP TABLE IF EXISTS $name;\n";
    push @out,  "CREATE TABLE $name (\n";
    if($table->{useid}){
        push @out,  "\tid INT UNSIGNED NOT NULL AUTO_INCREMENT,\n";
        push @out,  "\tPRIMARY KEY (id),\n";
    }
    if($table->{timestamp}){
        push @out, "\ttimestamp TIMESTAMP,\n";
    }
    my $unique;
    if($table->{unique}){
        my @list=split /,\s*/, $table->{unique};
        push @out, "\tUNIQUE (".join(", ", @list)."),\n";
    }
    if($table->{fulltext}){
        push @out, "\tFULLTEXT (".$table->{fulltext}."),\n";
    }
    if($table->{key}){
        my @list=split /,\s*/, $table->{key};
        push @out, "\tPRIMARY KEY (".join(", ", @list)."),\n";
    }
    if($table->{insertdate}){
        push @out, "\tdate_inserted DATE,\n";
    }
    foreach my $f (@$flist){
        my $size=50;
        my $type;
        my $defname=$f;
        my $colname=$f;
        if($f=~/(\w+)\((\w+)\)/){
            $defname=$1;
            $colname=$2;
        }
        elsif($f=~/$name\_(\w+)/){
            $defname=$f;
            $colname=$1;
        }
        push @out,  "\t$colname ";
        my $ff=$fields->{$defname};
        $type=getfieldtype($ff, $colname);
        $size=getfieldsize($ff, $type);
        if($type eq "password"){
            push @out,  "VARCHAR($size) BINARY";
        }
        elsif($type eq "datetime"){
            push @out,  "DATETIME";
        }
        elsif($type eq "curdate"){
            push @out,  "DATE";
        }
        elsif($type eq "money"){
            push @out,  "DECIMAL(10, 2)";
        }
        elsif($type eq "uint"){
            push @out,  "INT UNSIGNED";
        }
        elsif($type){
            push @out, uc($type);
        }
        else{
            push @out,  "VARCHAR($size)";
        }
        if($ff->{notnull}){push @out, " NOT NULL";};
        if(defined $ff->{default}){
            push @out, " DEFAULT $ff->{default}";
        }
        if($f eq $lastf){
            if($unique){
                push @out, ",\n\t$unique\n);\n";
            }
            else{
                push @out,  "\n);\n";
            }
        }
        else{
            push @out,  ",\n";
        }
    }
    if($table->{initlist}){
        my @values=split /,\s*/, $table->{initlist};
        my $f=$flist->[0];
        my $ff=$fields->{$f};
        $type=getfieldtype($ff, $colname);
        $size=getfieldsize($ff, $type);
        foreach my $v (@values){
            push @out, "INSERT INTO $name ($f) VALUES (".sql_quote($type, $v).");\n";
        }
        push @out,  "\n";
    }
    elsif($table->{init}){
        my $tlist=$table->{init};
        my $insert_a="INSERT INTO $name (". join(", ", @$flist).") VALUES ";
        foreach my $init_line (@$tlist){
            my @l=split /,\s*/, $init_line;
            push @out, $insert_a."('".join("', '", @l)."');\n";
        }
    }
    return join '', @out;
}
sub sql_quote {
    my ($type, $v)=@_;
    if($type =~/int|DATE/i){
        return $v;
    }
    else{
        return "'$v'";
    }
}
sub display_list_field {
    my ($out, $f, $fields, $suffix, $csv)=@_;
    my $colname;
    if($f=~/(.*)\((.*)\)/){
        $colname=$2;
        $f=$1;
    }
    else{
        $colname=$f;
    }
    my $ff=$fields->{$f};
    my $display;
    if($csv and $ff->{text_display}){
        $display=$ff->{text_display};
    }
    elsif($ff->{display}){
        $display=$ff->{display};
    }
    if($display){
        if($display=~/function (\w+)\((.*)\)/){
            my $t0=$1;
            my $t1=$2;
            $t1=~s/\$\(colname\)/$colname/g;
            push @$out, "    $t0($t1);";
        }
        elsif($display=~/function (\w+)/){
            push @$out, "    $1(\$i$suffix);";
        }
        elsif($display=~/call\s+(.*)/){
            MyDef::compileutil::call_sub($1);
        }
        elsif($display=~/do\s+(.*)/){
            push @$out, "    $1;";
        }
        else{
            my @tt;
            $display=~s/"/\\"/g;
            while($display=~/\$\[(.*?)\]/){
                push @tt, "\"$`\"";
                push @tt, "\$i$suffix\['$1'\]";
                $display=$';
            }
            push @tt, "\"$display\"";
            push @$out, "        print ".join('.',@tt).";";
        }
    }
    elsif($ff->{type} eq "boolean" and $ff->{list}){
        @l=split /,\s*/, $ff->{list};
        push @$out, "if(\$i$suffix\['$f']){";
        push @$out, "    print \"$l[0]\";";
        push @$out, "}else{";
        push @$out, "    print \"$l[1]\";";
        push @$out, "}";
    }
    else{
        $listname=getfieldlistname($ff, $f);
        if($listname){
            push @$out, "if(!empty(\$$listname) and array_key_exists(\$i$suffix\['$f'], \$$listname)){";
            push @$out, "    print \$$listname\[\$i$suffix\['$f']];";
            push @$out, "}else{";
            push @$out, "    print \$i$suffix\['$f'];";
            push @$out, "}";
        }
        else{
            if($f=~/^\$/){
                push @$out, "        print \$i$suffix\[$f];";
            }
            else{
                push @$out, "        print \$i$suffix\['$f'];";
            }
        }
    }
    if($csv){
        push @$out, "PRINT , ";
    }
}
sub csvlist {
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
    if($full){
        foreach my $f (@$flist){
            if($f=~/(.*)\((.*)\)/){
                $colname=$2;
                $f=$1;
            }
            my $ff=$fields->{$f};
            my $title=$f;
            if($ff->{title}){$title=$ff->{title};};
            push @$out, "PRINT $title, ";
        }
        push @$out, "PRINTLN ";
    }
    push @$out, "\$j$suffix=0;";
    push @$out, "foreach(\$itemlist$suffix as \$i$suffix){";
    foreach my $f (@$flist){
        display_list_field($out, $f, $fields, $suffix, "csv");
    }
    push @$out, "PRINTLN ";
    push @$out, "    \$j$suffix++;";
    push @$out, "}";
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
                $colname=$2;
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
    push @$out, "    print \"<tr>\";";
    foreach my $f (@$flist){
        my $ff=$fields->{$f};
        my $align="center";
        if($ff->{align}){
            $align=$ff->{align};
        }
        my $width="";
        if($ff->{width}){$width=" width=\\\"$ff->{width}\\\"";};
        push @$out, "    print \"<td class=\$tdclass align=$align $width>\";";
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
sub formhead {
    my ($out, $param)=@_;
    my @p=split /,\s*/, $param;
    my $formname=shift @p;
    my $method="post";
    my $action="{\$_SERVER['PHP_SELF']}";
    my $uploadlimit=0;
    my $onsubmit;
    foreach my $n(@p){
        if($n eq 'get' or $n eq 'post'){
            $method=$n;
        }
        elsif($n=~/\//){
            $action=$n;
        }
        elsif($n=~/\.php/){
            $action=$n;
        }
        elsif($n=~/\d+/){
            $uploadlimit=$n;
        }
        elsif($n=~/\(.*\)/){
            $onsubmit=$n;
        }
    }
    if($onsubmit){
        $onsubmit="onsubmit=\"return $onsubmit\"";
    }
    if($uploadlimit){
        push @$out, "PRINT <form method=\"$method\" action=\"$action\" name=\"$formname\" enctype=\"multipart/form-data\" $onsubmit>";
        push @$out, "PRINT <input type=\"hidden\" name=\"MAX_FILE_SIZE\" value=\"$uploadlimit\" />";
    }
    else{
        push @$out, "PRINT <form method=\"$method\" action=\"$action\" name=\"$formname\" $onsubmit>";
    }
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
sub formshow {
    my ($out, $formname)=@_;
    my $fields=$MyDef::def->{fields};
    my $form=$MyDef::def->{fieldsets}->{$formname};
    my $flist=$form->{fields};
    push @$out, "PRINT <div class=\"form\">";
    if($form->{title}){
        push @$out, "print '<h1 class=\"formtitle\">".$form->{title}."</h1>';";
    }
    push @$out, 'print "<table class=\"formtable\">";';
    my $labelalign="right";
    if($form->{align}){$labelalign=$form->{align};};
    foreach my $f (@$flist){
        my $ff=$fields->{$f};
        my $title=$f;
        if($ff->{title}){$title=$ff->{title};};
        my $prefix;
        if($ff->{optional}){
            push @$out, "if(\$$f){";
        }
        push @$out, "print \"<tr><td class=\\\"labelcolumn\\\" valign=\\\"top\\\" align=\\\"$labelalign\\\">\";";
        push @$out, 'print "<label>'.$title.':</label>";';
        push @$out, 'print "</td><td class=\"formspacer\"></td>";';
        push @$out, 'print "<td valign=\"top\" align=\"left\">";';
        my $listname;
        if($ff->{listname}){
            $listname=$ff->{listname};
        }
        elsif($ff->{list}){
            $listname=$f.'_optlist';
        }
        if($ff->{type} eq "boolean"){
            my $y="Yes";
            my $n="No";
            if($ff->{list}){
                my @l=split(/,\s*/, $ff->{list});
                $y=$l[0];
                $n=$l[1];
            }
            push @$out, "if(\$$f==1){print \"$y\";}";
            push @$out, "else{print \"$n\";}";
        }
        elsif($ff->{type} eq "file"){
        }
        elsif($ff->{type} eq "imagefile"){
        }
        elsif($ff->{type} eq "password"){
            print STDERR "    Password should not be displayed.\n";
        }
        else{
            if($listname){
                push @$out, "if(\$$listname){";
                push @$out, "    print \$$listname\[\$$f\];";
                push @$out, "}";
                push @$out, "else{";
                push @$out, "    print \$$f;";
                push @$out, "}";
            }
            else{
                push @$out, "print \$$f;";
            }
        }
        push @$out, "print \"</td></tr>\";";
        if($ff->{optional}){
            push @$out, "}";
        }
    }
    push @$out, 'print "</td></tr>";';
    push @$out, 'print "</table>";';
    push @$out, "PRINT </div>";
}
sub getfieldsize {
    my ($ff, $type) =@_;
    my $size=$ff->{size};
    if(!$size){
        if($type eq "year"){
            $size=4;
        }
        elsif($type eq "date"){
            $size=10; if($ff->{optional}){$valign="valign=\"middle\"";};
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
            $size=12;$prefix='\$';
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
sub form_twocolumn {
    my ($out, $fields, $displaylist, $inputlist, $maxsize, $id)=@_;
    $tlist=$displaylist;
    my $display=1;
    my $idstr;
    if($id){
        $idstr=" id=\\\"$id\\\"";
    }
    push @$out, "print \"<table class=\\\"formtable\\\"$idstr>\";";
FLIST:
    foreach my $f (@$tlist){
        my $ff=$fields->{$f};
        my $type=getfieldtype($ff, $f);
        $label=getfieldlabel($ff, $f);
        if(!$ff->{optional} and !$display){
            $label.="*";
        }
        my $valign="valign=\\\"top\\\"";
        push @$out, "print '<tr class=\"formrow\">';";
        push @$out, "print \"<td class=\\\"labelcolumn\\\" $valign align=\\\"$labelalign\\\">\";";
        push @$out, "print \"<label>$label</label>\";";
        if($ff->{help}){
            push @$out, "print \"<div class=\\\"formhelp\\\">$ff->{help}</div>\";";
        }
        push @$out, 'print "</td><td class=\"formspacer\"></td>";';
        push @$out, "print \"<td class=\\\"inputcolumn\\\">\\n\";";
        if($display){
            fielddisplay($out, $f, $ff);
        }
        else{
            fieldinput($out, $f, $ff, $maxsize);
        }
        push @$out, 'print "\n</td></tr>\n";';
    }
    if($display){
        $display=0;
        $tlist=$inputlist;
        goto FLIST;
    }
    push @$out, "print \"</table>\";";
}
sub form_one {
    my ($out, $fields, $displaylist, $inputlist, $maxsize)=@_;
    $tlist=$displaylist;
FLIST:
    foreach my $f (@$tlist){
        my $ff=$fields->{$f};
        my $type=getfieldtype($ff, $f);
        $label=getfieldlabel($ff, $f);
        if(!$ff->{optional} and !$display){
            $label.="*";
        }
        my $valign="valign=\"top\"";
        push @$out, "PRINT <p>";
        push @$out, 'print "<label>'.$label.'</label><br />";';
        if($display){
            fielddisplay($f, $ff);
        }
        else{
            fieldinput($f, $ff, $maxsize);
        }
    }
    if($display){
        $display=0;
        $tlist=$inputlist;
        goto FLIST;
    }
    push @$out, "PRINT </p>";
}
sub formbody {
    my ($out, $formname)=@_;
    formpreloadselection($out, $formname);
    my $fields=$MyDef::def->{fields};
    my $form=$MyDef::def->{fieldsets}->{$formname};
    my $inputlist=$form->{fields};
    my @displaylist=();
    if($form->{display}){
        @displaylist=split /,\s*/, $form->{display};
    }
    if(!$form->{layout}){
        $form->{layout}="2";
    }
    push @$out, "PRINT <div class=\"form\">";
    if($form->{title}){
        push @$out, "print '<h2 class=\"formtitle\">".$form->{title}."</h2>';";
    }
    if($form->{legend}){
        push @$out, "print \" <fieldset><legend>$form->{legend}</legend>\";";
    }
    my $maxsize=20;
    if($form->{maxsize}){
        $maxsize=$form->{maxsize};
    }
    if($form->{layout} eq "2"){
        form_twocolumn($out, $fields, $displaylist, $inputlist, $maxsize);
    }
    else{
        form_one($out, $fields, $displaylist, $inputlist, $maxsize);
    }
    my $buttons=$form->{buttons};
    if($buttons){
        push @$out, "PRINT <br>";
        foreach my $b(@$buttons){
            formbutton($out, $b);
        }
    }
    if($form->{legend}){
        push @$out, "PRINT </fieldset>";
    }
    push @$out, "PRINT </div>";
}
sub forminput {
    my ($out, $param, $id)=@_;
    @inputlist=split /,\s*/, $param;
    my $fields=$MyDef::def->{fields};
    my @displaylist=();
    my $maxsize=80;
    form_twocolumn($out, $fields, [], \@inputlist, $maxsize, $id);
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
sub input {
    my ($out, $f)=@_;
    my $ff=$MyDef::def->{fields}->{$f};
    my $type=getfieldtype($ff, $f);
    fieldinput($out, $f, $ff);
}
sub get_f_type {
    my $f=shift;
    my $ff=$MyDef::def->{fields}->{$f};
    my $type;
    if($ff->{type}){
        return $ff->{type};
    }
    elsif($f=~/_id$/){
        $type="uint";
    }
    elsif($f=~/_date$/ or $f=~/^date_/){
        $type="date";
    }
    elsif($f=~/_flag$/ or $f=~/^flag_/){
        $type="boolean";
    }
    elsif($f=~/_quantity$/){
        $type="int";
    }
    elsif($f=~/^number_/){
        $type="int";
    }
    elsif($f eq "password"){
        $type="password";
    }
    elsif($f =~/phone/){
        $type="phone";
    }
    elsif($f eq 'city'){
        $type='city';
    }
    elsif($f eq 'state'){
        $type='state';
    }
    elsif($f =~ /zip(code)?/){
        $type='zip';
    }
    elsif($f =~ /email/){
        $type='email';
    }
    elsif($f =~ /city_state_zip/){
        $type='city_state_zip';
    }
    $ff->{type}=$type;
    return $type;
}
sub get_f_name {
    my $f=shift;
    my $ff=$MyDef::def->{fields}->{$f};
    if(!$ff or !$ff->{name}) {return $f;};
    return $ff->{name};
}
sub get_f_listname {
    my $f=shift;
    my $ff=$MyDef::def->{fields}->{$f};
    if($ff->{listname}){
        return $ff->{listname};
    }
    elsif($ff->{list}){
        return $f.'_optlist';
    }
    return;
}
sub get_f_label {
    my $f=shift;
    my $ff=$MyDef::def->{fields}->{$f};
    if(!$ff){return $f;};
    if($ff->{title}){return $ff->{title};};
    if($ff->{label}){return $ff->{label};};
    return $f;
}
sub get_f_display {
    my $f=shift;
    my $ff=$MyDef::def->{fields}->{$f};
    if($ff->{display}){return;};
    my $listname=getfieldlistname($ff, $f);
    my $type=getfieldtype($ff, $f);
    if($type eq "boolean"){
        my $y="Yes";
        my $n="No";
        if($ff->{list}){
            my @l=split(/,\s*/, $ff->{list});
            $y=$l[0];
            $n=$l[1];
        }
        push @$out, "if(\$$f==1){print \"$y\";}";
        push @$out, "else{print \"$n\";}";
    }
    elsif($type eq "file"){
    }
    elsif($type eq "imagefile"){
    }
    elsif($type eq "password"){
        push @$out, "*** ***";
    }
    else{
        if($listname){
            push @$out, "if(\$$listname){";
            push @$out, "    print \$$listname\[\$$f\];";
            push @$out, "}";
            push @$out, "else{";
            push @$out, "    print \$$f;";
            push @$out, "}";
        }
        else{
            push @$out, "print \$$f;";
        }
    }
}
sub fieldinput {
    my ($out, $f, $ff, $maxsize) =@_;
    my $type=getfieldtype($ff, $f);
    my $size=getfieldsize($ff, $type);
    if($maxsize and $size>$maxsize){
        $size=$maxsize;
    }
    my $handler="";
    foreach my $k(keys %$ff){
        if($k=~/^on(.*)/){
            print "handler: $f - $k\n";
            $handler=$handler." $k=\"$ff->{$k}\"";
        }
    }
    my $disabled="";
    if($ff->{disabled}){
        $disabled=" disabled";
    }
    my $listname=getfieldlistname($ff, $f);
    my $prefix=$ff->{prefix};
    my $suffix=$ff->{suffix};
    my $isout=0;
    push @$out, "\$inputclass='input_normal';";
    push @$out, "if(isset(\$error_fields) and array_key_exists('$f', \$error_fields)){\$inputclass='input_error';}";
    my $input_style;
    if(!$ff->{size} and $ff->{width}){
        $input_style=" style=\"width: $ff->{width};\"";
    }
    if($type eq "boolean"){
        my $y="Yes";
        my $n="No";
        if($ff->{list}){
            my @l=split(/,\s*/, $ff->{list});
            my $j=0;
            foreach my $tl(@l){
                if($tl=~/(.*)(=>|:)([01])/){
                    if($3 eq "0"){
                        $n=$1;
                    }
                    else{
                        $y=$1;
                    }
                }
                else{
                    if($j==0){
                        $y=$tl;
                    }
                    else{
                        $n=$tl;
                    }
                }
                $j++;
            }
        }
        push @$out, "if(!empty(\$$f)){\$t=' checked';}else{\$t='';}";
        push @$out, "PRINT $y<input type=\"radio\" name=\"$f\" value=\"1\" \$t$handler $input_style>";
        push @$out, "PRINT &nbsp;&nbsp;";
        push @$out, "if(empty(\$$f)){\$t=' checked';}else{\$t='';}";
        push @$out, "PRINT $n<input type=\"radio\" name=\"$f\" value=\"0\" \$t$handler $input_style>";
        $isout=1;
    }
    elsif($type eq "checkbox"){
        push @$out, "if(!empty(\$$f)){\$t=' checked';}else{\$t='';}";
        push @$out, "PRINT <input type=\"checkbox\" name=\"$f\" \$t$handler $input_style>";
        push @$out, "PRINT &nbsp;&nbsp;";
        $isout=1;
    }
    elsif($listname){
        push @$out, "if (\$$listname){";
        my $sizestr;
        my $name=$f;
        if($ff->{size}=~/(\d+)/){
            $sizestr="size=$1";
        }
        if($ff->{multiple}){
            $sizestr.=" multiple=\"yes\"";
            $name.="[]";
        }
        if($ff->{other}){
            push @$out, "PRINT <select class=\"\$inputclass\" name=\"$name\" onchange=\"selectother_$f(this);\" $sizestr $input_style>";
            push @$out, '$selected=0;';
        }
        else{
            push @$out, "PRINT <select class=\"\$inputclass\" name=\"$name\" $handler $sizestr $input_style>";
        }
        if($ff->{listnoselect}){
        }
        else{
            my $void="Select";
            if($ff->{void}){$void=$ff->{void};};
            push @$out, "if (!isset(\$$f) or (\$$f=='')){print \"<option value=\\\"\\\" selected>$void</option>\"; \$selected=1;}else{print \"<option value=\\\"\\\">Select</option>\";}";
        }
        push @$out, "foreach (\$$listname as \$v=>\$o){";
        push @$out, "    if(isset(\$$f) and \$v==\$$f){";
        push @$out, "        print \"<option value=\\\"\$v\\\" selected>\$o</option>\";";
        push @$out, "        \$selected=1;";
        push @$out, "    }";
        push @$out, "    else{";
        push @$out, "        print \"<option value=\\\"\$v\\\">\$o</option>\";";
        push @$out, "    }";
        push @$out, "}";
        if($ff->{other}){
            push @$out, "if (!\$selected){print \"<option value=\\\"other\\\" selected>other</option>\";}else{print \"<option value=\\\"other\\\">other</option>\";}";
        }
        push @$out, 'print "</select>";';
        if($ff->{other}){
            push @$out, "if(\$selected){";
            push @$out, '    print "<div id=\"other_'.$f.'\" style=\"display: none; margin-top: 10px;\"><div class=\"formprompt\">Please specify '.$title.':</div><input class=\"fullinput\" type=\"text\" name=\"other_'.$f.'\" value=\"$other_'.$f.'\" /></div>";';
            push @$out, "}else{";
            push @$out, '    print "<div id=\"other_'.$f.'\" style=\"display: block; margin-top: 10px;\"><div class=\"formprompt\">Please specify '.$title.':</div><input class=\"fullinput\" type=\"text\" name=\"other_'.$f.'\" value=\"$'.$f.'\" /></div>";';
            push @$out, "}";
        }
        push @$out, "}";
        push @$out, "else{";
        if($ff->{selectonly}){
            push @$out, "PRINT $prefix<input class=\"$inputclass\" type=\"text\" name=\"$f\" value=\"\$$f\" size=\"$size\"$handler disabled $input_style>$suffix";
        }
        else{
            push @$out, "PRINT $prefix<input class=\"$inputclass\" type=\"text\" name=\"$f\" value=\"i\$$f\" size=\"$size\"$handler $input_style>$suffix";
        }
        push @$out, "}";
        $isout=1;
    }
    elsif($type eq "date"){
        if(!$ff->{optional}){
            $inputdate="inputdate_us";
            $php->{$inputdate}=1;
            $php->{inputoptionlist}=1;
            push @$out, "if(empty(\$$f)){";
            push @$out, "    $inputdate(\"$f\", '');";
            push @$out, "}";
            push @$out, "else{";
            push @$out, "    $inputdate(\"$f\", \$$f);";
            push @$out, "}";
            $isout=1;
        }
    }
    elsif($type eq "fullname"){
        push @$out, "    print \"<table>\";";
        push @$out, "    print \"<tr>\";";
        push @$out, "    print \"<td>\";";
        push @$out, "    print \"<input class=\"textinput1\" type=\\\"text\\\" name=\\\"$f\_f\\\" size=\\\"10\\\" value=\\\"\$$f\_f\\\">\";";
        push @$out, "    print \"</td>\";";
        push @$out, "    print \"<td>\";";
        push @$out, "    print \"<input class=\"textinput2\" type=\\\"text\\\" name=\\\"$f\_m\\\" size=\\\"4\\\" value=\\\"\$$f\_m\\\">\";";
        push @$out, "    print \"</td>\";";
        push @$out, "    print \"<td>\";";
        push @$out, "    print \"<input class=\"textinput1\" type=\\\"text\\\" name=\\\"$f\_l\\\" size=\\\"10\\\" value=\\\"\$$f\_l\\\">\";";
        push @$out, "    print \"</td>\";";
        push @$out, "    print \"</tr>\";";
        push @$out, "    print \"<tr>\";";
        push @$out, "    print \"<td class=\\\"formhelp\\\">\";";
        push @$out, "    print \"First\";";
        push @$out, "    print \"</td>\";";
        push @$out, "    print \"<td class=\\\"formhelp\\\">\";";
        push @$out, "    print \"M.\";";
        push @$out, "    print \"</td>\";";
        push @$out, "    print \"<td class=\\\"formhelp\\\">\";";
        push @$out, "    print \"Last\";";
        push @$out, "    print \"</td>\";";
        push @$out, "    print \"</tr>\";";
        push @$out, "    print \"</table>\";";
        $isout=1;
    }
    elsif($type eq "usaddress"){
        $php->{getstatelist_short}=1;
        $php->{inputoptionlist}=1;
        push @$out, "    print \"<table><tr><td colspan=3>\";";
        push @$out, "    print \"<input class=\\\"fullinput\\\" type=\\\"text\\\" name=\\\"address\\\" size=\\\"$size\\\" value=\\\"\$address\\\">\";";
        push @$out, "    print \"</td></tr>\";";
        push @$out, "    print \"<tr><td colspan=3 class=\\\"formhelp\\\">\";";
        push @$out, "    print \"Street\";";
        push @$out, "    print \"</td></tr>\";";
        push @$out, "    print \"<tr>\";";
        push @$out, "    print \"<td>\";";
        push @$out, "    print \"<input class=\"textinput1\" type=\\\"text\\\" name=\\\"city\\\" size=\\\"15\\\" value=\\\"\$city\\\">\";";
        push @$out, "    print \"</td>\";";
        push @$out, "    print \"<td>\";";
        push @$out, "    print \"<select name=\\\"state\\\">\";";
        push @$out, "    if(!\$state){print \"<option value=\\\"\\\" selected></option>\";}";
        push @$out, "    else{print \"<option value=\\\"\\\"></option>\";}";
        push @$out, "    inputoptionlist(getstatelist_short(), \$state);";
        push @$out, "    print \"</select>\";";
        push @$out, "    print \"</td>\";";
        push @$out, "    print \"<td>\";";
        push @$out, "    print \"<input class=\\\"textinput1\\\" type=\\\"text\\\" name=\\\"zipcode\\\" size=\\\"5\\\" value=\\\"\$zipcode\\\">\";";
        push @$out, "    print \"</td>\";";
        push @$out, "    print \"</tr>\";";
        push @$out, "    print \"<tr>\";";
        push @$out, "    print \"<td class=\\\"formhelp\\\">\";";
        push @$out, "    print \"City\";";
        push @$out, "    print \"</td>\";";
        push @$out, "    print \"<td class=\\\"formhelp\\\">\";";
        push @$out, "    print \"State\";";
        push @$out, "    print \"</td>\";";
        push @$out, "    print \"<td class=\\\"formhelp\\\">\";";
        push @$out, "    print \"Zipcode\";";
        push @$out, "    print \"</td>\";";
        push @$out, "    print \"</tr>\";";
        push @$out, "    print \"</table>\";";
        $isout=1;
    }
    elsif($type eq "blob" or $type eq "text"){
        if($size=~/(\d+)x(\d+)/){
            $sizestr="cols=\\\"$1\\\" rows=\\\"$2\\\"";
        }
        push @$out, "print \"<textarea class=\\\"\$inputclass\\\" name=\\\"$f\\\" $sizestr>\$$f</textarea>\";";
        $isout=1;
    }
    elsif($type eq "imagefile" or $type eq 'file'){
        push @$out, "print \"<input class=\\\"\$inputclass\\\" name=\\\"$f\\\" type=\\\"file\\\" size=\\\"$size\\\"$handler />\";";
        $isout=1;
    }
    if(!$isout){
        my $typestr="text";
        if($type eq "password"){
            $typestr="password";
        }
        push @$out, "if(!empty(\$$f)){\$val_clause=\"value=\\\"\$$f\\\"\";}";
        push @$out, "else{\$val_clause='';}";
        push @$out, "PRINT $prefix<input class=\"$inputclass\" type=\"$typestr\" name=\"$f\" \$val_clause size=\"$size\"$handler $disabled $input_style>$suffix";
        $isout=1;
    }
    if($ff->{suffix}){
        if($ff->{suffix}=~/\$button (.*)/){
            formbutton($out, $1);
        }
        else{
            push @$out, $ff->{tail};
        }
    }
}
sub fielddisplay {
    my ($out, $f, $ff) =@_;
    my $listname=getfieldlistname($ff, $f);
    my $type=getfieldtype($ff, $f);
    if($type eq "boolean"){
        my $y="Yes";
        my $n="No";
        if($ff->{list}){
            my @l=split(/,\s*/, $ff->{list});
            $y=$l[0];
            $n=$l[1];
        }
        push @$out, "if(\$$f==1){print \"$y\";}";
        push @$out, "else{print \"$n\";}";
    }
    elsif($type eq "file"){
    }
    elsif($type eq "imagefile"){
    }
    elsif($type eq "password"){
        push @$out, "*** ***";
    }
    else{
        if($listname){
            push @$out, "if(\$$listname){";
            push @$out, "    print \$$listname\[\$$f\];";
            push @$out, "}";
            push @$out, "else{";
            push @$out, "    print \$$f;";
            push @$out, "}";
        }
        else{
            push @$out, "print \$$f;";
        }
    }
}
