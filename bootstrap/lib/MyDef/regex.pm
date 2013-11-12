package MyDef::regex;
sub parse_regex_match {
    my ($re, $out, $init, $var, $pos, $end)=@_;
    my $regex=parse_regex($re);
    my ($startstate, $straight)=build_nfa($regex);
    if($straight){
        my $p=["and"];
        my @threadstack;
        push @threadstack, {state=>$startstate, offset=>0, output=>$p};
        while(my $thread=pop @threadstack){
            my $s=$thread->{state};
            my $off=$thread->{offset};
            my $rout=$thread->{output};
            while(1){
                if($s->{c} eq "Match"){
                    last;
                }
                elsif($s->{c} eq "Split"){
                    my ($s1, $s2)=(["and"], ["and"]);
                    push @$rout, ["or", $s1, $s2];
                    push @threadstack, {state=>$s->{"out1"}, offset=>$off, output=>$s1};
                    push @threadstack, {state=>$s->{"out2"}, offset=>$off, output=>$s2};
                    last;
                }
                elsif($s->{c} eq "AnyChar"){
                    $s=$s->{"out1"};
                    $off++;
                }
                elsif($s->{c} eq "Class"){
                    $s=$s->{"out1"};
                    $off++;
                }
                else{
                    my $position="$pos+$off";
                    if(!$pos){
                        $position=$off;
                    }
                    elsif($pos=~/^\d+/){
                        $position=$pos+$off;
                    }
                    if($s->{c} =~/^-(.)(.)/){
                        push @$rout, "$var\[$position\]>='$1' && $var\[$position\]<='$2'";
                    }
                    elsif($s->{c} eq "'"){
                        push @$rout, "$var\[$position\]=='\\''";
                    }
                    else{
                        push @$rout, "$var\[$position\]=='$s->{c}'";
                    }
                    $s=$s->{"out1"};
                    $off++;
                }
            }
        }
        return regex_straight($p);
    }
    else{
        if(!$end){die "regex $var [$pos] missing range\n";};
        $init->();
        my $n=dump_vm_c(build_vm($startstate), $out);
        my $strstart="$var+$pos";
        if(!$pos){ $strstart=$var;};
        my $strend="$var+$end";
        return "regex_vm_match(nfa, $n, $strstart, $strend)";
    }
}
sub regex_straight {
    my $a=shift;
    if(!ref($a)){
        return $a;
    }
    elsif(ref($a) eq "ARRAY"){
        my $t=shift(@$a);
        my $sep;
        my @tlist;
        foreach my $b(@$a){
            push @tlist, regex_straight($b);
        }
        if($t eq "and"){
            if(@tlist==1 and $tlist[0]=~/^\((.*)\)$/){
                return $1;
            }
            else{
                return join(" && ", @tlist);
            }
        }
        elsif($t eq "or"){
            return "(".join(" || ", @tlist).")";
        }
    }
}
sub dump_vm_c {
    my ($vm, $out)=@_;
    my $n=@$vm;
    push @$out, "struct VMInst* nfa;";
    push @$out, "nfa=(struct VMInst[$n]) {";
    my $i=0;
    foreach my $l(@$vm){
        if($l->[0] eq "Match"){
            push @$out, "    Match, 0, 0, 0,";
        }
        elsif($l->[0] eq "Char"){
            my $c="'$l->[1]'";
            push @$out, "    Char, $c, 0, 0,";
        }
        elsif($l->[0] eq "Split"){
            push @$out, "    Split, 0, $l->[2], $l->[3],";
        }
        elsif($l->[0] eq "Jmp"){
            push @$out, "    Jmp, 0,  $l->[2], 0,";
        }
        elsif($l->[0] eq "AnyChar"){
            push @$out, "    AnyChar, 0, 0, 0,";
        }
        $i++;
    }
    push @$out, "};";
    return $n;
}
sub print_vm {
    my $vm=shift;
    my $i=0;
    foreach my $l(@$vm){
        if($l->[4]){
            print "$i:";
        }
        if($l->[0] eq "Match"){
            print "\tMatch\n";
        }
        elsif($l->[0] eq "Char"){
            print "\tChar $l->[1]\n";
        }
        elsif($l->[0] eq "Split"){
            print "\tSplit $l->[2], $l->[3]\n";
        }
        elsif($l->[0] eq "Jmp"){
            print "\tJmp $l->[2]\n";
        }
        elsif($l->[0] eq "AnyChar"){
            print "\tAnyChar\n";
        }
        $i++;
    }
}
sub build_vm {
    my $startstate=shift;
    my @threadstack;
    push @threadstack, $startstate;
    my $count;
    my @output;
    my %history;
    my %labelhash;
    while(my $s=pop @threadstack){
        if(defined $history{$s}){
            next;
        }
        while(1){
            if(defined $history{$s}){
                push @output, ["Jmp", undef, $s, undef];
                $labelhash{$s}=1;
                last;
            }
            else{
                $history{$s}=$#output+1;
                if($s->{c} eq "Match"){
                    push @output,  ["Match", undef, undef, undef];
                    last;
                }
                elsif($s->{c} eq "Split"){
                    push @output, ["Split", undef, $s->{out1}, $s->{out2}];
                    push @threadstack, $s->{out1};
                    push @threadstack, $s->{out2};
                    $labelhash{$s->{out1}}=1;
                    $labelhash{$s->{out2}}=1;
                    last;
                }
                elsif($s->{c} eq "AnyChar"){
                    push @output,  ["AnyChar", undef, undef, undef];
                    $s=$s->{out1};
                }
                else{
                    push @output,  ["Char", $s->{c}, undef, undef];
                    $s=$s->{out1};
                }
                $count++;
                if($count>1000){die "deadloop\n";};
            }
        }
    }
    foreach my $l (@output){
        if($l->[0] eq "Jmp"){
            $l->[2]=$history{$l->[2]};
        }
        elsif($l->[0] eq "Split"){
            $l->[2]=$history{$l->[2]};
            $l->[3]=$history{$l->[3]};
        }
    }
    foreach my $s (keys %labelhash){
        $output[$history{$s}]->[4]=1;
    }
    return \@output;
}
sub build_nfa {
    my $src=shift;
    if(ref($src) ne "ARRAY"){die "build_nfa error.\n"};
    my @states;
    my @fragstack;
    my $straight=1;
    my $match={idx=>0, c=>"Match"};
    my $state_idx=1;
    foreach my $c(@$src){
        if($c eq "]."){
            my $e2=pop @fragstack;
            my $e1=pop @fragstack;
            my $e1out=$e1->{out};
            foreach $out (@$e1out){
                my $s=$out->{state};
                $s->{$out->{arrow}}=$e2->{start};
            }
            push @fragstack, {start=>$e1->{start}, out=>$e2->{out}};
        }
        elsif($c eq "]|"){
            my $e2=pop @fragstack;
            my $e1=pop @fragstack;
            my $state={idx=>$state_idx, c=>"Split", out1=>$e1->{start}, out2=>$e2->{start}};
            push @states, $state; $state_idx++;
            my $e1out=$e1->{out};
            my $e2out=$e2->{out};
            foreach my $out (@$e2out){
                push @$e1out, $out;
            }
            push @fragstack, {start=>$state, out=>$e1out};
        }
        elsif($c eq "]?"){
            my $e=pop @fragstack;
            my $point;
            my $state={idx=>$state_idx, c=>"Split", out1=>$e->{start}};
            push @states, $state; $state_idx++;
            my $eout=$e->{out};
            push @$eout, {state=>$state, arrow=>"out2"};
            push @fragstack, {start=>$state, out=>$eout};
            $straight=0;
        }
        elsif($c eq "]*"){
            my $e=pop @fragstack;
            my $point;
            my $state={idx=>$state_idx, c=>"Split", out1=>$e->{start}};
            push @states, $state; $state_idx++;
            my $eout=$e->{out};
            foreach $out (@$eout){
                $out->{state}->{$out->{arrow}}=$state;
            }
            push @fragstack, {start=>$state, out=>[{state=>$state, arrow=>"out2"}]};
            $straight=0;
        }
        elsif($c eq "]+"){
            my $e=pop @fragstack;
            my $point;
            my $state={idx=>$state_idx, c=>"Split", out1=>$e->{start}};
            push @states, $state; $state_idx++;
            my $eout=$e->{out};
            foreach $out (@$eout){
                $out->{state}->{$out->{arrow}}=$state;
            }
            push @fragstack, {start=>$e->{start}, out=>[{state=>$state, arrow=>"out2"}]};
            $straight=0;
        }
        else{
            my $state={idx=>$state_idx, c=>$c};
            push @states, $state; $state_idx++;
            push @fragstack, {start=>$state, out=>[{state=>$state, arrow=>"out1"}]};
        }
    }
    my $e=pop @fragstack;
    if(@fragstack){die "Unbalanced fragstack\n";};
    my $eout=$e->{out};
    foreach my $out (@$eout){
        $out->{state}->{$out->{arrow}}=$match;
    }
    return ($e->{start}, $straight);
}
sub parse_regex {
    my $re=shift;
    my $relen=length($re);
    my $natom=0;
    my $nalt=0;
    my @parenlist;
    my @dst;
    my $escape;
    my @class;
    my $inclass;
    for(my $i=0; $i<$relen; $i++){
        my $c=substr($re, $i, 1);
        if($inclass){
            my $c2=substr($re, $i+2, 1);
            if(substr($re, $i+1, 1) eq "-"){
                push @class, "-$c$c2";
                $i+=2;
            }
            elsif($escape){
                if($c =~/[tnr']/){
                    push @class, "\\$c";
                }
                elsif($c eq '\\'){
                    push @class, "\\\\";
                }
                else{
                    push @class, $c;
                }
                $escape=0;
            }
            elsif($c eq "\\"){
                $escape=1;
            }
            elsif($c eq ']'){
                foreach my $t (@class){
                    push @dst, $t;
                }
                for(my $i=0; $i<@class-1; $i++){
                    push @dst, "]|";
                }
                $inclass=0;
            }
            else{
                push @class, $c;
            }
        }
        else{
            if($escape){
                if($c =~/[tnr']/){
                    $c="\\$c";
                }
                elsif($c eq 'd'){
                    $c="-09";
                }
                elsif($c =~/[()*+?|.\]\[]/){
                    $c="]$c";
                }
                elsif($c eq '\\'){
                    $c="]\\\\";
                }
                else{
                }
                $escape=0;
            }
            if($c eq "\\"){
                $escape=1;
            }
            elsif($c eq '['){
                for (my $i=0; $i<$natom-1; $i++){ push @dst, "]."; };
                if(!$natom){ $natom=1; } else{ $natom=2; };
                @class=();
                $inclass=1;
            }
            elsif($c eq '('){
                for (my $i=0; $i<$natom-1; $i++){ push @dst, "]."; };
                push @parenlist, {nalt=>$nalt, natom=>$natom};
                $natom=0;
                $nalt=0;
            }
            elsif($c eq ')'){
                for (my $i=0; $i<$natom-1; $i++){ push @dst, "]."; };
                for(my $i=0; $i<$nalt; $i++){ push @dst, "]|"; };
                my $p=pop @parenlist;
                if(!$p){
                    die "REGEX $re: Unmatched parenthesis\n";
                }
                if(!$natom){
                    die "REGEX $re: Empty parenthesis\n";
                }
                $natom=$p->{natom};
                $nalt=$p->{nalt};
                $natom++;
            }
            elsif($c eq '|'){
                if(!$natom){
                    die "REGEX $re: Empty alternations\n";
                }
                for (my $i=0; $i<$natom-1; $i++){ push @dst, "]."; };
                $natom=0;
                $nalt++;
            }
            elsif($c eq '*' or $c eq '+' or $c eq '?'){
                if(!$natom){
                    die "REGEX $re: Empty '$c'\n";
                }
                push @dst, "]$c";
            }
            else{
                for (my $i=0; $i<$natom-1; $i++){ push @dst, "]."; };
                if($c=~/](.+)/){
                    $c=$1;
                }
                elsif($c eq '.'){
                    $c = "AnyChar";
                }
                push @dst, $c;
                if(!$natom){ $natom=1; } else{ $natom=2; };
            }
        }
    }
    if(@parenlist){
        die "REGEX $re: Unmatched parenthesis\n";
    }
    for (my $i=0; $i<$natom-1; $i++){ push @dst, "]."; };
    for(my $i=0; $i<$nalt; $i++){ push @dst, "]|"; };
    return \@dst;
}
sub add_regex_vm_code{
    my ($out, $n, $var, $end)=@_;
    push @$out, "void add_vm_thread(int* tlist, int thread){";
    push @$out, "    int i;";
    push @$out, "    for(i=0;i<tlist[0];i++){";
    push @$out, "        if(tlist[i+1]==thread){";
    push @$out, "            return;";
    push @$out, "        }";
    push @$out, "    }";
    push @$out, "    tlist[0]++;";
    push @$out, "    tlist[tlist[0]]=thread;";
    push @$out, "}";
    push @$out, "";
    push @$out, "int regex_vm_match(struct VMInst* nfa, int nfasize, char* s, char* end){";
    push @$out, "    struct VMInst* pc;";
    push @$out, "    int* clist=(int*)malloc((nfasize+1)*sizeof(int));";
    push @$out, "    int* nlist=(int*)malloc((nfasize+1)*sizeof(int));";
    push @$out, "    int* tlist;";
    push @$out, "    clist[0]=0;";
    push @$out, "    nlist[0]=0;";
    push @$out, "    add_vm_thread(clist, 0);";
    push @$out, "    char * sp;";
    push @$out, "    int i;";
    push @$out, "    for(sp=s; sp<end; sp++){";
    push @$out, "        for(i=1; i<clist[0]+1; i++){";
    push @$out, "            pc=nfa+clist[i];";
    push @$out, "            switch(pc->opcode){";
    push @$out, "            case Char:";
    push @$out, "                if(*sp != pc->c)";
    push @$out, "                    break;";
    push @$out, "                add_vm_thread(nlist, clist[i]+1);";
    push @$out, "                break;";
    push @$out, "            case AnyChar:";
    push @$out, "                add_vm_thread(nlist, clist[i]+1);";
    push @$out, "                break;";
    push @$out, "            case Match:";
    push @$out, "                free(clist);";
    push @$out, "                free(nlist);";
    push @$out, "                return 1;";
    push @$out, "            case Jmp:";
    push @$out, "                add_vm_thread(clist, pc->x);";
    push @$out, "                break;";
    push @$out, "            case Split:";
    push @$out, "                add_vm_thread(clist, pc->x);";
    push @$out, "                add_vm_thread(clist, pc->y);";
    push @$out, "                break;";
    push @$out, "            }";
    push @$out, "         }";
    push @$out, "         tlist=nlist; nlist=clist; clist=tlist;";
    push @$out, "         nlist[0]=0;";
    push @$out, "    }";
    push @$out, "    free(clist);";
    push @$out, "    free(nlist);";
    push @$out, "    return 0;";
    push @$out, "}";
    push @$out, "";
    my $strvar=$var;
    my $size=$end;
    if($pos){
        $strvar="$var+$pos";
        $size=$end-$pos;
    }
}
1;
