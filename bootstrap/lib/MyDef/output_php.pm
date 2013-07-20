use strict;
package MyDef::output_php;
use MyDef::compileutil;
use Term::ANSIColor qw(:constants);
my $php;
my @style_key_list;
my $style;
my $style_sheets;
my $cur_mode;
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
    if($page->{type}){
        $ext=$page->{type};
    }
    $php={};
    $style={};
    @style_key_list=();
    $style_sheets=[];
    $page->{pageext}=$ext;
    return ($ext, "html");
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
        if($func=~/^(img)$/){
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
        if($func eq 'include'){
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
        elsif($func eq 'input'){
            field_input($param);
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
    my $f;
    ($f, $out)=@_;
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
sub field_label {
    my ($f)=@_;
    my $ff=$MyDef::def->{fields}->{$f};
    my $title=ucfirst($f);
    if($ff->{label}){
        $title=$ff->{label};
    }
    elsif($ff->{title}){
        $title=$ff->{title};
    }
    push @$out, "print \"$title\";";
}
sub field_input {
    my ($f)=@_;
    my $ff=$MyDef::def->{fields}->{$f};
    my $type=getfieldtype($ff, $f);
    my $size=getfieldsize($ff, $type);
    my $disabled="";
    if($ff->{disabled}){
        $disabled=" disabled";
    }
    my $listname=getfieldlistname($ff, $f);
    my $prefix=$ff->{prefix};
    my $suffix=$ff->{suffix};
    my $isout=0;
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
        }
    }
    elsif($type eq "blob" or $type eq "text"){
        push @$out, "PRINT <textarea class=\"input\" name=\"$f\" id=\"input-$f\">\$$f</textarea>";
    }
    else{
        my $typestr="text";
        if($type eq "password"){
            $typestr="password";
        }
        push @$out, "if(!empty(\$$f)){\$val_clause=\"value=\\\"\$$f\\\"\";}";
        push @$out, "else{\$val_clause='';}";
        push @$out, "PRINT $prefix<input type=\"$typestr\" name=\"$f\" id=\"input-$f\" class=\"input\" \$val_clause $disabled >$suffix";
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
sub field_label {
    my ($f)=@_;
    my $ff=$MyDef::def->{fields}->{$f};
    my $title=ucfirst($f);
    if($ff->{label}){
        $title=$ff->{label};
    }
    elsif($ff->{title}){
        $title=$ff->{title};
    }
    push @$out, "print \"$title\";";
}
sub field_input {
    my ($f)=@_;
    my $ff=$MyDef::def->{fields}->{$f};
    my $type=getfieldtype($ff, $f);
    my $size=getfieldsize($ff, $type);
    my $disabled="";
    if($ff->{disabled}){
        $disabled=" disabled";
    }
    my $listname=getfieldlistname($ff, $f);
    my $prefix=$ff->{prefix};
    my $suffix=$ff->{suffix};
    my $isout=0;
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
        }
    }
    elsif($type eq "blob" or $type eq "text"){
        push @$out, "PRINT <textarea class=\"input\" name=\"$f\" id=\"input-$f\">\$$f</textarea>";
    }
    else{
        my $typestr="text";
        if($type eq "password"){
            $typestr="password";
        }
        push @$out, "if(!empty(\$$f)){\$val_clause=\"value=\\\"\$$f\\\"\";}";
        push @$out, "else{\$val_clause='';}";
        push @$out, "PRINT $prefix<input type=\"$typestr\" name=\"$f\" id=\"input-$f\" class=\"input\" \$val_clause $disabled >$suffix";
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
