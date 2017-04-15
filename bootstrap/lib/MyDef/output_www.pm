use strict;
package MyDef::output_www;
our $debug=0;
our $out;
our $mode;
our $page;
our $style;
our @style_key_list;
our $style_sheets;
our @mode_stack;
our $cur_mode="html";
our %plugin_statement;
our %plugin_condition;
our $time_start = time();

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

use Term::ANSIColor qw(:constants);
sub get_interface {
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout);
}
sub init_page {
    my ($t_page)=@_;
    $page=$t_page;
    MyDef::set_page_extension("html");
    my $init_mode="html";
    $style={};
    @style_key_list=();
    $style_sheets=[];
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
    if($cur_mode eq "php"){
        push @$out, "?>\n";
        MyDef::compileutil::pop_interface();
        $cur_mode=pop @mode_stack;
        if($mode eq $cur_mode){
            goto modeswitch_done;
        }
    }
    if($mode eq "php"){
        MyDef::compileutil::push_interface("php");
        push @$out, "<?php\n";
        push @mode_stack, $cur_mode;
        $cur_mode=$mode;
        goto modeswitch_done;
    }
    if($cur_mode eq "js"){
        push @$out, "<\/script>\n";
        MyDef::compileutil::pop_interface();
        $cur_mode=pop @mode_stack;
        if($mode eq $cur_mode){
            goto modeswitch_done;
        }
    }
    if($mode eq "js"){
        MyDef::compileutil::push_interface("js");
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
    if(0){
    }
    elsif($l=~/^CSS:\s*(.*)/){
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
                    push @$out, "<$func$attr>";
                }
                elsif(defined $quick_content){
                    push @$out, "<$func$attr>$quick_content</$func>";
                }
                elsif($func eq "pre"){
                    my @src;
                    push @src, "<$func$attr>";
                    push @src, "PUSHDENT";
                    push @src, "BLOCK";
                    push @src, "POPDENT";
                    push @src, "</$func>";
                    MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                    return "NEWBLOCK-pre";
                }
                else{
                    my @src;
                    push @src, "<$func$attr>";
                    push @src, "INDENT";
                    push @src, "BLOCK";
                    push @src, "DEDENT";
                    push @src, "</$func>";
                    MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                    return "NEWBLOCK-tag";
                }
                return 0;
            }
            if($func eq "script"){
                MyDef::compileutil::modepush("js");
                my @src;
                push @src, "INDENT";
                push @src, "BLOCK";
                push @src, "DEDENT";
                push @src, "PARSE:MODEPOP";
                MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                return "NEWBLOCK-script";
            }
            elsif($func=~/^(title|charset)/){
                $page->{$1}=$2;
                return;
            }
            elsif($func eq "include"){
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
    if($page->{type} eq "php"){
        $l=~s/(\$\w+)/<?php echo $1 ?>/g;
    }
    push @$out, $l;
}
sub dumpout {
    my ($f, $out, $pagetype)=@_;
    my $dump={out=>$out,f=>$f, module=>"output_www"};
    if($MyDef::page->{type} && $MyDef::page->{type} eq "css"){
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
