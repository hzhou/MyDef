use strict;
package MyDef::output_tcl;

our $debug=0;
our $out;
our $mode;
our $page;
our $tk={};
our $tk_top_index;
our $case_if="if";
our $case_elif="elseif";
our @case_stack;
our $case_state;
our %plugin_statement;
our %plugin_condition;

sub get_interface {
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout);
}

sub init_page {
    my ($t_page)=@_;
    $page=$t_page;
    MyDef::set_page_extension("tcl");
    my $init_mode="sub";
    $tk_top_index=0;
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

    if($debug eq "case"){
        my $level=@case_stack;
        print "        $level:[$case_state]$l\n";
    }

    if($l=~/^\x24(if|elif|elsif|elseif|case)\s+(.*)$/){
        my $cond=$2;
        my $case=$case_if;
        if($1 eq "if"){
        }
        elsif($1 eq "case"){
            if(!$case_state){
                $case=$case_if;
            }
            else{
                $case=$case_elif;
            }
        }
        else{
            $case=$case_elif;
        }
        $cond=parse_condition($cond);
        my @src;
        if($case eq $case_if){
            push @src, "$case {$cond} {";
            push @src, "INDENT";
            push @src, "BLOCK";
            push @src, "DEDENT";
            push @src, "}";
        }
        else{
            if($out->[-1] ne "}"){
                my $curfile=MyDef::compileutil::curfile_curline();
                print "[$curfile]\x1b[33m case: else missing } - [$out->[-1]]\n\x1b[0m";
            }
            pop @$out;
            push @src, "} $case {$cond} {";
            push @src, "INDENT";
            push @src, "BLOCK";
            push @src, "DEDENT";
            push @src, "}";
        }
        push @src, "PARSE:CASEPOP";
        push @case_stack, {state=>"if"};

        undef $case_state;
        if($debug eq "case"){
            my $level=@case_stack;
            print "Entering case [$level]: $l\n";
        }
        MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
        return "NEWBLOCK-if";
    }
    elsif($l=~/^\$else/){
        if(!$case_state and $l!~/NoWarn/i){
            my $curfile=MyDef::compileutil::curfile_curline();
            print "[$curfile]\x1b[33m Dangling \$else\n\x1b[0m";
        }
        my @src;
        if($out->[-1] ne "}"){
            my $curfile=MyDef::compileutil::curfile_curline();
            print "[$curfile]\x1b[33m case: else missing } - [$out->[-1]]\n\x1b[0m";
        }
        pop @$out;
        push @src, "} else {";
        push @src, "INDENT";
        push @src, "BLOCK";
        push @src, "DEDENT";
        push @src, "}";
        push @src, "PARSE:CASEPOP";
        push @case_stack, {state=>undef};

        undef $case_state;
        if($debug eq "case"){
            my $level=@case_stack;
            print "Entering case [$level]: $l\n";
        }
        MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
        return "NEWBLOCK-else";
    }
    elsif($l!~/^SUBBLOCK/){
        undef $case_state;
        if($l eq "CASEPOP"){
            if($debug eq "case"){
                my $level=@case_stack;
                print "    Exit case [$level]\n";
            }
            my $t_case=pop @case_stack;
            if($t_case){
                $case_state=$t_case->{state};
            }
            return 0;
        }
    }

    if($l=~/^DUMP_STUB\s/){
        push @$out, $l;
    }
    elsif($l=~/^NOOP POST_MAIN/){
        push @$out, "NEWLINE";
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
                my $params = $code->{params};
                if(!$params){
                    $params=[];
                }
                push @$out, "proc $name {@$params} {";
                push @$out, "INDENT";
                $code->{scope}="list_sub";
                MyDef::compileutil::list_sub($code);
                push @$out, "DEDENT";
                push @$out, "}";
                push @$out, "NEWLINE";
            }
        }
        return;
    }
    elsif($l=~/^CALLBACK\s+(\w+)\s*(.*)/){
        my ($func, $param)=($1, $2);
        my $codelist = $MyDef::compileutil::named_blocks{"last_grab"};

        $tk->{_list}=[];
        $tk->{_config}=[];
        if($func eq "grid"){
            tk_grid($codelist, $param);
        }
        elsif($func eq "pack"){
            tk_pack($codelist, $param);
        }
        elsif($func eq "place"){
            tk_place($codelist, $param);
        }
        my $macros = $MyDef::def->{macros};
        push @$out, "NEWLINE";
        foreach my $o (@{$tk->{_list}}){
            my $t;
            foreach my $k (sort keys %$o){
                if($k=~/^_/){
                    next;
                }
                else{
                    $t.=" -$k $o->{$k}";
                }
            }
            if($o->{_scroll}){
                my $id = $o->{_id};
                my $xy = $o->{_scroll};
                $o->{_id}="$id.t0";
                my $h = $o->{_type};
                if($o->{_type} =~/(entry|label|button)/){
                    $h = "ttk::$1";
                }
                $t = "$h $o->{_id} $t";
                my ($tx, $ty);
                if($xy=~/x/){
                    $tx = "scrollbar $id.tx -orient horizontal -command {$id.t0 xview}";
                    $t .= " -xscrollcommand {$id.tx set}";
                }
                if($xy=~/y/){
                    $ty = "scrollbar $id.ty -orient vertical -command {$id.t0 yview}";
                    $t .= " -yscrollcommand {$id.ty set}";
                }

                push @$out, "frame $id";
                push @$out, "grid [$t] -row 0 -column 0 -sticky nsew";
                if($ty){
                    push @$out, "grid [$ty] -row 0 -column 1 -sticky ns";
                }
                if($tx){
                    push @$out, "grid [$tx] -row 1 -column 0 -sticky ew";
                }
                push @$out, "grid columnconfigure $id 0 -weight 1";
                push @$out, "grid rowconfigure $id 0 -weight 1";
                $t = $id;
            }
            else{
                my $h = $o->{_type};
                if($o->{_type} =~/(entry|label|button)/){
                    $h = "ttk::$1";
                }
                $t = "$h $o->{_id} $t";
                $t = "[$t]";
            }
            if($o->{_name}){
                $macros->{"id_$o->{_name}"} = $o->{_id};
            }
            my $l;
            if($o->{_place}){
                $l = "place $t $o->{_place}";
            }
            elsif($o->{_grid}){
                $l = "grid $t $o->{_grid}";
            }
            elsif($o->{_pack}){
                $l = "pack $t $o->{_pack}";
            }
            else{
                $l = $t;
            }
            push @$out, $l;
        }
        push @$out, "NEWLINE";
        foreach my $l (@{$tk->{_config}}){
            push @$out, $l;
        }
        push @$out, "NEWLINE";

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
            if($func eq "plugin"){
                foreach my $p (split /,\s*/, $param){
                    if($p=~/^&(.+)/){
                        if($p=~/_condition$/){
                            $plugin_condition{$1}=$p;
                        }
                        else{
                            $plugin_statement{$1}=$p;
                        }
                    }
                    else{
                        if($p=~/_condition$/){
                            $plugin_condition{$p}=$p;
                        }
                        else{
                            $plugin_statement{$p}=$p;
                        }
                    }
                }
                return;
            }
            elsif($plugin_statement{$func}){
                my $c= $plugin_statement{$func};
                if($c=~/^&(.+)/){
                    return "PARSE:\&call $1, $param";
                }
                else{
                    MyDef::compileutil::call_sub("$c, $param");
                }
                return;
            }
            elsif($func eq "print"){
                push @$out, "puts \"$param\"";
                return;
            }
            elsif($func eq "while"){
                if($param=~/^\/(.*)\/g\s*->\s*(.*)/){
                    my ($re, $tail) = ($1, $2);
                    return single_block("foreach {$tail} [regexp -inline -all -- {$re} \$_] {", "}", "while");
                }
                return single_block("while {$param} {", "}", "while");
            }
            elsif($func eq "for"){
                if($param=~/(.*);(.*);(.*)/){
                    my @src;
                    push @src, "for $param {";
                    push @src, "INDENT";
                    push @src, "BLOCK";
                    push @src, "DEDENT";
                    push @src, "}";
                    MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                    return "NEWBLOCK-for";
                }
                my $var;
                if($param=~/^(.+?)\s*=\s*(.*)/){
                    $var=$1;
                    $param=$2;
                }
                my ($i0, $i1, $step);
                if($param=~/^(.+?)\s+to\s+(.+)/){
                    my $to;
                    ($i0, $to, $step) = ($1, $2, 1);
                    if($to=~/(.+?)\s+step\s+(.+)/){
                        ($to, $step)=($1, $2);
                    }
                    $i1=" <= $to";
                }
                elsif($param=~/^(.+?)\s+downto\s+(.+)/){
                    my $to;
                    ($i0, $to, $step) = ($1, $2, 1);
                    if($to=~/(.+?)\s+step\s+(.+)/){
                        ($to, $step)=($1, $2);
                    }
                    $i1=" >= $to";
                    if($step!~/^-/){
                        $step="-$step";
                    }
                }
                else{
                    my @tlist=split /:/, $param;
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
                }
                if(defined $i0){
                    if($step eq "1"){
                        $step = "incr $var";
                    }
                    elsif($step eq "-1"){
                        $step = "decr $var";
                    }
                    elsif($step=~/^-/){
                        $step = "set $var [expr \$$var $step]";
                    }
                    else{
                        $step = "set $var [expr \$$var+$step]";
                    }
                    $param = "{set $var $i0} {\$$var $i1} {$step}";
                    my @src;
                    push @src, "for $param {";
                    push @src, "INDENT";
                    push @src, "BLOCK";
                    push @src, "DEDENT";
                    push @src, "}";
                    MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                    return "NEWBLOCK-for";
                }
            }
            elsif($func eq "foreach"){
                if($param =~/(.+?)\s+in\s*(.+)/){
                    return single_block("foreach {$1} $2 {", "}", "foreach");
                }
                else{
                    return single_block("foreach $param {", "}", "foreach");
                }
            }
            elsif($func eq "proc"){
                if($param=~/^\/(.*)\/g\s*->\s*(.*)/){
                    my ($re, $tail) = ($1, $2);
                    return single_block("foreach {$tail} [regexp -inline -all -- {$re} \$_] {", "}", "while");
                }
                return single_block("proc $param {", "}", "proc");
            }
            elsif($func =~/^(grid|pack|place)$/){
                return "CALLBACK $1 $param";
            }
        }
    }
    elsif($l=~/^CALLBACK\s+(\w+)\s*(.*)/){
        my ($func, $param)=($1, $2);
        my $codelist=$MyDef::compileutil::named_blocks{"last_grab"};
        return;
    }


    push @$out, $l;
}

sub dumpout {
    my ($f, $out)=@_;
    my $dump={out=>$out,f=>$f};
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

# ---- subroutines --------------------------------------------
sub parse_condition {
    my ($t) = @_;
    if($t=~/^\/(.*)\//){
        my $re = $1;
        my $tail = $';
        if($tail =~/->\s*(.*)/){
            $t="[regexp {$re} \$_ $1]";
        }
        else{
            $t="[regexp {$re} \$_]";
        }
    }
    return $t;
}

sub tk_grid {
    my ($codelist, $param) = @_;
    my $_l = $tk->{_list};
    my ($prefix, $root);
    if($param){
        $prefix = $param;
    }
    $root = $prefix;
    if(!$root){
        $root = ".";
    }
    my (@sticky, $pad);
    my $r=0;
    my $_i = -1;
    my $_n = @$codelist;
    while($_i <$_n-1){
        $_i++;
        my $l = $codelist->[$_i];
        if($l=~/^SOURCE/){
            next;
        }
        if($l=~/^sticky:\s*(.+)/){
            @sticky = split /,\s*/, $1;
            next;
        }
        elsif($l=~/^pad:\s*(.+)/){
            my @t = split /\s+/, $1;
            if(@t==2){
                $pad = "-padx $t[0] -pady $t[1]";
            }
            elsif(@t==1){
                $pad = "-padx $t[0] -pady $t[0]";
            }
            next;
        }
        elsif($l=~/^weight:\s*(.*)/){
            my $_c = $tk->{_config};
            my @t = split /\s+/, $1;
            my $type = "columnconfigure";
            my $i=0;
            foreach my $t (@t){
                if($t eq "x"){
                    $type = "rowconfigure";
                    $i = 0;
                }
                else{
                    if($t ne "-"){
                        push @$_c, "grid $type $root $i -weight $t";
                    }
                    $i++;
                }
            }
            next;
        }
        elsif($l=~/^SOURCE/){
            next;
        }
        my @t = split /,\s+/, $l;
        my $_i = -1;
        foreach my $t (@t){
            $_i++;
            my $id="$prefix.g$r$_i";
            my $grid = "-row $r -column $_i";
            if(@sticky){
                $grid.= " -sticky $sticky[$_i]";
            }
            if($pad){
                $grid.= " $pad";
            }
            if($t=~/^-\s*$/){
            }
            if($t=~/^(\S+)\s+(.+)/){
                my ($type, $t)=($1,$2);
                my $grab;
                if($type=~/^\$?(grid|pack|place)$/){
                    $grab = $1;
                    $type = "frame";
                }

                my $o = {"_type"=>$type, "_id"=>$id, "_grid"=>$grid};
                push @$_l, $o;
                if($o and $t){
                    while(1){
                        if($t=~/\G$/sgc){
                            last;
                        }
                        elsif($t=~/\G-(\w+)\s+("(?:[^"\\]|\\.)*"|\S+)/sgc){
                            my ($w, $v)=($1,$2);
                            if($w=~/^(name|scroll)/){
                                $o->{"_$1"} = $v;
                            }
                            elsif($w=~/^(sticky|pad[xy]|expand|fill)/){
                                $o->{"_grid"} .= " -$w $v";
                            }
                            else{
                                $o->{$w}=$v;
                            }
                        }
                        elsif($t=~/\G("(?:[^"\\]|\\.)*")/sgc){
                            $o->{text}=$1;
                        }
                        elsif($t=~/\G[,\s]+/sgc){
                            next;
                        }
                        else{
                            die "parse_loop: nothing matches! [$t]\n";
                        }
                    }
                }

                if($grab){
                    my @grab_list;
                    if($codelist->[$_i+1] =~/^SOURCE_INDENT/){
                        $_i = $_i+2;
                        my $grab_indent = 1;
                        while($_i<$_n){
                            my $l = $codelist->[$_i];
                            push @grab_list, $l;
                            if($l=~/^SOURCE_INDENT/){
                                $grab_indent++;
                            }
                            elsif($l=~/^SOURCE_DEDENT/){
                                $grab_indent--;
                                if($grab_indent==0){
                                    pop @grab_list;
                                    last;
                                }
                            }
                            $_i++;
                        }
                    }
                    else{


                    }
                    if($grab eq "grid"){
                        tk_grid(\@grab_list, $id);
                    }
                    elsif($grab eq "pack"){
                        tk_pack(\@grab_list, $id);
                    }
                    elsif($grab eq "place"){
                        tk_place(\@grab_list, $id);
                    }
                }
            }
        }
        $r++;
    }
}

sub tk_pack {
    my ($codelist, $param) = @_;
    my $_l = $tk->{_list};
    my ($prefix, $root);
    if($param){
        $prefix = $param;
    }
    $root = $prefix;
    if(!$root){
        $root = ".";
    }
    my $idx=0;
    my $_i = -1;
    my $_n = @$codelist;
    while($_i <$_n-1){
        $_i++;
        my $l = $codelist->[$_i];
        if($l=~/^SOURCE/){
            next;
        }
        my $pack="-side top";
        if($l=~/^\s*(top|bottom|left|right):\s+(.*)/){
            $pack = "-side $1";
            $l =$2;
        }
        my @t = split /,\s+/, $l;
        foreach my $t (@t){
            my $id="$prefix.p$idx";
            $idx++;
            if($t=~/^(\S+)\s+(.+)/){
                my ($type, $t)=($1,$2);
                my $grab;
                if($type=~/^\$?(grid|pack|place)$/){
                    $grab = $1;
                    $type = "frame";
                }

                my $o = {"_type"=>$type, "_id"=>$id, "_pack"=>$pack};
                push @$_l, $o;
                if($o and $t){
                    while(1){
                        if($t=~/\G$/sgc){
                            last;
                        }
                        elsif($t=~/\G-(\w+)\s+("(?:[^"\\]|\\.)*"|\S+)/sgc){
                            my ($w, $v)=($1,$2);
                            if($w=~/^(name|scroll)/){
                                $o->{"_$1"} = $v;
                            }
                            elsif($w=~/^(sticky|pad[xy]|expand|fill)/){
                                $o->{"_pack"} .= " -$w $v";
                            }
                            else{
                                $o->{$w}=$v;
                            }
                        }
                        elsif($t=~/\G("(?:[^"\\]|\\.)*")/sgc){
                            $o->{text}=$1;
                        }
                        elsif($t=~/\G[,\s]+/sgc){
                            next;
                        }
                        else{
                            die "parse_loop: nothing matches! [$t]\n";
                        }
                    }
                }

                if($grab){
                    my @grab_list;
                    if($codelist->[$_i+1] =~/^SOURCE_INDENT/){
                        $_i = $_i+2;
                        my $grab_indent = 1;
                        while($_i<$_n){
                            my $l = $codelist->[$_i];
                            push @grab_list, $l;
                            if($l=~/^SOURCE_INDENT/){
                                $grab_indent++;
                            }
                            elsif($l=~/^SOURCE_DEDENT/){
                                $grab_indent--;
                                if($grab_indent==0){
                                    pop @grab_list;
                                    last;
                                }
                            }
                            $_i++;
                        }
                    }
                    else{


                    }
                    if($grab eq "grid"){
                        tk_grid(\@grab_list, $id);
                    }
                    elsif($grab eq "pack"){
                        tk_pack(\@grab_list, $id);
                    }
                    elsif($grab eq "place"){
                        tk_place(\@grab_list, $id);
                    }
                }
            }
        }
    }
}

sub tk_place {
    my ($codelist, $param) = @_;
    my $_l = $tk->{_list};
    my ($prefix, $root);
    if($param){
        $prefix = $param;
    }
    $root = $prefix;
    if(!$root){
        $root = ".";
    }
    my $idx=0;
    my $_i = -1;
    my $_n = @$codelist;
    while($_i <$_n-1){
        $_i++;
        my $l = $codelist->[$_i];
        if($l=~/^SOURCE/){
            next;
        }
        if($l=~/^\s*(\S+)\s*(\S+)\s*(.*)/){
            my ($x,$y, $t)=($1,$2,$3);
            my $id="$prefix.p$idx";
            $idx++;
            my $place;
            if($x=~/^0\./){
                $place.= " -relx $x";
            }
            else{
                $place.= " -x $x";
            }
            if($y=~/^0\./){
                $place.= " -rely $y";
            }
            else{
                $place.= " -y $y";
            }
            if($t=~/^(c|[tb][lr]|[ns][ew])\s*/){
                $t = $';
                my $a = $1;
                $a=~tr/tblr/nsew/;
                $place.= " -anchor $a";
            }
            if($t=~/^(\S+)\s+(.+)/){
                my ($type, $t)=($1,$2);
                my $grab;
                if($type=~/^\$?(grid|pack|place)$/){
                    $grab = $1;
                    $type = "frame";
                }

                my $o = {"_type"=>$type, "_id"=>$id, "_place"=>$place};
                push @$_l, $o;
                if($o and $t){
                    while(1){
                        if($t=~/\G$/sgc){
                            last;
                        }
                        elsif($t=~/\G-(\w+)\s+("(?:[^"\\]|\\.)*"|\S+)/sgc){
                            my ($w, $v)=($1,$2);
                            if($w=~/^(name|scroll)/){
                                $o->{"_$1"} = $v;
                            }
                            elsif($w=~/^(sticky|pad[xy]|expand|fill)/){
                                $o->{"_place"} .= " -$w $v";
                            }
                            else{
                                $o->{$w}=$v;
                            }
                        }
                        elsif($t=~/\G("(?:[^"\\]|\\.)*")/sgc){
                            $o->{text}=$1;
                        }
                        elsif($t=~/\G[,\s]+/sgc){
                            next;
                        }
                        else{
                            die "parse_loop: nothing matches! [$t]\n";
                        }
                    }
                }

                if($grab){
                    my @grab_list;
                    if($codelist->[$_i+1] =~/^SOURCE_INDENT/){
                        $_i = $_i+2;
                        my $grab_indent = 1;
                        while($_i<$_n){
                            my $l = $codelist->[$_i];
                            push @grab_list, $l;
                            if($l=~/^SOURCE_INDENT/){
                                $grab_indent++;
                            }
                            elsif($l=~/^SOURCE_DEDENT/){
                                $grab_indent--;
                                if($grab_indent==0){
                                    pop @grab_list;
                                    last;
                                }
                            }
                            $_i++;
                        }
                    }
                    else{


                    }
                    if($grab eq "grid"){
                        tk_grid(\@grab_list, $id);
                    }
                    elsif($grab eq "pack"){
                        tk_pack(\@grab_list, $id);
                    }
                    elsif($grab eq "place"){
                        tk_place(\@grab_list, $id);
                    }
                }
            }
        }
    }
}

1;
