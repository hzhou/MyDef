use strict;
use MyDef::output_perl;

package MyDef::output_plot;
our @g_stack;
our $g_hash={};
our %colornames;
our $out;
our $debug;
our %eqn_vars;
our @eqn_list;
our $n_eqn;
our $n_var;

sub parse_path {
    my ($param, $info) = @_;
    my $has_cycle=0;
    if($param=~/\s*\.\.\s*cycle\s*$/){
        $has_cycle=1;
        $param=$`;
    }
    elsif($param=~/\s*--\s*cycle\s*$/){
        $param=$`;
        if($param=~/(.*?)(\.\.|--)/){
            $param.="--$1";
        }
    }
    $param=~s/\.\.\./..tension -1../g;
    $param=~s/--/{curl 1}..{curl 1}/g;
    my @segments;
    my @t_segs = split /\s*&\s*/, $param;
    foreach my $s (@t_segs){
        my $plist=[];
        my $i=0;
        my @tlist=split /(\.\.(?:(?:tension|controls|arc).*?\.\.)?)/, $s;
        foreach my $t (@tlist){
            if($t eq ".."){
                next;
            }
            elsif($t=~/^\.\.tension\s*(.*?)\s*\.\.$/){
                if(!$plist->[$i]){
                    $plist->[$i]={};
                }
                my $tt=$1;
                if($tt=~/^(\S+)\s*and\s*(\S+)$/){
                    $plist->[$i-1]->{"tension+"}=$1;
                    $plist->[$i]->{"tension-"}=$2;
                }
                else{
                    $plist->[$i-1]->{"tension+"}=$tt;
                    $plist->[$i]->{"tension-"}=$tt;
                }
            }
            elsif($t=~/^\.\.controls\s*(.*?)\s*\.\.$/){
                if(!$plist->[$i]){
                    $plist->[$i]={};
                }
                my $tt=$1;
                if($tt=~/^(\S+)\s*and\s*(\S+)$/){
                    my ($t1, $t2)=($1, $2);
                    ($plist->[$i-1]->{"x+"}, $plist->[$i-1]->{"y+"}) = parse_point($t1);
                    ($plist->[$i]->{"x-"}, $plist->[$i]->{"y-"}) = parse_point($t2);
                }
                else{
                    die "single control point not supported\n";
                }
            }
            elsif($t=~/^\.\.arc\s*(.*?)\s*\.\.$/){
                if(!$plist->[$i]){
                    $plist->[$i]={};
                }
                my $tt=$1;
                if($tt=~/\((\S+),\s*(\S+)\s*\)/){
                    $plist->[$i-1]->{"arc+"}=$1;
                    $plist->[$i]->{"arc-"}=$2;
                }
            }
            else{
                if(!$plist->[$i]){
                    $plist->[$i]={};
                }
                my ($t1, $t2);
                if($t=~/^{(.*?)}/){
                    $t1 = $1;
                    $t=$';
                }
                if($t=~/^(.*){(.*)}$/){
                    $t2 = $2;
                    $t = $1;
                }
                if(!$t1 && $t2){
                    $t1 = $t2;
                    undef $t2;
                }
                if($t1){
                    if($t1=~/curl\s*(\S+)/){
                        $plist->[$i]->{"curl-"}=$1;
                        if(!$t2){
                            $plist->[$i]->{"curl+"}=$1;
                        }
                    }
                    else{
                        my ($x, $y)=parse_dir($t1);
                        if(!$t2){
                            $plist->[$i]->{"dx"}=$x;
                            $plist->[$i]->{"dy"}=$y;
                        }
                        else{
                            $plist->[$i]->{"dx-"}=$x;
                            $plist->[$i]->{"dy-"}=$y;
                        }
                    }
                }
                if($t2){
                    if($t2=~/curl\s*(\S+)/){
                        $plist->[$i]->{"curl+"}=$1;
                    }
                    else{
                        my ($x, $y)=parse_dir($t2);
                        $plist->[$i]->{"dx+"}=$x;
                        $plist->[$i]->{"dy+"}=$y;
                    }
                }
                my ($x, $y)=parse_point($t);
                $plist->[$i]->{x}=$x;
                $plist->[$i]->{y}=$y;
                if($i>0){
                    if(defined $plist->[$i]->{"x-"} or defined $plist->[$i]->{"arc-"}){
                        my $t=$plist->[$i];
                        if($i>1){
                            pop @$plist;
                            push @segments, $plist;
                            push @segments, [$plist->[-1], $t];
                        }
                        else{
                            push @segments, $plist;
                        }
                        $plist=[$t];
                        $i=0;
                    }
                    elsif(defined $plist->[$i]->{"dx-"} or defined $plist->[$i]->{"dx"} or defined $plist->[$i]->{"curl-"} or defined $plist->[$i]->{"curl"}){
                        my $t=$plist->[$i];
                        push @segments, $plist;
                        $plist=[$t];
                        $i=0;
                    }
                }
                $i++;
            }
        }
        if($i==1 and @tlist>1){
        }
        else{
            if(!@segments){
                if($has_cycle){
                    $plist->[0]->{cycle}=1;
                }
                push @segments, $plist;
            }
            elsif(!$has_cycle or $plist->[-1]->{"dx-"} or $plist->[-1]->{"curl-"} or $segments[0]->[0]->{"dx-"} or $segments[0]->[0]->{"curl-"}){
                push @segments, $plist;
            }
            else{
                my $tlist = shift @segments;
                push @$plist, @$tlist;
                push @segments, $plist;
            }
        }
    }
    my $last_point="";
    my $segment_i=0;
    foreach my $plist (@segments){
        my $t="$plist->[0]->{x}, $plist->[0]->{y}";
        if($t ne $last_point){
            push @$out, "MyPlot::moveto($t);";
        }
        if(@$plist==1){
            if($t ne $last_point){
                push @$out, "MyPlot::lineto($t);";
                if(($info->{type} eq "drawdblarrow") and $segment_i == 0){
                }
                if(($info->{type} eq "drawdblarrow" or $info->{type} eq "drawarrow") and $segment_i == $#segments){
                }
                $last_point = $t;
            }
        }
        elsif(@$plist==2 and defined $plist->[0]->{"x+"}){
            my $t = $plist->[0]->{"x+"}.", ";
            $t .= $plist->[0]->{"y+"}.", ";
            $t .= $plist->[1]->{"x-"}.", ";
            $t .= $plist->[1]->{"y-"};
            my $t2 = $plist->[1]->{"x"}.", ";
            $t2 .= $plist->[1]->{"y"};
            push @$out, "MyPlot::curveto($t, $t2);";
            if(($info->{type} eq "drawdblarrow") and $segment_i == 0){
                my $t = $plist->[0]->{"x"}.", ";
                $t .= $plist->[0]->{"y"}.", ";
                $t .= "atan2(".$plist->[0]->{"y+"}."-".$plist->[0]->{"y"}.",";
                $t .= $plist->[0]->{"x+"}."-".$plist->[0]->{"x"}.")";
                $info->{arrow_0_param} = $t;
            }
            if(($info->{type} eq "drawdblarrow" or $info->{type} eq "drawarrow") and $segment_i == $#segments){
                my $t = $plist->[-1]->{"x"}.", ";
                $t .= $plist->[-1]->{"y"}.", ";
                $t .= "atan2(".$plist->[1]->{"y-"}."-".$plist->[1]->{"y"}.",";
                $t .= $plist->[1]->{"x-"}."-".$plist->[1]->{"x"}.")";
                $info->{arrow_1_param} = $t;
            }
            $last_point = $t2;
        }
        elsif(@$plist==2 and defined $plist->[0]->{"arc+"} and defined $plist->[1]->{"arc-"}){
            my $t = $plist->[0]->{"x"}.", ";
            $t .= $plist->[0]->{"y"};
            my $t2 = $plist->[1]->{"x"}.", ";
            $t2 .= $plist->[1]->{"y"};
            my $arc = $plist->[0]->{"arc+"}.", ";
            $arc .= $plist->[1]->{"arc-"};
            push @$out, "MyPlot::arcto($t, $t2, $arc);";
            if(($info->{type} eq "drawdblarrow") and $segment_i == 0){
                my $t = $plist->[0]->{"x"}.", ";
                $t .= $plist->[0]->{"y"}.", ";
                my $a;
                if($plist->[1]->{"arc-"} > $plist->[0]->{"arc+"}){
                    $a = $plist->[0]->{"arc+"}+90;
                }
                else{
                    $a = $plist->[0]->{"arc+"}-90;
                }
                $a*=0.0174532925199;
                $t .= sprintf("%.4f", $a);
                $info->{arrow_0_param} = $t;
            }
            if(($info->{type} eq "drawdblarrow" or $info->{type} eq "drawarrow") and $segment_i == $#segments){
                my $t = $plist->[-1]->{"x"}.", ";
                $t .= $plist->[-1]->{"y"}.", ";
                my $a;
                if($plist->[1]->{"arc-"} > $plist->[0]->{"arc+"}){
                    $a = $plist->[1]->{"arc-"}-90;
                }
                else{
                    $a = $plist->[1]->{"arc-"}+90;
                }
                $a*=0.0174532925199;
                $t .= sprintf("%.4f", $a);
                $info->{arrow_1_param} = $t;
            }
            $last_point = $t2;
        }
        elsif(@$plist==2 and !defined $plist->[0]->{"dx"} and !defined $plist->[1]->{"dx"} and !defined $plist->[0]->{"dx+"} and !defined $plist->[1]->{"dx-"}){
            my $t2 = $plist->[1]->{"x"}.", ";
            $t2 .= $plist->[1]->{"y"};
            push @$out, "MyPlot::lineto($t2);";
            if(($info->{type} eq "drawdblarrow") and $segment_i == 0){
                my $t = $plist->[0]->{"x"}.", ";
                $t .= $plist->[0]->{"y"}.", ";
                $t .= "atan2(".$plist->[1]->{"y"}."-".$plist->[0]->{"y"}.",";
                $t .= $plist->[1]->{"x"}."-".$plist->[0]->{"x"}.")";
                $info->{arrow_0_param} = $t;
            }
            if(($info->{type} eq "drawdblarrow" or $info->{type} eq "drawarrow") and $segment_i == $#segments){
                my $t = $plist->[-1]->{"x"}.", ";
                $t .= $plist->[-1]->{"y"}.", ";
                $t .= "atan2(".$plist->[0]->{"y"}."-".$plist->[1]->{"y"}.",";
                $t .= $plist->[0]->{"x"}."-".$plist->[1]->{"x"}.")";
                $info->{arrow_1_param} = $t;
            }
            $last_point = $t2;
        }
        else{
            push @$out, "my \@path;\n";
            foreach my $t (@$plist){
                my @t;
                foreach my $k (sort keys %$t){
                    push @t, "\"$k\"=>$t->{$k}";
                }
                push @$out, "push \@path, {".join(', ', @t)."};\n";
            }
            push @$out, "MyPlot::solve_path(\\\@path);\n";
            push @$out, "MyPlot::do_path(\\\@path, 1);";
            if(($info->{type} eq "drawdblarrow") and $segment_i == 0){
                my $t = $plist->[0]->{"x"}.", ";
                $t .= $plist->[0]->{"y"}.", ";
                my $t2 = "atan2(\$path[0]->{\"y+\"}-\$path[0]->{\"y\"}, ";
                $t2 .= "\$path[0]->{\"x+\"}-\$path[0]->{\"x\"})";
                push @$out, "my \$theta0 = $t2;";
                $t .= "\$theta0";
                $info->{arrow_0_param} = $t;
            }
            if(($info->{type} eq "drawdblarrow" or $info->{type} eq "drawarrow") and $segment_i == $#segments){
                my $t = $plist->[-1]->{"x"}.", ";
                $t .= $plist->[-1]->{"y"}.", ";
                my $t2 = "atan2(\$path[-1]->{\"y-\"}-\$path[-1]->{\"y\"}, ";
                $t2 .= "\$path[-1]->{\"x-\"}-\$path[-1]->{\"x\"})";
                $t .= "$t2";
                $info->{arrow_1_param} = $t;
            }
            $last_point="$plist->[-1]->{x}, $plist->[-1]->{y}";
        }
        $segment_i++;
    }
    my $first_point="$segments[0]->[0]->{x}, $segments[0]->[0]->{y}";
    if($has_cycle or $first_point eq $last_point){
        push @$out, "MyPlot::close_path();";
    }
}

sub parse_point {
    my ($t) = @_;
    my $exp = parse_expr($t, $g_hash->{macro}, {});
    if($exp->[1] ne "list"){
        die "point parsing error: [$t]\n";
    }
    my @t;
    for(my $i=0; $i <2; $i++){
        my $t=$exp->[0]->[$i];
        if($t->[1] eq "var"){
            $t[$i]=get_var_string($t);
        }
        elsif($t->[1] eq "num"){
            $t[$i]=$t->[0];
        }
        else{
            die "parse_point illegal type [$t]\n";
        }
    }
    return @t;
}

sub parse_dir {
    my ($t) = @_;
    my ($x, $y);
    if($t eq "left"){
        ($x, $y)=(-1,0);
    }
    elsif($t eq "right"){
        ($x, $y)=(1,0);
    }
    elsif($t eq "up"){
        ($x, $y)=(0,1);
    }
    elsif($t eq "down"){
        ($x, $y)=(0,-1);
    }
    elsif($t=~/dir\s*(\S+)/){
        my $t=$1;
        my $u=3.1415926/180;
        if($t=~/^[0-9.]+$/){
            ($x, $y)=(cos($t), sin($t));
        }
        else{
            ($x, $y)=("cos($t*$u)", "sin($t*$u)");
        }
    }
    else{
        ($x, $y)=parse_point($t);
        if($x==0 and $y==0){
            die "Error in parse_dir[$t]\n";
        }
        my $d = sqrt($x**2+$y**2);
        $x/=$d;
        $y/=$d;
    }
    return ($x, $y);
}

sub parse_edge {
    my ($t) = @_;
    my ($t1, $t2)=MyDef::utils::proper_split($t);
    my ($x1, $y1)=parse_point($t1);
    my ($x2, $y2)=parse_point($t2);
    return ($x1, $y1, $x2, $y2);
}

sub parse_point_name {
    my ($v, $macros) = @_;
    my ($pre, $xyz, $tail);
    if($v=~/^([xyz])(\w*)/){
        ($pre, $xyz, $tail)=("", $1, $2);
    }
    elsif($v=~/^(\w+_)([xyz])(\w*)/){
        ($pre, $xyz, $tail)=($1, $2, $3);
    }
    else{
        return;
    }
    if($tail){
        if(defined $macros->{i}){
            $tail=~s/i/$macros->{i}/g;
        }
        if(defined $macros->{j}){
            $tail=~s/j/$macros->{j}/g;
        }
        if(defined $macros->{k}){
            $tail=~s/k/$macros->{k}/g;
        }
    }
    return ($pre, $xyz, $tail);
}

sub parse_expr {
    my ($l, $macros1, $macros2) = @_;
    if(!$l){
        return;
    }
    if($debug){
        print "parse_expr [$l]\n";
    }
    my @stack;
    my %prec=(
        'eof'=>0,
        ','=>1,
        "+"=>2, "-"=>2,
        "*"=>3, "/"=>3, "%"=>3,
        "^"=>4,
        "func"=>5,
        "unary"=>6,
        "num"=>4,
        "list"=>4,
        "var"=>4,
        '('=>-1, '['=>-1, ')'=>0, ']'=>0,
        't('=>4, 't['=>4,
        );
    my %func=();
    my @bracket_stack;
    my %match=('['=>']', '('=>')');
    while(1){
        my $cur;
        if($l=~/\G$/gc){
            $cur = [undef, "eof"];
        }
        elsif($l=~/\G\s+/gc){
            next;
        }
        elsif($l=~/\G([\+\-\*\/,])/gc){
            $cur = [$1, $1];
        }
        elsif($l=~/\G([\(\[\{])/gc){
            $cur = [$1, "t$1"];
        }
        elsif($l=~/\G([\)\]\}])/gc){
            $cur = [$1, $1];
        }
        elsif($l=~/\G(\d+)\/(\d+)/gc){
            $cur = [$1/$2, "num"];
        }
        elsif($l=~/\G(\d+(\.\d+)?)/gc){
            $cur = [$1, "num"];
        }
        elsif($l=~/\G(\$\w+)/gc){
            $cur = [$1, "num"];
        }
        elsif($l=~/\G([ijk])%(\d+)/gc){
            $cur = [$macros2->{$1} % $2, "num"];
        }
        elsif($l=~/\G([ijk])\/(\d+)/gc){
            use integer;
            $cur = [$macros2->{$1} / $2, "num"];
        }
        elsif($l=~/\G(\w+)/gc){
            if(defined $macros1->{$1}){
                $cur = [$macros1->{$1}, "num"];
            }
            elsif(defined $macros2->{$1}){
                $cur = [$macros2->{$1}, "num"];
            }
            elsif($func{$1}){
                $cur = [$1, "func"];
            }
            else{
                my $t=$1;
                my ($pre, $xyz, $tail)=parse_point_name($1, $macros2);
                if(!$xyz){
                    $cur = make_var($t, {});
                }
                elsif($xyz eq "z"){
                    my $x = make_var($pre."x".$tail, $macros2);
                    my $y = make_var($pre."y".$tail, $macros2);
                    $cur = [[$x, $y], "list"];
                }
                else{
                    $cur = make_var($pre.$xyz.$tail, $macros2);
                }
            }
        }
        else{
            $l=~/\G(.)/gc;
            $cur = [$1, "extra"];
        }
        process:
        if(!defined $prec{$cur->[1]}){
            die "precedence $cur->[1] not specified\n";
        }
        while(@stack>=2 and ($stack[-1]->[1]=~/num|var|list/) and $prec{$cur->[1]} <= $prec{$stack[-2]->[1]}){
            reduce_stack(\@stack);
        }
        if($cur->[1] eq 't[' or $cur->[1] eq 't('){
            $cur->[1]=substr($cur->[1], 1, 1);
            push @bracket_stack, $match{$cur->[1]};
        }
        elsif($cur->[1] eq ']' or $cur->[1] eq ')'){
            if($cur->[1] ne $bracket_stack[-1]){
                print "cur: $cur->[1], last: $bracket_stack[-1]\n";
                die "Bracket mismatch\n";
            }
            elsif($match{$stack[-1]->[1]} eq $cur->[1]){
                die "Bracket empty\n";
            }
            elsif($match{$stack[-2]->[1]} eq $cur->[1]){
                my $t = pop @stack;
                pop @stack;
                if($cur->[1] eq ")"){
                    $cur = $t;
                    goto process;
                }
                elsif($cur->[1] eq "]"){
                    if($t->[1] eq "list" and @{$t->[0]}==2){
                        if($stack[-1]->[1] eq "num"){
                            my $t2=pop @stack;
                            $cur = do_portion($t2, @{$t->[0]});
                        }
                        elsif($stack[-1]->[0] eq "-"){
                            pop @stack;
                            $cur = do_portion([-1, "num"], @{$t->[0]});
                        }
                        else{
                            die "Error [ ]: wrong scalar\n";
                        }
                    }
                    else{
                        die "Error [ ]: type mismatch\n";
                    }
                    goto process;
                }
            }
            else{
                die "Error unreduced bracket\n";
            }
        }
        elsif($cur->[1] eq '-' and (@stack==0 or $stack[-1]->[1] !~/num|var|list/)){
            $cur = ["-", "unary"];
        }
        if($cur->[1] eq "eof"){
            last;
        }
        else{
            push @stack, $cur;
        }
    }
    if(@stack!=1){
        my $n=@stack;
        print "---- dump stack [$n] ----\n";
        foreach my $t (@stack){
            print_token($t);
        }
        die "Unreduced expresion [$l].\n";
    }
    return $stack[0];
}

sub reduce_stack {
    my ($stack) = @_;
    my $cur;
    my $t = pop @$stack;
    my $op = pop @$stack;
    if($op->[1] eq "unary"){
        if($op->[0] eq "-"){
            $cur = do_unary("neg", $t);
        }
        else{
            die "Non-supported unary operator\n";
        }
    }
    elsif($op->[1] =~/[\+\-\*\/\^,]/){
        my $t2 = pop @$stack;
        $cur = do_binary($op->[1], $t2, $t);
    }
    elsif($op->[1] eq "num"){
        $cur = do_binary("*", $op, $t);
    }
    elsif($op->[1] eq "func"){
        $cur = do_function($op->[0], $t);
    }
    else{
        print_token($op, "op");
        print_token($t, "t");
        die "not supported operator type $op->[1]\n";
    }
    push @$stack, $cur;
}

sub get_var_string {
    my ($v) = @_;
    my %t;
    foreach my $t (@{$v->[0]}){
        my ($k, $v)=@$t;
        if(defined $t{$k}){
            $t{$k}+=$v;
        }
        else{
            $t{$k}=$v;
        }
    }
    my @t=sort {$a cmp $b} keys %t;
    my @segs;
    my $const;
    foreach my $k (@t){
        if($k eq "1"){
            $const=$t{1};
        }
        else{
            my $c=$t{$k};
            if($c==1){
                push @segs, "\$$k";
            }
            elsif($c<0){
                push @segs, "($c) * \$$k";
            }
            else{
                push @segs, "$c * \$$k";
            }
        }
    }
    if(defined $const){
        if($const<0){
            push @segs, "($const)";
        }
        else{
            push @segs, $const;
        }
    }
    return join(" + ", @segs);
}

sub do_unary {
    my ($op, $t) = @_;
    if($op eq "neg"){
        if($t->[1] eq "list"){
            foreach my $t2 (@{$t->[0]}){
                $t2=do_unary($op, $t2);
            }
            return $t;
        }
        elsif($t->[1] eq "num"){
            $t->[0]=-$t->[0];
            return $t;
        }
        elsif($t->[1] eq "var"){
            my $tlist = $t->[0];
            foreach my $t2 (@{$t->[0]}){
                $t2->[1]= - $t2->[1];
            }
            return $t;
        }
    }
    else{
        die "non supported unary operator\n";
    }
}

sub do_binary {
    my ($op, $t1, $t2) = @_;
    if($op eq ","){
        if($t1->[1] eq "list" and $t2->[1] ne "list"){
            push @{$t1->[0]}, $t2;
            return $t1;
        }
        else{
            return [[$t1, $t2], "list"];
        }
    }
    elsif($t1->[1] eq "list" and $t2->[1] eq "list"){
        my $n = @{$t1->[0]};
        my @t;
        for(my $i=0; $i <$n; $i++){
            push @t, do_binary($op, $t1->[0]->[$i], $t2->[0]->[$i]);
        }
        return [\@t, "list"];
    }
    elsif($t1->[1] eq "num" and $t2->[1] eq "num"){
        $t1=$t1->[0];
        $t2=$t2->[0];
        if($op eq "+"){
            return [$t1+$t2, "num"];
        }
        elsif($op eq "-"){
            return [$t1-$t2, "num"];
        }
        elsif($op eq "*"){
            return [$t1*$t2, "num"];
        }
        elsif($op eq "/"){
            return [$t1/$t2, "num"];
        }
        elsif($op eq "++"){
            return [sqrt($t1*$t1+$t2*$t2), "num"];
        }
        elsif($op eq "+-+"){
            return [sqrt($t1*$t1-$t2*$t2), "num"];
        }
        elsif($op eq "^"){
            return [$t1**$t2, "num"];
        }
        else{
            die "unsuported binary operator $op\n";
        }
    }
    elsif($t2->[1] eq "num"){
        if($op eq "-"){
            $t2->[0] = -$t2->[0];
            return do_binary("+", $t2, $t1);
        }
        elsif($op eq "/"){
            $t2->[0] = 1.0/$t2->[0];
            return do_binary("*", $t2, $t1);
        }
        elsif($op eq "+" or $op eq "*"){
            return do_binary($op, $t2, $t1);
        }
        else{
            die "unsuported binary t1->[1] $op num\n";
        }
    }
    elsif($t1->[1] eq "num" and $t2->[1] eq "list"){
        my $n = @{$t2->[0]};
        my @t;
        for(my $i=0; $i <$n; $i++){
            push @t, do_binary($op, $t1, $t2->[0]->[$i]);
        }
        return [\@t, "list"];
    }
    elsif($t1->[1] eq "num" and $t2->[1] eq "var"){
        if($op eq "*"){
            foreach my $t (@{$t2->[0]}){
                $t->[1]*=$t1->[0];
            }
            return $t2;
        }
        elsif($op eq "+"){
            push @{$t2->[0]}, [1, $t1->[0]];
            return $t2;
        }
        elsif($op eq "-"){
            foreach my $t (@{$t2->[0]}){
                $t->[1] = -$t->[1];
            }
            push @{$t2->[0]}, [1, $t1->[0]];
            return $t2;
        }
        else{
            die "unsuported binary num $op var\n";
        }
    }
    elsif($t1->[1] eq "var" and $t2->[1] eq "var"){
        if($op eq "+"){
            foreach my $t (@{$t2->[0]}){
                push @{$t1->[0]}, $t;
            }
            return $t1;
        }
        elsif($op eq "-"){
            foreach my $t (@{$t2->[0]}){
                $t->[1] = -$t->[1];
                push @{$t1->[0]}, $t;
            }
            return $t1;
        }
        else{
            die "unsuported binary var $op var\n";
        }
    }
}

sub make_var {
    my ($name, $coeff) = @_;
    if(ref($coeff) ne "HASH"){
        return [[[$name, $coeff]], "var"];
    }
    elsif(defined $coeff->{$name}){
        return [$coeff->{$name}, "num"];
    }
    else{
        return [[[$name, 1]], "var"];
    }
}

sub parse_eqn {
    my ($left, $right, $macro, $points) = @_;
    my $eqn = do_binary("-", $left, $right);
    if($eqn->[1] ne "var"){
        die "equation contains no variable\n";
    }
    my %t;
    foreach my $t (@{$eqn->[0]}){
        my ($k, $v)=@$t;
        if(defined $t{$k}){
            $t{$k}+=$v;
        }
        else{
            $t{$k}=$v;
        }
    }
    if(!exists $t{1}){
        $t{1}=0;
    }
    my @t=sort {$a cmp $b} keys %t;
    if($debug){
        print "eqn: ";
        foreach my $t (@t){
            print " $t{$t} $t, ";
        }
        print "\n";
    }
    if(@t==2){
        my $k=$t[1];
        my $v=-$t{1}/$t{$k};
        if(defined $macro->{$k}){
            die "variable exist: $k ($macro->{$k} --> $v)\n";
        }
        else{
            $macro->{$k}=$v;
            if($k=~/(\b|_)[xy]/){
                $points->{$k}=$v;
            }
        }
    }
    else{
        foreach my $k (@t){
            if($k ne "1" and !exists($eqn_vars{$k})){
                $eqn_vars{$k}=1;
                $n_var++;
            }
        }
        push @eqn_list, \%t;
        $n_eqn++;
        if($n_eqn == $n_var){
            die "solving linear equations not implemented\n";
            reset_eqns();
        }
    }
}

sub reset_eqns {
    %eqn_vars=();
    @eqn_list=();
    $n_eqn=0;
    $n_var=0;
}

sub do_portion {
    my ($a, $t1, $t2) = @_;
    my $t = do_binary("-", $t2, $t1);
    $t = do_binary("*", $a, $t);
    $t = do_binary("+", $t1, $t);
    return $t;
}

sub do_function {
    my ($name, @t) = @_;
}

sub check_default {
    my ($type) = @_;
    if($type eq "draw"){
        if(!$g_hash->{linewidth}){
            $g_hash->{linewidth}=2;
            push @$out, "MyPlot::line_width(2);";
        }
        if(!$g_hash->{linecap}){
            $g_hash->{linecap}="round";
            push @$out, "MyPlot::line_cap('round');";
            push @$out, "MyPlot::line_join('round');";
        }
    }
}

sub parse_graphic_state {
    my ($param) = @_;
    my $cm_changed;
    my @tlist = MyDef::utils::proper_split($param);
    foreach my $t (@tlist){
        if($t=~/^(\d[0-9.]*)(pt)?/){
            $g_hash->{linewidth}=$1;
            push @$out, "MyPlot::line_width($1);";
        }
        elsif($t =~/^dash$/){
            push @$out, "MyPlot::line_dash(1);";
        }
        elsif($colornames{$t} or $t=~/^#/){
            if($colornames{$t}){
                $t = $colornames{$t};
            }
            if($t=~/^#(..)(..)(..)/){
                if($1 eq $2 and $1 eq $3){
                    my $t=sprintf("%.2f", hex($1)/255);
                    push @$out, "MyPlot::stroke_gray($t);";
                }
                else{
                    my $r=sprintf("%.2f",hex($1)/255);
                    my $g=sprintf("%.2f",hex($2)/255);
                    my $b=sprintf("%.2f",hex($3)/255);
                    push @$out, "MyPlot::stroke_rgb($r, $g, $b);";
                }
            }
        }
        elsif($t=~/fill\s*(.*)/){
            $t=$1;
            if($colornames{$t}){
                $t = $colornames{$t};
            }
            if($t=~/^#(..)(..)(..)/){
                if($1 eq $2 and $1 eq $3){
                    my $t=sprintf("%.2f", hex($1)/255);
                    push @$out, "MyPlot::fill_gray($t);";
                }
                else{
                    my $r=sprintf("%.2f",hex($1)/255);
                    my $g=sprintf("%.2f",hex($2)/255);
                    my $b=sprintf("%.2f",hex($3)/255);
                    push @$out, "MyPlot::fill_rgb($r, $g, $b);";
                }
            }
        }
        elsif($t=~/origin\s*\((.*)\)/){
            my ($x, $y)=parse_point($1);
            if(!$g_hash->{cm}){
                $g_hash->{cm}=[1, 0, 0, 1, $x, $y];
            }
            else{
                my $cm = $g_hash->{cm};
                $cm->[4]+=$cm->[0]*$x+$cm->[1]*$y;
                $cm->[5]+=$cm->[2]*$x+$cm->[3]*$y;
            }
            $cm_changed=1;
        }
        elsif($t=~/rotate\s*(.*)/){
            my $th=$1*3.14159265/180;
            my $C=cos($th);
            my $S=sin($th);
            if(!$g_hash->{cm}){
                $g_hash->{cm}=[$C, $S, -$S, $C, 0, 0];
            }
            else{
                my $cm = $g_hash->{cm};
                my $a0 = $cm->[0]*$C-$cm->[1]*$S;
                my $a1 = $cm->[0]*$S+$cm->[1]*$C;
                my $a2 = $cm->[2]*$C-$cm->[3]*$S;
                my $a3 = $cm->[2]*$S+$cm->[3]*$C;
                $cm->[0]=$a0;
                $cm->[1]=$a1;
                $cm->[2]=$a2;
                $cm->[3]=$a3;
            }
            $cm_changed=1;
        }
        elsif($t=~/scale\s*\((.*)\)/){
            my ($x, $y)=parse_point($1);
            if(!$g_hash->{cm}){
                $g_hash->{cm}=[$x, 0, 0, $y, 0, 0];
            }
            else{
                my $cm = $g_hash->{cm};
                $cm->[0]*=$x;
                $cm->[1]*=$y;
                $cm->[2]*=$x;
                $cm->[3]*=$y;
            }
            $cm_changed=1;
        }
        elsif($t=~/scale\s*(.*)/){
            if(!$g_hash->{cm}){
                $g_hash->{cm}=[$1, 0, 0, $1, 0, 0];
            }
            else{
                my $cm = $g_hash->{cm};
                $cm->[0]*=$1;
                $cm->[1]*=$1;
                $cm->[2]*=$1;
                $cm->[3]*=$1;
            }
            $cm_changed=1;
        }
        elsif($t=~/skew\s*\((.*)\)/){
            my ($x, $y)=parse_point($1);
            my $ta=tan($x*3.14159265/180);
            my $tb=tan($y*3.14159265/180);
            if(!$g_hash->{cm}){
                $g_hash->{cm}=[1, $ta, $tb, 1, 0, 0];
            }
            else{
                my $cm = $g_hash->{cm};
                my $a0=$cm->[0]+$cm->[1]*$tb;
                my $a1=$cm->[0]*$ta+$cm->[1];
                my $a2=$cm->[2]+$cm->[3]*$tb;
                my $a3=$cm->[2]*$ta+$cm->[3];
                $cm->[0]=$a0;
                $cm->[1]=$a1;
                $cm->[2]=$a2;
                $cm->[3]=$a3;
            }
            $cm_changed=1;
        }
        elsif($t=~/skew\s*(.*)/){
            my $ta=tan($1*3.14159265/180);
            my $tb=tan($1*3.14159265/180);
            if(!$g_hash->{cm}){
                $g_hash->{cm}=[1, $ta, $tb, 1, 0, 0];
            }
            else{
                my $cm = $g_hash->{cm};
                my $a0=$cm->[0]+$cm->[1]*$tb;
                my $a1=$cm->[0]*$ta+$cm->[1];
                my $a2=$cm->[2]+$cm->[3]*$tb;
                my $a3=$cm->[2]*$ta+$cm->[3];
                $cm->[0]=$a0;
                $cm->[1]=$a1;
                $cm->[2]=$a2;
                $cm->[3]=$a3;
            }
            $cm_changed=1;
        }
        elsif($t=~/(\w+)=([0-9\.]+)/){
            $g_hash->{macro}->{$1}=$2;
        }
    }
    if($cm_changed){
        my $t=join(", ",  @{$g_hash->{cm}});
        push @$out, "MyPlot::set_matrix($t);";
    }
}

sub print_token {
    my ($t, $pre, $post) = @_;
    if(defined $pre){
        print $pre;
    }
    if(ref($t->[0]) eq "ARRAY"){
        print "  ( ";
        foreach my $t2 (@{$t->[0]}){
            print_token($t2, "", ", ");
        }
        print " $t->[1] )";
    }
    elsif(ref($t->[0]) eq "HASH"){
        print "  ( ";
        while (my ($k, $v) = each %{$t->[0]}){
            print "$k=>";
            print_token($v, "", "");
            print ", ";
        }
        print ", $t->[1] )";
    }
    else{
        print "  ( $t->[0], $t->[1] )";
    }
    if(defined $post){
        print $post;
    }
    else{
        print "\n";
    }
}

%colornames=(
    black=>"#000000",
    white=>"#ffffff",
    red=>"#ff0000",
    lime=>"#00ff00",
    blue=>"#0000ff",
    cyan=>"#00ffff",
    aqua=>"#00ffff",
    magenta=>"#ff00ff",
    fuchsia=>"#ff00ff",
    yellow=>"#ffff00",
    maroon=>"#800000",
    green=>"#008000",
    navy=>"#000080",
    teal=>"#008080",
    purple=>"#800080",
    olive=>"#808000",
    gray=>"#808080",
    silver=>"#c0c0c0",
    orange=>"#ffa500",
    brown=>"#a52a2a",
    gold=>"#ffd700",
    pink=>"#ffc0cb",
    beige=>"#f5f5dc",
    bisque=>"#ffe4c4",
    ivory=>"#fffff0",
    indigo=>"#4b0082",
    turquoise=>"#40e0d0",
    aliceblue=>"#f0f8ff",
    antiquewhite=>"#faebd7",
    aquamarine=>"#7fffd4",
    azure=>"#f0ffff",
    blanchedalmond=>"#ffebcd",
    blueviolet=>"#8a2be2",
    burlywood=>"#deb887",
    cadetblue=>"#5f9ea0",
    chartreuse=>"#7fff00",
    chocolate=>"#d2691e",
    coral=>"#ff7f50",
    cornflowerblue=>"#6495ed",
    cornsilk=>"#fff8dc",
    crimson=>"#dc143c",
    darkblue=>"#00008b",
    darkcyan=>"#008b8b",
    darkgoldenrod=>"#b8860b",
    darkgray=>"#a9a9a9",
    darkgreen=>"#006400",
    darkkhaki=>"#bdb76b",
    darkmagenta=>"#8b008b",
    darkolivegreen=>"#556b2f",
    darkorange=>"#ff8c00",
    darkorchid=>"#9932cc",
    darkred=>"#8b0000",
    darksalmon=>"#e9967a",
    darkseagreen=>"#8fbc8f",
    darkslateblue=>"#483d8b",
    darkslategray=>"#2f4f4f",
    darkturquoise=>"#00ced1",
    darkviolet=>"#9400d3",
    deeppink=>"#ff1493",
    deepskyblue=>"#00bfff",
    dimgray=>"#696969",
    dodgerblue=>"#1e90ff",
    firebrick=>"#b22222",
    floralwhite=>"#fffaf0",
    forestgreen=>"#228b22",
    gainsboro=>"#dcdcdc",
    ghostwhite=>"#f8f8ff",
    goldenrod=>"#daa520",
    greenyellow=>"#adff2f",
    honeydew=>"#f0fff0",
    hotpink=>"#ff69b4",
    indianred=>"#cd5c5c",
    khaki=>"#f0e68c",
    lavender=>"#e6e6fa",
    lavenderblush=>"#fff0f5",
    lawngreen=>"#7cfc00",
    lemonchiffon=>"#fffacd",
    lightblue=>"#add8e6",
    lightcoral=>"#f08080",
    lightcyan=>"#e0ffff",
    lightgoldenrodyellow=>"#fafad2",
    lightgray=>"#d3d3d3",
    lightgreen=>"#90ee90",
    lightpink=>"#ffb6c1",
    lightsalmon=>"#ffa07a",
    lightseagreen=>"#20b2aa",
    lightskyblue=>"#87cefa",
    lightslategray=>"#778899",
    lightsteelblue=>"#b0c4de",
    lightyellow=>"#ffffe0",
    limegreen=>"#32cd32",
    linen=>"#faf0e6",
    mediumaquamarine=>"#66cdaa",
    mediumblue=>"#0000cd",
    mediumorchid=>"#ba55d3",
    mediumpurple=>"#9370db",
    mediumseagreen=>"#3cb371",
    mediumslateblue=>"#7b68ee",
    mediumspringgreen=>"#00fa9a",
    mediumturquoise=>"#48d1cc",
    mediumvioletred=>"#c71585",
    midnightblue=>"#191970",
    mintcream=>"#f5fffa",
    mistyrose=>"#ffe4e1",
    moccasin=>"#ffe4b5",
    navajowhite=>"#ffdead",
    oldlace=>"#fdf5e6",
    olivedrab=>"#6b8e23",
    orangered=>"#ff4500",
    orchid=>"#da70d6",
    palegoldenrod=>"#eee8aa",
    palegreen=>"#98fb98",
    paleturquoise=>"#afeeee",
    palevioletred=>"#db7093",
    papayawhip=>"#ffefd5",
    peachpuff=>"#ffdab9",
    peru=>"#cd853f",
    plum=>"#dda0dd",
    powderblue=>"#b0e0e6",
    rebeccapurple=>"#663399",
    rosybrown=>"#bc8f8f",
    royalblue=>"#4169e1",
    saddlebrown=>"#8b4513",
    salmon=>"#fa8072",
    sandybrown=>"#f4a460",
    seagreen=>"#2e8b57",
    seashell=>"#fff5ee",
    sienna=>"#a0522d",
    skyblue=>"#87ceeb",
    slateblue=>"#6a5acd",
    slategray=>"#708090",
    snow=>"#fffafa",
    springgreen=>"#00ff7f",
    steelblue=>"#4682b4",
    tan=>"#d2b48c",
    thistle=>"#d8bfd8",
    tomato=>"#ff6347",
    violet=>"#ee82ee",
    wheat=>"#f5deb3",
    whitesmoke=>"#f5f5f5",
    yellowgreen=>"#9acd32",
);
sub get_interface {
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout);
}
sub set_output {
    my ($newout)=@_;
    $out = $newout;
    MyDef::output_perl::set_output($newout);
}
sub modeswitch {
    my ($mode, $in)=@_;
}
sub init_page {
    my ($page)=@_;
    if(!$page->{type}){
        $page->{type}="pl";
    }
    MyDef::output_perl::init_page(@_);
    return $page->{init_mode};
}
sub parsecode {
    my ($l)=@_;
    if($l=~/^DEBUG (\w+)/){
        if($1 eq "OFF"){
            $debug=0;
        }
        else{
            $debug=$1;
        }
        return MyDef::output_perl::parsecode($l);
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
    if($l=~/CALLBACK\s*(\w+)\s*(.*)/){
        my ($func, $param)=($1, $2);
        my $codelist=$MyDef::compileutil::named_blocks{"last_grab"};
        if($func =~/^set_point/){
            my %points;
            my ($origin, $rotate);
            my $macros1={};
            my @tlist=MyDef::utils::proper_split /,\s*/, $param;
            my $loop_list;
            foreach my $t (@tlist){
                if($t=~/^([ijk])=(.+)/){
                    my @t_loops;
                    my $v=$1;
                    my @ilist=split /:/, $2;
                    if(@ilist==2){
                        for(my $i=$ilist[0];$i<$ilist[1];$i++){
                            push @t_loops, "$v=$i";
                        }
                    }
                    elsif(@ilist==3){
                        for(my $i=$ilist[0];$i<$ilist[1];$i+=$ilist[2]){
                            push @t_loops, "$v=$i";
                        }
                    }
                    if(@t_loops){
                        if(!$loop_list){
                            $loop_list=\@t_loops;
                        }
                        else{
                            my @t;
                            foreach my $t1 (@t_loops){
                                foreach my $t2 (@$loop_list){
                                    push @t, "$t2, $t1";
                                }
                            }
                            $loop_list=\@t;
                        }
                    }
                }
                elsif($t=~/^origin\s*\((\S+),\s*(\S+)\)/){
                    $origin=[$1, $2];
                }
                elsif($t=~/^rotate\s*(\S+)/){
                    $rotate=$1;
                }
                elsif($t=~/^(\w+)=(.+)/){
                    $macros1->{$1}=$2;
                }
            }
            if(!$loop_list){
                $loop_list=[""];
            }
            foreach my $t (@$loop_list){
                my $macros2={};
                while($t=~/(\w+)=(\d+)/g){
                    $macros2->{$1}=$2;
                }
                reset_eqns();
                foreach my $l (@$codelist){
                    if($l!~/^SOURCE/){
                        if($l=~/(.+)=(.+)/){
                            my ($t1, $t2)=($1, $2);
                            my $left=parse_expr($t1, $macros1, $macros2);
                            my $right=parse_expr($t2, $macros1, $macros2);
                            if($left->[1] eq "list" and $right->[1] eq "list"){
                                my $n1=@{$left->[0]};
                                if($n1==@{$right->[0]}){
                                    for(my $i=0; $i <$n1; $i++){
                                        parse_eqn($left->[0]->[$i], $right->[0]->[$i], $macros2, \%points);
                                    }
                                }
                                else{
                                    die "list assignment mismatch ($n1)\n";
                                }
                            }
                            else{
                                parse_eqn($left, $right, $macros2, \%points);
                            }
                        }
                        else{
                        }
                    }
                }
            }
            if(%points){
                my @zlist;
                foreach my $p (sort keys %points){
                    if(defined $points{$p}){
                        my ($pre, $xyz, $tail)=parse_point_name($p);
                        my $x=$pre.'x'.$tail;
                        my $y=$pre.'y'.$tail;
                        push @zlist, [$x, $y, $points{$x}, $points{$y}];
                        $points{$x}=undef;
                        $points{$y}=undef;
                    }
                }
                if($rotate){
                    my $s=sin($rotate*3.14159265/180.0);
                    my $c=cos($rotate*3.14159265/180.0);
                    foreach my $z (@zlist){
                        my $x = $c * $z->[2] - $s * $z->[3];
                        my $y = $s * $z->[2] + $c * $z->[3];
                        $z->[2] = $x;
                        $z->[3] = $y;
                    }
                }
                if($origin){
                    foreach my $z (@zlist){
                        $z->[2]+=$origin->[0];
                        $z->[3]+=$origin->[1];
                    }
                }
                push @$out, "\n";
                foreach my $z (@zlist){
                    push @$out, "my (\$$z->[0], \$$z->[1]) = ($z->[2], $z->[3]);\n";
                }
                push @$out, "\n";
            }
            return 0;
        }
        elsif($func =~/^tex/){
            my @tlist=MyDef::utils::proper_split($param);
            my $pt_size=12;
            my $mode="text";
            my ($x, $y);
            my ($w, $h);
            foreach my $t (@tlist){
                if($t=~/^(\d+)(pt)?$/){
                    $pt_size=$1;
                }
                elsif($t=~/^(math)$/){
                    $mode=$1;
                }
                elsif($t=~/^at\s*\((\S+),\s*(\S+)\)$/){
                    ($x, $y)=($1, $2);
                }
                elsif($t=~/^width\s*(\S+)/){
                    $w = $1;
                }
            }
            push @$out, "MyPlot::init_tex_font($pt_size);";
            while($codelist->[-1]=~/^\s*$/){
                pop @$codelist;
            }
            while($codelist->[0]=~/^SOURCE/){
                shift @$codelist;
            }
            my $src;
            if(@$codelist==1){
                my $t=$codelist->[0];
                $t=~s/\\/\\\\/g;
                $t=~s/'/\\'/g;
                $src="'$t'";
            }
            else{
                push @$out, "my \$tex_src= <<'HERE';";
                push @$out, "PUSHDENT";
                foreach my $t (@$codelist){
                    if($t!~/^SOURCE/){
                        push @$out, $t;
                    }
                }
                push @$out, "HERE";
                push @$out, "POPDENT";
                $src = '$tex_src';
            }
            push @$out, "my \$tex = MyPlot::format_tex(MyPlot::parse_tex($src, \"$mode\"));";
            if($w){
                push @$out, "MyPlot::tex_set_width(\$tex, $w);";
            }
            push @$out, "MyPlot::tex_display(\$tex, $x, $y);";
            return 0;
        }
        return 0;
    }
    elsif($l=~/^\$(\w+)\s*(.*)/){
        my ($func, $param)=($1, $2);
        if($func =~/^draw/){
            check_default("draw");
            my $info={type=>$func};
            parse_path($param, $info);
            push @$out, "MyPlot::stroke();";
            if($info->{arrow_0_param}){
                push @$out, "MyPlot::arrow($info->{arrow_0_param}, $g_hash->{linewidth}+4);";
            }
            if($info->{arrow_1_param}){
                push @$out, "MyPlot::arrow($info->{arrow_1_param}, $g_hash->{linewidth}+4);";
            }
            return 0;
        }
        elsif($func =~/^fill/){
            check_default("fill");
            my $info={type=>$func};
            parse_path($param, $info);
            push @$out, "MyPlot::fill();";
            return 0;
        }
        elsif($func =~/^label/){
            if($param=~/^\[(.*?)\](.*)/){
                my ($param, $tail)=($1, $2);
                $tail=~s/^\s*[:,]?\s*//;
                my ($x1, $y1, $x2, $y2)=parse_edge($param);
                my @t;
                push @t, "x1=>$x1";
                push @t, "y1=>$y1";
                push @t, "x2=>$x2";
                push @t, "y2=>$y2";
                my @tlist=MyDef::utils::proper_split($tail);
                foreach my $t (@tlist){
                    if($t=~/"(.*)"/){
                        push @t, "label=>$t";
                    }
                }
                my $t=join(", ", @t);
                push @$out, "MyPlot::label_edge({$t});";
            }
            elsif($param=~/^</){
            }
            else{
                my $tail;
                if($param=~/(.*?):\s*(.*)/){
                    ($param, $tail)=($1, $2);
                }
                my ($x, $y)=parse_point($param);
                my @t;
                push @t, "x=>$x";
                push @t, "y=>$y";
                if($param=~/^z(\w+)/){
                    push @t, "label=>\"$1\"";
                }
                elsif($param=~/^(\w+_)z(\w+)/){
                    push @t, "label=>\"$1_$2\"";
                }
                else{
                    push @t, "label=>\"$param\"";
                }
                my $t=join(", ", @t);
                push @$out, "MyPlot::label_point({$t});";
            }
            return 0;
        }
        elsif($func eq "set_point"){
            return "CALLBACK set_point $param";
        }
        elsif($func eq "tex"){
            return "CALLBACK tex $param";
        }
        elsif($func eq "line" or $func eq "style"){
            parse_graphic_state($param, $func);
            return 0;
        }
        elsif($func eq "group"){
            check_default("draw");
            push @g_stack, $g_hash;
            my %t=%$g_hash;
            $g_hash=\%t;
            $g_hash->{cm}=undef;
            $g_hash->{macro}={};
            push @$out, "MyPlot::save_state();";
            parse_graphic_state($param, "group");
            my @src;
            push @src, "BLOCK";
            push @src, "\$ungroup";
            MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
            return "NEWBLOCK-group";
        }
        elsif($func eq "ungroup"){
            $g_hash=pop @g_stack;
            push @$out, "MyPlot::restore_state();";
            return 0;
        }
    }
    return MyDef::output_perl::parsecode($l);
}
sub dumpout {
    my ($f, $out, $pagetype)=@_;
    MyDef::output_perl::dumpout($f, $out, $pagetype);
}
1;
