use strict;
package MyDef::utils;
our $time_start = time();

sub get_tlist {
    my ($t) = @_;
    my @vlist = split /,\s*/, $t;
    my @tlist;
    foreach my $v (@vlist){
        if($v=~/^(\w+)\.\.(\w+)$/){
            push @tlist, get_range($1, $2);
        }
        elsif($v=~/^(\w+)-(\w+)$/){
            push @tlist, get_range($1, $2);
        }
        else{
            push @tlist, $v;
        }
    }
    return @tlist;
}

sub get_range {
    my ($a, $b) = @_;
    my @tlist;
    if($a=~/^\d+$/ and $b=~/^\d+$/){
        if($a<=$b){
            for(my $i=$a;$i<=$b;$i++){
                push @tlist, $i;
            }
        }
        else{
            for(my $i=$a;$i>=$b;$i--){
                push @tlist, $i;
            }
        }
    }
    elsif($a=~/^[a-zA-Z]$/ and $b=~/^[a-zA-Z]$/){
        ($a, $b) = (ord($a), ord($b));
        if($a<=$b){
            for(my $i=$a;$i<=$b;$i++){
                push @tlist, chr($i);
            }
        }
        else{
            for(my $i=$a;$i>=$b;$i--){
                push @tlist, chr($i);
            }
        }
    }
    elsif($a=~/^0x(\d+)$/ and $b=~/^\d+$/){
        $a = $1;
        if($a>0){
            $a-=1;
            $b-=1;
        }
        if($a<=$b){
            for(my $i=$a;$i<=$b;$i++){
                push @tlist, sprintf("0x%x", 1<<$i);
            }
        }
        else{
            for(my $i=$a;$i>=$b;$i--){
                push @tlist, sprintf("0x%x", 1<<$i);
            }
        }
    }
    return @tlist;
}

sub for_list_expand {
    my ($pat, $list) = @_;
    my @vlist=split /\s+and\s+/, $list;
    my @tlist;
    foreach my $v (@vlist){
        my @t = MyDef::utils::get_tlist($v);
        push @tlist, \@t;
    }
    my $n = @{$tlist[0]};
    my $m = @tlist;
    my @plist;
    if($pat!~/\$\d/ && $m==1 && $pat=~/\*/){
        foreach my $t (@{$tlist[0]}){
            my $l = $pat;
            $l =~s/\*/$t/g;
            push @plist, $l;
        }
    }
    else{
        for(my $i=0; $i <$n; $i++){
            my $l = $pat;
            my $j=1;
            foreach my $tlist (@tlist){
                $l=~s/\$$j/$tlist->[$i]/g;
                $j++;
            }
            push @plist, $l;
        }
    }
    return \@plist;
}

sub smart_split {
    my ($param, $n) = @_;
    my @tlist = split /,\s*/, $param;
    if($n==@tlist){
        return @tlist;
    }
    else{
        return proper_split($param);
    }
}

sub proper_split {
    my ($param) = @_;
    my @tlist;
    if($param eq "0"){
        return (0);
    }
    elsif(!$param){
        return @tlist;
    }
    my @closure_stack;
    my $t;
    ;
    while(1){
        if($param=~/\G$/sgc){
            last;
        }
        elsif($param=~/\G(\s+)/sgc){
            if($t or @closure_stack){
                $t.=$1;
            }
            else{
            }
        }
        elsif($param=~/\G(,)/gc){
            if(@closure_stack){
                $t.=$1;
            }
            else{
                push @tlist, $t;
                undef $t;
            }
        }
        elsif($param=~/\G([^"'\(\[\{\)\]\},]+)/gc){
            $t.=$1;
        }
        elsif($param=~/\G("([^"\\]|\\.)*")/gc){
            $t.=$1;
        }
        elsif($param=~/\G('([^'\\]|\\.)*')/gc){
            $t.=$1;
        }
        elsif($param=~/\G([\(\[\{])/gc){
            $t.=$1;
            push @closure_stack, $1;
        }
        elsif($param=~/\G([\)\]\}])/gc){
            $t.=$1;
            if(@closure_stack){
                my $match;
                if($1 eq ')'){
                    $match='(';
                }
                elsif($1 eq ']'){
                    $match='[';
                }
                elsif($1 eq '}'){
                    $match='{';
                }
                my $pos=-1;
                for(my $i=0; $i <@closure_stack; $i++){
                    if($match==$closure_stack[$i]){
                        $pos=$i;
                    }
                }
                if($pos>=0){
                    splice(@closure_stack, $pos);
                }
                else{
                    warn "proper_split: unbalanced [$param]\n";
                }
            }
        }
        elsif($param=~/\G(.)/gc){
            my $curfile=MyDef::compileutil::curfile_curline();
            print "[$curfile]proper_split: unmatched $1 [$param]\n";
            $t.=$1;
        }
    }
    if($t){
        $t=~s/\s+$//;
    }
    if($t or @tlist){
        push @tlist, $t;
    }
    return @tlist;
}

sub expand_macro {
    my ($line, $sub) = @_;
    my @paren_stack;
    my $segs=[];
    ;
    while(1){
        if($line=~/\G$/sgc){
            last;
        }
        elsif($line=~/\G\$\(/sgc){
            push @paren_stack, $segs;
            $segs=[];
            push @paren_stack, "\$\(";
        }
        elsif($line=~/\G\$\./sgc){
            push @$segs, $sub->("this");
        }
        elsif($line=~/\G([\x80-\xff]+)/sgc){
            my $t = MyDef::compileutil::get_macro_word($1, 1);
            if($t){
                $MyDef::compileutil::n_get_macro++;
                push @$segs, $t;
            }
            else{
                push @$segs, $1;
            }
        }
        elsif(!@paren_stack){
            if($line=~/\G([^\$\x80-\xff]|\$(?![\(\.]))+/sgc){
                push @$segs, $&;
            }
        }
        else{
            if($line=~/\G\(/sgc){
                push @paren_stack, $segs;
                $segs=[];
                push @paren_stack, "(";
            }
            elsif($line=~/\G\)/sgc){
                my $t=join('', @$segs);
                my $open=pop @paren_stack;
                $segs=pop @paren_stack;
                if($open eq "(" or $t!~/^\w/){
                    push @$segs, "$open$t)";
                }
                else{
                    push @$segs, $sub->($t);
                }
            }
            elsif($line=~/\G([^\$\x80-\xff()]|\$(?![\(\.]))+/sgc){
                push @$segs, $&;
            }
        }
    }
    ;
    while(@paren_stack){
        my $t = join('', @$segs);
        my $open = pop @paren_stack;
        $segs = pop @paren_stack;
        push @$segs, $open;
        push @$segs, $t;
    }
    return join('', @$segs);
}

sub uniq_name {
    my ($name, $hash) = @_;
    if(!$hash->{$name}){
        return $name;
    }
    else{
        my $i=2;
        if($name=~/[0-9_]/){
            $name.="_";
        }
        ;
        while($hash->{"$name$i"}){
            $i++;
        }
        return "$name$i";
    }
}

sub string_symbol_name {
    my ($s) = @_;
    my $n=length($s);
    my $name="";
    for(my $i=0; $i <$n; $i++){
        my $c = substr($s, $i, 1);
        if($c=~/\w/){
            $name.=$c;
        }
        elsif($c eq "+"){
            $name.="Plus";
        }
        elsif($c eq "-"){
            $name.="Minus";
        }
        elsif($c eq "*"){
            $name.="Mult";
        }
        elsif($c eq "/"){
            $name.="Div";
        }
        elsif($c eq "="){
            $name.="Eq";
        }
        elsif($c eq "!"){
            $name.="Emark";
        }
        elsif($c eq "~"){
            $name.="Tlide";
        }
        elsif($c eq "^"){
            $name.="Ctrl";
        }
        elsif($c eq "%"){
            $name.="Mod";
        }
        elsif($c eq ">"){
            $name.="Gt";
        }
        elsif($c eq "<"){
            $name.="Lt";
        }
        elsif($c eq "|"){
            $name.="Or";
        }
        elsif($c eq "&"){
            $name.="And";
        }
        elsif($c eq "("){
            $name.="Lp";
        }
        elsif($c eq ")"){
            $name.="Rp";
        }
        elsif($c eq "["){
            $name.="Lb";
        }
        elsif($c eq "]"){
            $name.="Rb";
        }
        elsif($c eq "{"){
            $name.="Lc";
        }
        elsif($c eq "}"){
            $name.="Rc";
        }
        elsif($c eq "\""){
            $name.="Dq";
        }
        elsif($c eq "'"){
            $name.="Sq";
        }
        elsif($c eq ","){
            $name.="Comma";
        }
        elsif($c eq "."){
            $name.="Dot";
        }
        elsif($c eq ":"){
            $name.="Colon";
        }
        elsif($c eq "?"){
            $name.="Qmark";
        }
        elsif($c eq ";"){
            $name.="Semi";
        }
        else{
            die "string_symbol_name: [$c] not defined\n";
        }
    }
    return $name;
}

sub parse_regex {
    my ($re, $flag_combine_chars) = @_;
    my @paren_stack;
    my $atoms=[];
    my $alts=[];
    my $has_Any=0;
    my $escape;
    my $_recurse="[1]";
    my $i=0;
    ;
    while($i<length($re)){
        my $c=substr($re, $i, 1);
        $i++;
        if(!$escape && $c eq "\\"){
            $escape=1;
            next;
        }
        elsif($escape){
            my $atom;
            if($c=~/[0aefnrt]/){
                if($c eq "a"){
                    $c= "\a";
                }
                elsif($c eq "e"){
                    $c= "\e";
                }
                elsif($c eq "f"){
                    $c= "\f";
                }
                elsif($c eq "n"){
                    $c= "\n";
                }
                elsif($c eq "r"){
                    $c= "\r";
                }
                elsif($c eq "t"){
                    $c= "\t";
                }
                elsif($c eq "0"){
                    $c= "\0";
                }
                $atom={type=>"char", char=>$c};
            }
            elsif($c=~/[sSdDwW]/){
                $atom={type=>"class", char=>$c};
            }
            else{
                $atom={type=>"char", char=>$c};
            }
            push @$atoms, $atom;
            $escape=0;
        }
        elsif($c eq '('){
            push @paren_stack, {atoms=>$atoms, alts=>$alts, type=>"group"};
            $atoms=[];
            $alts=[];
            if(substr($re, $i, 2) eq "?:"){
                $paren_stack[-1]->{type}="seq";
                $i+=2;
            }
            elsif(substr($re, $i, 2) eq "?="){
                $paren_stack[-1]->{type}="?=";
                $i+=2;
            }
            elsif(substr($re, $i, 2) eq "?!"){
                $paren_stack[-1]->{type}="?!";
                $i+=2;
            }
        }
        elsif($c eq ')'){
            {
                my $type="seq";
                $type=$paren_stack[-1]->{type};
                my $n=@$atoms;
                if($n==0){
                    warn "regex_parse: empty group\n";
                    push @$alts, undef;
                }
                else{
                    if($flag_combine_chars){
                        my @tlist;
                        my $last;
                        push @$atoms, {type=>"end"};
                        foreach my $t (@$atoms){
                            if(!$last){
                                $last=$t;
                            }
                            elsif($t->{type} ne "char" or $last->{type} ne "char"){
                                push @tlist, $last;
                                $last=$t;
                            }
                            else{
                                $last->{char}.=$t->{char};
                            }
                        }
                        $atoms=\@tlist;
                        $n=@$atoms;
                    }
                    if($type ne "seq"){
                        push @$alts, {type=>$type, n=>$n, list=>$atoms};
                        $atoms=[];
                    }
                    else{
                        my $atom;
                        if($n==1){
                            $atom=pop @$atoms;
                        }
                        else{
                            $atom={type=>"seq", n=>$n, list=>$atoms};
                            $atoms=[];
                        }
                        push @$alts, $atom;
                    }
                }
            }
            my $atom;
            my $n=@$alts;
            if($n==1){
                $atom=pop @$alts;
            }
            elsif($n>1){
                $atom={type=>"alt", n=>$n, list=>$alts};
                $alts=[];
            }
            my $p=pop @paren_stack;
            if(!$p){
                die "REGEX $re: Unmatched parenthesis\n";
            }
            $atoms=$p->{atoms};
            $alts=$p->{alts};
            push @$atoms, $atom;
        }
        elsif($c eq '|'){
            {
                my $type="seq";
                my $n=@$atoms;
                if($n==0){
                    warn "regex_parse: empty alt\n";
                    push @$alts, undef;
                }
                else{
                    if($flag_combine_chars){
                        my @tlist;
                        my $last;
                        push @$atoms, {type=>"end"};
                        foreach my $t (@$atoms){
                            if(!$last){
                                $last=$t;
                            }
                            elsif($t->{type} ne "char" or $last->{type} ne "char"){
                                push @tlist, $last;
                                $last=$t;
                            }
                            else{
                                $last->{char}.=$t->{char};
                            }
                        }
                        $atoms=\@tlist;
                        $n=@$atoms;
                    }
                    if($type ne "seq"){
                        push @$alts, {type=>$type, n=>$n, list=>$atoms};
                        $atoms=[];
                    }
                    else{
                        my $atom;
                        if($n==1){
                            $atom=pop @$atoms;
                        }
                        else{
                            $atom={type=>"seq", n=>$n, list=>$atoms};
                            $atoms=[];
                        }
                        push @$alts, $atom;
                    }
                }
            }
        }
        elsif($c eq '*' or $c eq '+' or $c eq '?'){
            if(!@$atoms){
                die "REGEX $re: Empty '$c'\n";
            }
            if(substr($re, $i, 1) eq "?"){
                print "Non-Greedy quantifier not supported!\n";
                $c.='?';
                $i++;
            }
            my $t=pop @$atoms;
            push @$atoms, {type=>$c, atom=>$t};
        }
        elsif($c eq '['){
            my @class=();
            my $escape;
            my $_recurse="[2]";
            ;
            while($i<length($re)){
                my $c=substr($re, $i, 1);
                $i++;
                if(!$escape && $c eq "\\"){
                    $escape=1;
                    next;
                }
                elsif($escape){
                    if($c=~/[0aefnrt]/){
                        if($c eq "a"){
                            $c= "\a";
                        }
                        elsif($c eq "e"){
                            $c= "\e";
                        }
                        elsif($c eq "f"){
                            $c= "\f";
                        }
                        elsif($c eq "n"){
                            $c= "\n";
                        }
                        elsif($c eq "r"){
                            $c= "\r";
                        }
                        elsif($c eq "t"){
                            $c= "\t";
                        }
                        elsif($c eq "0"){
                            $c= "\0";
                        }
                    }
                    elsif($c=~/[sSdDwW]/){
                        $c = "\\$c";
                    }
                    push @class, $c;
                    $escape=0;
                }
                elsif($c eq ']'){
                    last;
                }
                else{
                    if(@class>=2 and $class[-1] eq "-"){
                        pop @class;
                        $class[-1].="-$c";
                    }
                    else{
                        push @class, $c;
                    }
                }
            }
            my $atom={type=>"class", list=>\@class};
            push @$atoms, $atom;
        }
        elsif($c eq '.'){
            my $atom={type=>"AnyChar"};
            if(substr($re, $i, 1) eq "*"){
                $atom->{type}="Any";
                $has_Any++;
                $i++;
            }
            push @$atoms, $atom;
        }
        else{
            my $atom={type=>"char", char=>$c};
            push @$atoms, $atom;
        }
    }
    if(@paren_stack){
        die "REGEX $re: Unmatched parenthesis\n";
    }
    {
        my $type="seq";
        my $n=@$atoms;
        if($n==0){
            warn "regex_parse: empty final\n";
            push @$alts, undef;
        }
        else{
            if($flag_combine_chars){
                my @tlist;
                my $last;
                push @$atoms, {type=>"end"};
                foreach my $t (@$atoms){
                    if(!$last){
                        $last=$t;
                    }
                    elsif($t->{type} ne "char" or $last->{type} ne "char"){
                        push @tlist, $last;
                        $last=$t;
                    }
                    else{
                        $last->{char}.=$t->{char};
                    }
                }
                $atoms=\@tlist;
                $n=@$atoms;
            }
            if($type ne "seq"){
                push @$alts, {type=>$type, n=>$n, list=>$atoms};
                $atoms=[];
            }
            else{
                my $atom;
                if($n==1){
                    $atom=pop @$atoms;
                }
                else{
                    $atom={type=>"seq", n=>$n, list=>$atoms};
                    $atoms=[];
                }
                push @$alts, $atom;
            }
        }
    }
    my $atom;
    my $n=@$alts;
    if($n==1){
        $atom=pop @$alts;
    }
    elsif($n>1){
        $atom={type=>"alt", n=>$n, list=>$alts};
        $alts=[];
    }
    if($has_Any){
        $atom->{has_Any}=$has_Any;
    }
    return $atom;
}

sub debug_regex {
    my ($r, $level) = @_;
    if(!$level){
        $level=0;
    }
    print '  ' x $level;
    if($r->{type} eq "class"){
        if($r->{list}){
            print "[ ", join(" ", @{$r->{list}}), " ]\n";
        }
        else{
            print "\\ $r->{char}\n";
        }
    }
    elsif($r->{type} eq "char"){
        print "$r->{char}\n";
    }
    elsif($r->{type} eq "AnyChar"){
        print ".\n";
    }
    else{
        print "$r->{type}\n";
        if($r->{list}){
            foreach my $t (@{$r->{list}}){
                debug_regex($t, $level+1);
            }
        }
        elsif($r->{atom}){
            debug_regex($r->{atom}, $level+1);
        }
    }
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

1;
