use strict;
package MyDef::output_perl;
our @scope_stack;
our $cur_scope;
our $global_scope;
our $debug=0;
our $out;
our $mode;
our $page;
our @globals;
our %globals;
our @uses;
our %uses;
our $case_if="if";
our $case_elif="elsif";
our @case_stack;
our $case_state;
our $case_wrap;
our $case_flag="\$b_flag_case";
our $fn_block=[];
our $loop_idx;

sub parse_condition {
    my ($t) = @_;
    if($t=~/[!=]~/){
    }
    elsif($t=~/[^!=><]=[^="]/){
        my $curfile=MyDef::compileutil::curfile_curline();
        print "[$curfile]\x1b[33m assignment in condition [$t]?\n\x1b[0m";
    }
    elsif($t=~/\$(?:eq|ne)/){
        if($t=~/(.*?)(\S+)\s+(\$eq|\$ne)\s+(.*)/){
            if($3 eq '$eq'){
                $t=$1."$2 && $2 eq $4";
            }
            else{
                $t=$1."!$2 || $2 ne $4";
            }
        }
    }
    return $t;
}

sub inject_function {
    my ($name, $params, $source) = @_;
    my $t_code={'type'=>"fn", name=>$name, params=>$params, 'source'=>$source};
    $MyDef::def->{codes}->{$name}=$t_code;
}

sub sumcode_generate {
    my ($h) = @_;
    my $left = $h->{left};
    my $right = $h->{right};
    my $left_idx = $h->{left_idx};
    my $right_idx = $h->{right_idx};
    my $klist = $h->{klist};
    my %k_calc_hash;
    my %k_inc_hash;
    my %k_init_hash;
    my @allidx=(@$left_idx, @$right_idx);
    EACH_K:
    foreach my $k (@$klist){
        my $pos;
        my $i=$#allidx;
        while($i>=0){
            $pos=index($k, $allidx[$i]);
            if($pos>=0){
                last;
            }
            $i--;
        }
        if(index(substr($k, $pos+1), $allidx[$i])>=0){
            $k_calc_hash{"$k-$allidx[$i]"}=1;
            next EACH_K;
        }
        else{
            $k_inc_hash{"$k-$allidx[$i]"}=1;
            $pos--;
            $i--;
            while($pos>=0 and $i>=0 and substr($k, $pos, 1) eq $allidx[$i]){
                if(index(substr($k, $pos+1), $allidx[$i])>=0 or ($pos>0 && index(substr($k, 0, $pos), $allidx[$i])>=0)){
                    $k_calc_hash{"$k-$allidx[$i]"}=1;
                    next EACH_K;
                }
                $pos--;
                $i--;
            }
            if($i>=0){
                $k_calc_hash{"$k-$allidx[$i]"}=1;
            }
            else{
                $k_init_hash{$k}=1;
            }
        }
    }
    my @code;
    my %loop_i_hash;
    my %loop_k_hash;
    foreach my $k (@$klist){
        my $kvar=$h->{"$k-var"};
        if($k_init_hash{$k}){
            push @code, $h->{"$k-init"};
            push @code, "$kvar = 0";
            $loop_k_hash{$k}=1;
        }
    }
    foreach my $i (@$left_idx){
        $loop_i_hash{$i}=1;
        my $dim=$h->{"$i-dim"};
        my $var=$h->{"$i-var"};
        push @code, "\$for $var=0:$dim";
        push @code, "SOURCE_INDENT";
        foreach my $k (@$klist){
            my $kvar=$h->{"$k-var"};
            if($k_calc_hash{"$k-$i"}){
                if(!$loop_k_hash{$k}){
                    push @code, $h->{"$k-init"};
                    $loop_k_hash{$k}=1;
                }
                my $t;
                for(my $j=0; $j <length($k)-1; $j++){
                    my $idx=substr($k, $j, 1);
                    if($loop_i_hash{$idx}){
                        my $dim=$h->{substr($k, $j+1, 1)."-dim"};
                        my $var=$h->{"$idx-var"};
                        if(!$t){
                            $t = "$var*$dim";
                        }
                        else{
                            $t = "($t+$var)*$dim";
                        }
                    }
                }
                my $idx=substr($k, -1, 1);
                if($loop_i_hash{$idx}){
                    my $var=$h->{"$idx-var"};
                    $t.="+$var";
                }
                if(!$t){
                    $t = "0";
                }
                push @code, "$kvar = $t";
            }
        }
    }
    if(@$right_idx){
        my $sum=$h->{sum};
        push @code, $h->{"sum-init"};
        foreach my $i (@$right_idx){
            $loop_i_hash{$i}=1;
            my $dim=$h->{"$i-dim"};
            my $var=$h->{"$i-var"};
            push @code, "\$for $var=0:$dim";
            push @code, "SOURCE_INDENT";
            foreach my $k (@$klist){
                my $kvar=$h->{"$k-var"};
                if($k_calc_hash{"$k-$i"}){
                    if(!$loop_k_hash{$k}){
                        push @code, $h->{"$k-init"};
                        $loop_k_hash{$k}=1;
                    }
                    my $t;
                    for(my $j=0; $j <length($k)-1; $j++){
                        my $idx=substr($k, $j, 1);
                        if($loop_i_hash{$idx}){
                            my $dim=$h->{substr($k, $j+1, 1)."-dim"};
                            my $var=$h->{"$idx-var"};
                            if(!$t){
                                $t = "$var*$dim";
                            }
                            else{
                                $t = "($t+$var)*$dim";
                            }
                        }
                    }
                    my $idx=substr($k, -1, 1);
                    if($loop_i_hash{$idx}){
                        my $var=$h->{"$idx-var"};
                        $t.="+$var";
                    }
                    if(!$t){
                        $t = "0";
                    }
                    push @code, "$kvar = $t";
                }
            }
        }
        push @code, "$sum += $right";
        foreach my $i (reverse @$right_idx){
            foreach my $k (@$klist){
                my $kvar=$h->{"$k-var"};
                if($k_inc_hash{"$k-$i"}){
                    if(substr($k, -1, 1) eq $i){
                        push @code, "$kvar++";
                    }
                    else{
                        my @tlist;
                        my $pos=index($k, $i);
                        $pos++;
                        while($pos<length($k)){
                            my $j=substr($k, $pos, 1);
                            my $dim=$h->{"$j-dim"};
                            push @tlist, $dim;
                            $pos++;
                        }
                        push @code, "$kvar += ".join("*", @tlist);
                    }
                }
            }
            push @code, "SOURCE_DEDENT";
        }
        if($left ne $sum){
            push @code, "$left = $sum";
        }
    }
    elsif($right){
        push @code, "$left = $right";
    }
    else{
        push @code, $left;
    }
    foreach my $i (reverse @$left_idx){
        foreach my $k (@$klist){
            my $kvar=$h->{"$k-var"};
            if($k_inc_hash{"$k-$i"}){
                if(substr($k, -1, 1) eq $i){
                    push @code, "$kvar++";
                }
                else{
                    my @tlist;
                    my $pos=index($k, $i);
                    $pos++;
                    while($pos<length($k)){
                        my $j=substr($k, $pos, 1);
                        my $dim=$h->{"$j-dim"};
                        push @tlist, $dim;
                        $pos++;
                    }
                    push @code, "$kvar += ".join("*", @tlist);
                }
            }
        }
        push @code, "SOURCE_DEDENT";
    }
    return \@code;
}

$global_scope={var_list=>[], var_hash=>{}, name=>"global"};
$cur_scope={var_list=>[], var_hash=>{}, name=>"default"};
push @scope_stack, $global_scope;
sub open_scope {
    my ($blk_idx, $scope_name)=@_;
    push @scope_stack, $cur_scope;
    $cur_scope={var_list=>[], var_hash=>{}, name=>$scope_name};
}
sub close_scope {
    my ($blk, $pre, $post)=@_;
    if(!$blk){
        $blk=$cur_scope;
    }
    if($blk->{return}){
        if(!$post){
            $post=MyDef::compileutil::get_named_block("_post");
        }
        push @$post, $blk->{return};
    }
    $cur_scope=pop @scope_stack;
}
sub find_var {
    my ($name)=@_;
    if($debug eq "type"){
        print "  cur_scope\[$cur_scope->{name}]: ";
        foreach my $v (@{$cur_scope->{var_list}}){
            print "$v, ";
        }
        print "\n";
        for(my $i=$#scope_stack; $i >=0; $i--){
            print "  scope $i\[$scope_stack[$i]->{name}]: ";
            foreach my $v (@{$scope_stack[$i]->{var_list}}){
                print "$v, ";
            }
            print "\n";
        }
    }
    if($cur_scope->{var_hash}->{$name}){
        return $cur_scope->{var_hash}->{$name};
    }
    for(my $i=$#scope_stack; $i >=0; $i--){
        if($scope_stack[$i]->{var_hash}->{$name}){
            return $scope_stack[$i]->{var_hash}->{$name};
        }
    }
    return undef;
}
sub get_interface {
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout);
}
sub init_page {
    my ($t_page)=@_;
    $page=$t_page;
    MyDef::set_page_extension("pl");
    my $init_mode="sub";
    if($page->{package} and !$page->{type}){
        MyDef::set_page_extension("pm");
    }
    elsif(!$page->{package} and $page->{type} && $page->{type} eq "pm"){
        $page->{package}=$page->{pagename};
    }
    @globals=();
    %globals=();
    @uses=();
    %uses=();
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
    elsif($l=~/^\$template\s*(.*)/){
        open In, $1 or die "Can't open template $1\n";
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
    elsif($l=~/^SUBBLOCK BEGIN (\d+) (.*)/){
        open_scope($1, $2);
        return;
    }
    elsif($l=~/^SUBBLOCK END (\d+) (.*)/){
        if($out->[-1]=~/^(return|break)/){
            $cur_scope->{return}=pop @$out;
        }
        close_scope();
        return;
    }
    if($debug eq "case"){
        my $level=@case_stack;
        print "        $level:[$case_state]$l\n";
    }
    if($l=~/^\$(if|elif|elsif|elseif|case)\s+(.*)$/){
        my $cond=$2;
        my $case=$case_if;
        if($1 eq "if"){
            if($case_wrap){
                push @$out, @$case_wrap;
                undef $case_wrap;
            }
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
        single_block("$case($cond){", "}");
        push @$out, "PARSE:CASEPOP";
        push @case_stack, {state=>"if", wrap=>$case_wrap};
        undef $case_state;
        undef $case_wrap;
        if($debug eq "case"){
            my $level=@case_stack;
            print "Entering case [$level]: $l\n";
        }
        return "NEWBLOCK-if";
    }
    elsif($l=~/^\$else/){
        if(!$case_state and $l!~/NoWarn/i){
            my $curfile=MyDef::compileutil::curfile_curline();
            print "[$curfile]\x1b[33m Dangling \$else\n\x1b[0m";
        }
        single_block("else{", "}");
        push @$out, "PARSE:CASEPOP";
        push @case_stack, {state=>undef, wrap=>$case_wrap};
        undef $case_state;
        undef $case_wrap;
        if($debug eq "case"){
            my $level=@case_stack;
            print "Entering case [$level]: $l\n";
        }
        return "NEWBLOCK-else";
    }
    elsif($l=~/^\&case\s+(.*)/){
        if(!$case_state){
            push @$out, "my \$b_flag_case=1;";
            MyDef::compileutil::call_sub($1, "\$call");
            single_block("if($case_flag){", "}");
        }
        else{
            push @$out, "else{";
            push @$out, "INDENT";
            push @$out, "my \$b_flag_case=1;";
            MyDef::compileutil::call_sub($1, "\$call");
            single_block("if($case_flag){", "}");
            push @$out, "DEDENT";
            if(!$case_wrap){
                $case_wrap=[];
            }
            push @$case_wrap, "}";
        }
        push @$out, "PARSE:CASEPOP";
        push @case_stack, {state=>"if", wrap=>$case_wrap};
        undef $case_state;
        undef $case_wrap;
        if($debug eq "case"){
            my $level=@case_stack;
            print "Entering case [$level]: $l\n";
        }
        return "NEWBLOCK-if";
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
                $case_wrap=$t_case->{wrap};
            }
            return 0;
        }
        elsif($l=~/^CASEEXIT/){
            push @$out, "my \$b_flag_case=0;";
            return 0;
        }
    }
    if(!$case_state){
        if($case_wrap){
            push @$out, @$case_wrap;
            undef $case_wrap;
        }
    }
    if($l=~/^\s*\$(\w+)\s*(.*)$/){
        my $func=$1;
        my $param=$2;
        if($func =~ /^global$/){
            $param=~s/\s*;\s*$//;
            my @tlist=MyDef::utils::proper_split($param);
            foreach my $v (@tlist){
                my ($name, $var);
                if($v=~/\@(\w+)\[(.*)\](.*)/){
                    $name=$1;
                    $v='@'.$1.$3;
                    $var={};
                    my @tlist=split /,\s*/, $2;
                    my $i=0;
                    foreach my $t (@tlist){
                        $i++;
                        $var->{"dim$i"}=$t;
                    }
                }
                my $t_name=$v;
                if($v=~/^(\S+)\s*=/){
                    $t_name=$1;
                }
                if(!$globals{$t_name}){
                    $globals{$t_name}=1;
                    push @globals, $v;
                }
                if($var){
                    $global_scope->{var_hash}->{$name}=$var;
                }
            }
            return 0;
        }
        elsif($func =~ /^my$/){
            $param=~s/\s*;\s*$//;
            my @tlist=MyDef::utils::proper_split($param);
            foreach my $v (@tlist){
                my ($name, $var);
                if($v=~/\@(\w+)\[(.*)\](.*)/){
                    $name=$1;
                    $v='@'.$1.$3;
                    $var={};
                    my @tlist=split /,\s*/, $2;
                    my $i=0;
                    foreach my $t (@tlist){
                        $i++;
                        $var->{"dim$i"}=$t;
                    }
                }
                push @$out, "my $v;";
                if($var){
                    $cur_scope->{var_hash}->{$name}=$var;
                }
            }
            return 0;
        }
        elsif($func =~ /^loopvar$/){
            my @tlist=MyDef::utils::proper_split($param);
            my $block=MyDef::compileutil::get_named_block("loop_$loop_idx");
            foreach my $v (@tlist){
                push @$block, "my $v;";
            }
            return 0;
        }
        elsif($func =~ /^use$/){
            $param=~s/\s*;\s*$//;
            my @tlist=MyDef::utils::proper_split($param);
            foreach my $v (@tlist){
                my $t_name=$v;
                if($v=~/^(\S+)\s*=/){
                    $t_name=$1;
                }
                if(!$uses{$t_name}){
                    $uses{$t_name}=1;
                    push @uses, $v;
                }
            }
            return 0;
        }
        elsif($func eq "sub"){
            if($param=~/^(\w+)\((.*)\)/){
                return single_block_pre_post(["sub $1 {", "INDENT", "my ($2)=\@_;"], ["DEDENT", "}"], "sub");
            }
            else{
                return single_block("sub $param {", "}", "sub");
            }
        }
        elsif($func =~ /^(while)$/){
            if($param=~/^(.*?);\s*(.*?);?\s*$/){
                return single_block_pre_post(["while($1){", "INDENT"], ["$2;", "DEDENT", "}"]);
            }
            else{
                return single_block("$1($param){", "}");
            }
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
                $param="my $var=$i0; $var $i1; $var$step";
                single_block("for($param){", "}");
                return "NEWBLOCK-for";
            }
        }
        elsif($func eq "foreach"){
            if($param=~/^(?:my\s+)?(\S+)\s+in\s+(.*)/){
                my ($var, $list)=($1, $2);
                if(!$var){
                    $var="\$i";
                }
                elsif($var=~/^(\w+)/){
                    $var='$'.$var;
                }
                return single_block("foreach my $var ($list){", "}", "foreach");
            }
            elsif($param=~/^(%.*)/){
                return single_block("while (my (\$k, \$v) = each $1){", "}", "foreach");
            }
            elsif($param=~/^(\S+),\s*(\S+)\s+in\s+(.*)/){
                my ($k, $v, $hash)=($1, $2, $3);
                return single_block("while (my ($k, $v)=each $hash){", "}", "foreach");
            }
        }
        elsif($func eq "boolhash"){
            if($param=~/^\((.*?)\)\s*(.*)/){
                my $v = $1;
                my @plist=split /,\s*/, $2;
                my @tlist;
                foreach my $t (@plist){
                    push @tlist, "$t=>1";
                }
                push @$out, "$v= (".join(', ', @tlist).");";
            }
            return 0;
        }
        elsif($func eq "sumcode" or $func eq "loop" or $func eq "sum"){
            if($param=~/^\((.*?)\)\s+(.*)/){
                my $dimstr=$1;
                $param=$2;
                my $h={};
                my ($left, $right);
                if($param=~/(.*?)\s*(?<![\+\-\*\/%&\|><=])=(?!=)\s*(.*)/){
                    ($left, $right)=($1, $2);
                }
                else{
                    $left=$param;
                }
                my @idxlist=('i','j','k','l');
                my @dimlist=MyDef::utils::proper_split($dimstr);
                my (@left_idx, @right_idx);
                foreach my $dim (@dimlist){
                    my $idx=shift @idxlist;
                    $h->{"$idx-dim"}=$dim;
                    $h->{"$idx-var"}="\$i_$idx";
                    if($left=~/\b$idx\b/){
                        push @left_idx, $idx;
                    }
                    else{
                        push @right_idx, $idx;
                    }
                }
                my (%k_hash, @k_list);
                my @segs=split /(\[[ijkl,]*?\])/, $left;
                foreach my $s (@segs){
                    if($s=~/^\[([ijkl,]*?)\]$/){
                        my @idxlist=split /,/, $1;
                        if(@idxlist > 1){
                            my $k=join('', @idxlist);
                            if(!$k_hash{$k}){
                                $k_hash{$k}=1;
                                push @k_list, $k;
                            }
                            $s="[\$k_$k\]";
                        }
                    }
                }
                $left=join '', @segs;
                $left=~s/\b([ijkl])\b/\$i_$1/g;
                if($right){
                    my @segs=split /(\[[ijkl,]*?\])/, $right;
                    foreach my $s (@segs){
                        if($s=~/^\[([ijkl,]*?)\]$/){
                            my @idxlist=split /,/, $1;
                            if(@idxlist > 1){
                                my $k=join('', @idxlist);
                                if(!$k_hash{$k}){
                                    $k_hash{$k}=1;
                                    push @k_list, $k;
                                }
                                $s="[\$k_$k\]";
                            }
                        }
                    }
                    $right=join '', @segs;
                    $right=~s/\b([ijkl])\b/\$i_$1/g;
                }
                $h->{left}=$left;
                $h->{left_idx}=\@left_idx;
                $h->{right}=$right;
                $h->{right_idx}=\@right_idx;
                $h->{klist} = \@k_list;
                foreach my $k (@k_list){
                    $h->{"$k-init"}="my \$k_$k";
                    $h->{"$k-var"}="\$k_$k";
                }
                if(@right_idx){
                    if($left=~/^(\$?\w+)$/){
                        $h->{sum}=$1;
                    }
                    else{
                        $h->{sum}="\$sum";
                    }
                    $h->{"sum-init"}="my $h->{sum} = 0";
                }
                my $codelist=sumcode_generate($h);
                MyDef::compileutil::parseblock({source=>$codelist, name=>"sumcode"});
                return;
            }
            elsif($func eq "sumcode"){
                my $h={};
                my ($left, $right);
                if($param=~/(.*?)\s*(?<![\+\-\*\/%&\|><=])=(?!=)\s*(.*)/){
                    ($left, $right)=($1, $2);
                }
                else{
                    $left=$param;
                }
                my (%k_hash, @k_list);
                my %var_hash;
                my (@left_idx, @right_idx);
                my @segs=split /(\w+\[[ijkl,]*?\])/, $left;
                foreach my $s (@segs){
                    if($s=~/^(\w+)\[([ijkl,]*?)\]$/){
                        if($var_hash{$s}){
                            $s=$var_hash{$s};
                        }
                        else{
                            my $t;
                            my ($v, $idx_str)=($1, $2);
                            my $var=find_var($v);
                            my @idxlist=split /,/, $idx_str;
                            if(@idxlist==1){
                                my $idx=$idx_str;
                                $t="$v\[\$i_$idx\]";
                            }
                            else{
                                my $k=join('', @idxlist);
                                if(!$k_hash{$k}){
                                    $k_hash{$k}=1;
                                    push @k_list, $k;
                                }
                                $t="$v\[\$k_$k\]";
                            }
                            my $i=0;
                            foreach my $idx (@idxlist){
                                $i++;
                                my ($dim, $inc);
                                if($var->{"dim$i"}){
                                    $dim=$var->{"dim$i"};
                                }
                                elsif($var->{"dimension"} and $i==1){
                                    $dim=$var->{"dimension"};
                                }
                                else{
                                    my $curfile=MyDef::compileutil::curfile_curline();
                                    print "[$curfile]\x1b[33m sumcode: var $v missing dimension $i\n\x1b[0m";
                                }
                                if(!$h->{"$idx-dim"}){
                                    push @left_idx, $idx;
                                    $h->{"$idx-dim"}=$dim;
                                    $h->{"$idx-var"}="\$i_$idx";
                                }
                                else{
                                    if($h->{"$idx-dim"} ne $dim){
                                        my $old_dim=$h->{"$idx-dim"};
                                        print "sumcode dimesnion mismatch: $old_dim != $dim\n";
                                    }
                                }
                            }
                            $var_hash{$s}=$t;
                            $s=$t;
                        }
                    }
                }
                $left=join '', @segs;
                $left=~s/\b([ijkl])\b/\$i_$1/g;
                if($right){
                    my @segs=split /(\w+\[[ijkl,]*?\])/, $right;
                    foreach my $s (@segs){
                        if($s=~/^(\w+)\[([ijkl,]*?)\]$/){
                            if($var_hash{$s}){
                                $s=$var_hash{$s};
                            }
                            else{
                                my $t;
                                my ($v, $idx_str)=($1, $2);
                                my $var=find_var($v);
                                my @idxlist=split /,/, $idx_str;
                                if(@idxlist==1){
                                    my $idx=$idx_str;
                                    $t="$v\[\$i_$idx\]";
                                }
                                else{
                                    my $k=join('', @idxlist);
                                    if(!$k_hash{$k}){
                                        $k_hash{$k}=1;
                                        push @k_list, $k;
                                    }
                                    $t="$v\[\$k_$k\]";
                                }
                                my $i=0;
                                foreach my $idx (@idxlist){
                                    $i++;
                                    my ($dim, $inc);
                                    if($var->{"dim$i"}){
                                        $dim=$var->{"dim$i"};
                                    }
                                    elsif($var->{"dimension"} and $i==1){
                                        $dim=$var->{"dimension"};
                                    }
                                    else{
                                        my $curfile=MyDef::compileutil::curfile_curline();
                                        print "[$curfile]\x1b[33m sumcode: var $v missing dimension $i\n\x1b[0m";
                                    }
                                    if(!$h->{"$idx-dim"}){
                                        push @right_idx, $idx;
                                        $h->{"$idx-dim"}=$dim;
                                        $h->{"$idx-var"}="\$i_$idx";
                                    }
                                    else{
                                        if($h->{"$idx-dim"} ne $dim){
                                            my $old_dim=$h->{"$idx-dim"};
                                            print "sumcode dimesnion mismatch: $old_dim != $dim\n";
                                        }
                                    }
                                }
                                $var_hash{$s}=$t;
                                $s=$t;
                            }
                        }
                    }
                    $right=join '', @segs;
                    $right=~s/\b([ijkl])\b/\$i_$1/g;
                }
                $h->{left}=$left;
                $h->{left_idx}=\@left_idx;
                $h->{right}=$right;
                $h->{right_idx}=\@right_idx;
                $h->{klist} = \@k_list;
                foreach my $k (@k_list){
                    $h->{"$k-init"}="my \$k_$k";
                    $h->{"$k-var"}="\$k_$k";
                }
                if(@right_idx){
                    if($left=~/^(\$?\w+)$/){
                        $h->{sum}=$1;
                    }
                    else{
                        $h->{sum}="\$sum";
                    }
                    $h->{"sum-init"}="my $h->{sum} = 0";
                }
                my $codelist=sumcode_generate($h);
                MyDef::compileutil::parseblock({source=>$codelist, name=>"sumcode"});
                return;
            }
        }
        elsif($func eq "print"){
            my $str=$param;
            my $need_escape;
            if($str=~/^\s*\"(.*)\"\s*$/){
                $str=$1;
            }
            else{
                $need_escape=1;
            }
            my %colors=(red=>31,green=>32,yellow=>33,blue=>34,magenta=>35,cyan=>36);
            my @fmt_list;
            my @arg_list;
            my @group;
            my $n_escape=0;
            while(1){
                if($str=~/\G$/gc){
                    last;
                }
                elsif($str=~/\G\$/gc){
                    if($str=~/\G(red|green|yellow|blue|magenta|cyan)/gc){
                        push @fmt_list, "\\x1b[$colors{$1}m";
                        $n_escape++;
                        if($str=~/\G\{/gc){
                            push @group, $1;
                        }
                    }
                    else{
                        push @fmt_list, '$';
                    }
                }
                elsif($str=~/\G(\\.)/gc){
                    push @fmt_list, $1;
                }
                elsif($str=~/\G"/gc){
                    if($need_escape){
                        push @fmt_list, "\\\"";
                    }
                    else{
                        push @fmt_list, "\"";
                    }
                }
                elsif($str=~/\G\}/gc){
                    if(@group){
                        pop @group;
                        if(!@group){
                            push @fmt_list, "\\x1b[0m";
                            $n_escape=0;
                        }
                        else{
                            my $c=$group[-1];
                            push @fmt_list, "\\x1b[$colors{$c}m";
                            $n_escape++;
                        }
                    }
                    else{
                        push @fmt_list, '}';
                    }
                }
                elsif($str=~/\G[^\$\}"]+/gc){
                    push @fmt_list, $&;
                }
            }
            my $tail=$fmt_list[-1];
            if($tail=~/(.*)-$/){
                $fmt_list[-1]=$1;
            }
            elsif($tail!~/\\n$/){
                push @fmt_list, "\\n";
            }
            if($n_escape){
                push @fmt_list, "\\x1b[0m";
            }
            push @$out, 'print "'.join('',@fmt_list).'";';
            return;
        }
        elsif($func eq "source-$param"){
            return "SKIPBLOCK";
        }
    }
    elsif($l=~/^NOOP POST_MAIN/){
        my $old_out=MyDef::compileutil::set_output($fn_block);
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
                push @$out, "sub $name {";
                push @$out, "INDENT";
                my $params=$code->{params};
                if($#$params>=0){
                    my $pline=join(", ", @$params);
                    push @$out, "my ($pline) = \@_;";
                }
                MyDef::compileutil::list_sub($code);
                push @$out, "DEDENT";
                push @$out, "}";
                push @$out, "NEWLINE";
            }
        }
        MyDef::compileutil::set_output($old_out);
        return 0;
    }
    elsif($l=~/^loop:/){
        $loop_idx+=1;
        push @$out, "DUMP_STUB loop_$loop_idx";
        return 0;
    }
    if($l=~/^\s*$/){
    }
    elsif($l=~/^\s*(break|continue);?\s*$/){
        if($1 eq "break"){
            $l="last;";
        }
        elsif($l eq "continue"){
            $l="next;";
        }
    }
    elsif($l=~/^\s*(for|while|if|else if)\s*\(.*\)\s*$/){
    }
    elsif($l=~/^\s*}/){
    }
    elsif($l!~/[,:\(\[\{;]\s*$/){
        $l.=";";
    }
    else{
    }
    push @$out, $l;
    return 0;
}
sub dumpout {
    my ($f, $out, $pagetype)=@_;
    my $dump={out=>$out,f=>$f, module=>"output_perl"};
    parsecode("NOOP");
    if(!$pagetype or $pagetype eq "pl"){
        push @$f, "#!/usr/bin/perl\n";
    }
    if($pagetype ne "eval"){
        push @$f, "use strict;\n";
        if(@uses){
            foreach my $v (@uses){
                push @$f, "use $v;\n";
            }
            push @$f, "\n";
        }
        if($MyDef::page->{package}){
            push @$f, "package ".$MyDef::page->{package}.";\n";
        }
        if(@globals){
            foreach my $v (@globals){
                push @$f, "our $v;\n";
            }
            push @$f, "\n";
        }
        if(@$fn_block){
            $dump->{fn_block}=$fn_block;
            unshift @$out, "INCLUDE_BLOCK fn_block";
        }
        unshift @$out, "DUMP_STUB global_init";
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
1;
