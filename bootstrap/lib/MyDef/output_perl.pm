use strict;
package MyDef::output_perl;
our $perl = $^X;
our @scope_stack;
our $cur_scope;
our $debug=0;
our $out;
our $mode;
our $page;
our %fn_hash;
our @functions;
our %functions;
our @globals;
our %globals;
our @uses;
our %uses;
our $case_if="if";
our $case_elif="elsif";
our @case_stack;
our $case_state;
our $case_wrap;
our $fn_block=[];

sub check_fcall {
    my ($l) = @_;
    while($l=~/\b(\w+)\(/g){
        if($fn_hash{$1}){
            if(!$functions{$1}){
                push @functions, $1;
                $functions{$1} = $MyDef::def->{codes}->{$1};
            }
        }
    }
}

sub parse_condition {
    my ($t) = @_;
    if($t=~/^\/|[!=]~\s*\//){
    }
    elsif($t=~/[^!=><]=[^="]/){
        if($t!~/["'].*=.*['"]/){
            my $curfile=MyDef::compileutil::curfile_curline();
            print "[$curfile]\x1b[33m assignment in condition [$t]?\n\x1b[0m";
        }
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

sub open_scope {
    my ($blk_idx, $scope_name) = @_;
    push @scope_stack, $cur_scope;
    $cur_scope={var_list=>[], var_hash=>{}, name=>$scope_name};
}

sub close_scope {
    my ($blk, $pre, $post) = @_;
    if(!$blk){
        $blk=$cur_scope;
    }
    $cur_scope=pop @scope_stack;
}

sub find_var {
    my ($name) = @_;
    if($debug eq "scope"){
        print "  cur_scope\[$cur_scope->{name}]: ";
        foreach my $v (@{$cur_scope->{var_list}}){
            print "$v, ";
        }
        print "\n";
        for(my $i=$#scope_stack; $i>=0; $i--){
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
    for(my $i=$#scope_stack; $i>=0; $i--){
        if($scope_stack[$i]->{var_hash}->{$name}){
            return $scope_stack[$i]->{var_hash}->{$name};
        }
    }
    return undef;
}

sub sumcode_generate {
    my ($h) = @_;
    my $left = $h->{left};
    my $right = $h->{right};
    my $left_idx = $h->{left_idx};
    my $right_idx = $h->{right_idx};
    my $klist = $h->{klist};
    my @code;
    my %loop_i_hash;
    if($debug){
        print "left indexs: ", join(", ", @$left_idx), "\n";
        print "right indexs: ", join(", ", @$right_idx), "\n";
    }
    foreach my $i (@$left_idx){
        $loop_i_hash{$i}=1;
        my $dim=$h->{"$i-dim"};
        my $var=$h->{"$i-var"};
        push @code, "\$for $var=0:$dim";
        push @code, "SOURCE_INDENT";
    }
    if(@$right_idx){
        push @code, "$left = 0";
        foreach my $i (@$right_idx){
            $loop_i_hash{$i}=1;
            my $dim=$h->{"$i-dim"};
            my $var=$h->{"$i-var"};
            push @code, "\$for $var=0:$dim";
            push @code, "SOURCE_INDENT";
        }
        push @code, "$left += $right";
        foreach my $i (reverse @$right_idx){
            push @code, "SOURCE_DEDENT";
        }
    }
    elsif(defined $right){
        push @code, "$left = $right";
    }
    else{
        push @code, $left;
    }
    foreach my $i (reverse @$left_idx){
        push @code, "SOURCE_DEDENT";
    }
    return \@code;
}

if($perl!~/^\//){
    $perl = "/usr/bin/perl";
}
$cur_scope={var_list=>[], var_hash=>{}, name=>"default"};
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
    elsif(!$page->{package} and $page->{type} eq "pm"){
        $page->{package}=$page->{_pagename};
    }
    if($page->{_pageext} eq "pm"){
        $page->{autolist}=1;
    }
    %fn_hash=();
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
            $fn_hash{$name}=$code;
        }
    }
    @functions=();
    %functions=();
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
    if($l!~/;\s*$/){
        if($l=~/^SUBBLOCK BEGIN (\d+) (.*)/){
            open_scope($1, $2);
            return;
        }
        elsif($l=~/^SUBBLOCK END (\d+) (.*)/){
            close_scope();
            return;
        }
        if($debug eq "case"){
            my $level=@case_stack;
            print "        $level:[$case_state]$l\n";
        }
        my $check_unwrap;
        if($l=~/^\x24(if|elif|elsif|elseif|case)\s+(.*)$/){
            my $cond=$2;
            my $case=$case_if;
            if($1 eq "if"){
                if($case_wrap){
                    if($debug eq "case"){
                        my $level=@case_stack;
                        print "   $level:[case_unwrap]$l\n";
                    }
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
            my @src;
            my $regex_capture;
            if($cond=~/(.*\S\/\w*)\s*->\s*([^\/]+?)\s*$/){
                $cond = $1;
                my @tlist=MyDef::utils::proper_split($2);
                my (@t1, @t2);
                my $i=1;
                foreach my $v (@tlist){
                    if($v ne "-"){
                        push @t1, $v;
                        push @t2, '$'.$i;
                    }
                    $i++;
                }
                $regex_capture = "my (".join(', ', @t1).") = (".join(', ', @t2).");";
            }
            push @src, "$case($cond){";
            push @src, "INDENT";
            if($regex_capture){
                push @src, $regex_capture;
            }
            push @src, "BLOCK";
            push @src, "DEDENT";
            push @src, "}";
            push @src, "PARSE:CASEPOP";
            push @case_stack, {state=>"if", wrap=>$case_wrap};
            undef $case_state;
            undef $case_wrap;
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
            push @src, "else{";
            push @src, "INDENT";
            push @src, "BLOCK";
            push @src, "DEDENT";
            push @src, "}";
            push @src, "PARSE:CASEPOP";
            push @case_stack, {state=>undef, wrap=>$case_wrap};
            undef $case_state;
            undef $case_wrap;
            if($debug eq "case"){
                my $level=@case_stack;
                print "Entering case [$level]: $l\n";
            }
            MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
            return "NEWBLOCK-else";
        }
        elsif($l!~/^SUBBLOCK/){
            undef $case_state;
            if($case_wrap){
                if($debug eq "case"){
                    my $level=@case_stack;
                    print "   $level:[case_unwrap]$l\n";
                }
                push @$out, @$case_wrap;
                undef $case_wrap;
            }
            if($l eq "CASEPOP"){
                if($debug eq "case"){
                    my $level=@case_stack;
                    print "    Exit case [$level][wrap:$case_wrap]\n";
                }
                my $t_case=pop @case_stack;
                if($t_case){
                    $case_state=$t_case->{state};
                    $case_wrap=$t_case->{wrap};
                }
                return 0;
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
                    if($v=~/^(\S+)\s*=/){
                        if(!$globals{$1}){
                            $globals{$1}=1;
                            push @globals, $v;
                        }
                    }
                    else{
                        if(!$globals{$v}){
                            $globals{$v}=1;
                            push @globals, $v;
                        }
                    }
                    if($var){
                    }
                }
                return 0;
            }
            elsif($func =~ /^my$/ and $param !~/^\s*[=+\-*\/]/){
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
            elsif($func =~ /^use$/){
                $param=~s/\s*;\s*$//;
                my @tlist=split /,\s*/, $param;
                foreach my $v (@tlist){
                    if(!$uses{$v}){
                        $uses{$v}=1;
                        push @uses, $v;
                    }
                }
                return 0;
            }
            elsif($func eq "list"){
                my @flist = MyDef::utils::proper_split($param);
                foreach my $name (@flist){
                    if($fn_hash{$name}){
                        if(!$functions{$name}){
                            push @functions, $name;
                            $functions{$name} = $MyDef::def->{codes}->{$name};
                        }
                    }
                    else{
                        my $curfile=MyDef::compileutil::curfile_curline();
                        print "[$curfile]\x1b[33m add_function: [$name] not found\n\x1b[0m";
                    }
                }
                return 0;
            }
            elsif($func eq "sub"){
                if($param=~/^(\w+)\((.*)\)/){
                    my @src;
                    push @src, "sub $1 {";
                    push @src, "INDENT";
                    push @src, "my ($2)=\@_;";
                    push @src, "BLOCK";
                    push @src, "DEDENT";
                    push @src, "}";
                    MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                    return "NEWBLOCK-sub";
                }
                else{
                    return single_block("sub $param {", "}", "sub");
                }
            }
            elsif($func =~ /^(while)$/){
                my $regex_capture;
                if($param=~/(.*\S\/\w*)\s*->\s*([^\/]+?)\s*$/){
                    $param = $1;
                    my @tlist=MyDef::utils::proper_split($2);
                    my (@t1, @t2);
                    my $i=1;
                    foreach my $v (@tlist){
                        if($v ne "-"){
                            push @t1, $v;
                            push @t2, '$'.$i;
                        }
                        $i++;
                    }
                    $regex_capture = "my (".join(', ', @t1).") = (".join(', ', @t2).");";
                }
                if($regex_capture){
                    my @src;
                    push @src, "while($param){";
                    push @src, "INDENT";
                    push @src, $regex_capture;
                    push @src, "BLOCK";
                    push @src, "DEDENT";
                    push @src, "}";
                    MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                    return "NEWBLOCK-while";
                }
                elsif($param=~/\/.*\/\w*\s*$/){
                    return single_block("while($param){", "}", "while");
                }
                else{
                    my ($init, $cond, $next);
                    my @clause = split /\s*;\s*/, $param;
                    my $n = @clause;
                    if($n>1 && !$clause[-1]){
                        $n--;
                    }
                    if($n>3){
                        my $curfile=MyDef::compileutil::curfile_curline();
                        print "[$curfile]\x1b[33m error: [\$while $param]\n\x1b[0m";
                    }
                    elsif($n==3){
                        ($init, $cond, $next) = @clause;
                    }
                    elsif($n==2){
                        ($cond, $next) = @clause;
                    }
                    elsif($n==1){
                        $cond = $param;
                    }
                    else{
                        $cond = 1;
                    }
                    my @src;
                    if($init){
                        push @src, "$init;";
                    }
                    push @src, "while($cond){";
                    push @src, "INDENT";
                    push @src, "BLOCK";
                    if($next){
                        push @src, "$next;";
                    }
                    push @src, "DEDENT";
                    push @src, "}";
                    MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                    return "NEWBLOCK-while";
                }
            }
            elsif($func =~ /^for(each)?$/){
                if($1 or $param=~/ in /){
                    if($param=~/^(.*?)\s+in\s+(.*)/){
                        my ($v, $t) = ($1, $2);
                        if($v!~/,/){
                            $v=~s/^my\s+//;
                            return single_block("foreach my $v ($t){", "}", "foreach");
                        }
                        else{
                            my @v = split /,\s*/, $v;
                            if(@v==2 and $t=~/^%/){
                                my ($k, $v)=@v;
                                return single_block("while (my ($k, $v)=each $t){", "}", "foreach");
                            }
                            else{
                                my @t=MyDef::utils::proper_split($t);
                                if($#v==$#t){
                                    unshift @v, '$_i';
                                }
                                if($#v==$#t+1 and $v[0]=~/^\$_?[ijk]/){
                                    if($#v==1){
                                        my ($idx, $v)=@v;
                                        my @src;
                                        push @src, "my $idx = -1;";
                                        push @src, "foreach my $v ($t){";
                                        push @src, "INDENT";
                                        push @src, "$idx++;";
                                        push @src, "BLOCK";
                                        push @src, "DEDENT";
                                        push @src, "}";
                                        MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                                        return "NEWBLOCK-foreach";
                                    }
                                    else{
                                        my $idx=shift @v;
                                        foreach my $v (@v){
                                            if($v eq $idx){
                                                my $curfile=MyDef::compileutil::curfile_curline();
                                                print "[$curfile]\x1b[33m foreach zip: dummy variable $idx is in conflict\n\x1b[0m";
                                            }
                                        }
                                        foreach my $t (@t){
                                            if($t!~/^@/){
                                                die "foreach zip error: $t is not an array.\n";
                                            }
                                        }
                                        my @src;
                                        push @src, "for(my $idx=0;$idx<$t[0];$idx++){";
                                        push @src, "INDENT";
                                        for(my $i=0; $i<@v; $i++){
                                            my $a=$v[$i];
                                            if($t[$i]=~/^@(\w+)$/){
                                                push @src, "my $a = \$$1"."[$idx];";
                                            }
                                            elsif($t[$i]=~/^@(.+)/){
                                                push @src, "my $a = $1"."->[$idx];";
                                            }
                                        }
                                        push @src, "BLOCK";
                                        push @src, "DEDENT";
                                        push @src, "}";
                                        MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                                        return "NEWBLOCK-foreach";
                                    }
                                }
                            }
                        }
                        die "foreach with mismatched keys and lists\n";
                    }
                    else{
                        if($param=~/^(%.*)/){
                            return single_block("while (my (\$k, \$v) = each $1){", "}", "foreach");
                        }
                        else{
                            return single_block("foreach ($param){", "}", "foreach");
                        }
                    }
                }
                else{
                    if($param=~/(.*);(.*);(.*)/){
                        my @src;
                        push @src, "for($param){";
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
                        $i1="<=$to";
                    }
                    elsif($param=~/^(.+?)\s+downto\s+(.+)/){
                        my $to;
                        ($i0, $to, $step) = ($1, $2, 1);
                        if($to=~/(.+?)\s+step\s+(.+)/){
                            ($to, $step)=($1, $2);
                        }
                        $i1=">=$to";
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
                            $step="++";
                        }
                        elsif($step eq "-1"){
                            $step="--";
                        }
                        else{
                            $step="+=$step";
                        }
                        if(!$var){
                            $var="\$i";
                        }
                        elsif($var=~/^(\w+)/){
                            $var='$'.$var;
                        }
                        $param="$var=$i0; $var$i1; $var$step";
                        $param = "my $param";
                        my @src;
                        push @src, "for($param){";
                        push @src, "INDENT";
                        push @src, "BLOCK";
                        push @src, "DEDENT";
                        push @src, "}";
                        MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
                        return "NEWBLOCK-for";
                    }
                }
                return 0;
            }
            elsif($func =~ /^loop$/){
                return single_block("while(1){", "}", "while");
            }
            elsif($func eq "sumcode" or $func eq "sum"){
                if($param=~/^\((.*?)\)\s+(.*)/){
                    my $dimstr=$1;
                    $param=$2;
                    if($debug){
                        print "parsecode_sum: [$param]\n";
                    }
                    my $h={};
                    my (%k_hash, @k_list);
                    my %var_hash;
                    my (@left_idx, @right_idx);
                    $h->{style}="perl";
                    my ($left, $right);
                    if($param=~/(.*?)\s*(?<![\+\-\*\/%&\|><=])=(?!=)\s*(.*)/){
                        ($left, $right)=($1, $2);
                    }
                    else{
                        $left=$param;
                    }
                    my @idxlist=('i','j','k','l');
                    my @dimlist=MyDef::utils::proper_split($dimstr);
                    foreach my $dim (@dimlist){
                        my $idx=shift @idxlist;
                        $h->{"$idx-dim"}=$dim;
                        $h->{"$idx-var"}="\$_$idx";
                        if($left=~/\b$idx\b/){
                            push @left_idx, $idx;
                        }
                        else{
                            push @right_idx, $idx;
                        }
                    }
                    my @segs=split /(\w+\[[ijkl,]*?\])/, $left;
                    foreach my $s (@segs){
                        if($s=~/^(\w+)\[([ijkl,]*?)\]$/){
                            if($var_hash{$s}){
                                $s=$var_hash{$s};
                            }
                            else{
                                my ($v, $idx_str)=($1, $2);
                                my @idxlist=split /,/, $idx_str;
                                my $t;
                                if(@idxlist==1){
                                    my $idx=$idx_str;
                                    $t="$v\[\$_$idx\]";
                                }
                                else{
                                    my $s;
                                    foreach my $idx (@idxlist){
                                        if(!$s){
                                            $s="\$_$idx";
                                        }
                                        else{
                                            my $dim=$h->{"$idx-dim"};
                                            if($s=~/\+/){
                                                $s="($s)";
                                            }
                                            $s= "$s*$dim+\$_$idx";
                                        }
                                    }
                                    $t="$v\[$s\]";
                                }
                                $var_hash{$s}=$t;
                                $s=$t;
                            }
                        }
                    }
                    $left=join '', @segs;
                    $left=~s/\b([ijkl])\b/\$_$1/g;
                    if($right){
                        my @segs=split /(\w+\[[ijkl,]*?\])/, $right;
                        foreach my $s (@segs){
                            if($s=~/^(\w+)\[([ijkl,]*?)\]$/){
                                if($var_hash{$s}){
                                    $s=$var_hash{$s};
                                }
                                else{
                                    my ($v, $idx_str)=($1, $2);
                                    my @idxlist=split /,/, $idx_str;
                                    my $t;
                                    if(@idxlist==1){
                                        my $idx=$idx_str;
                                        $t="$v\[\$_$idx\]";
                                    }
                                    else{
                                        my $s;
                                        foreach my $idx (@idxlist){
                                            if(!$s){
                                                $s="\$_$idx";
                                            }
                                            else{
                                                my $dim=$h->{"$idx-dim"};
                                                if($s=~/\+/){
                                                    $s="($s)";
                                                }
                                                $s= "$s*$dim+\$_$idx";
                                            }
                                        }
                                        $t="$v\[$s\]";
                                    }
                                    $var_hash{$s}=$t;
                                    $s=$t;
                                }
                            }
                        }
                        $right=join '', @segs;
                        $right=~s/\b([ijkl])\b/\$_$1/g;
                    }
                    $h->{left}=$left;
                    $h->{left_idx}=\@left_idx;
                    $h->{right}=$right;
                    $h->{right_idx}=\@right_idx;
                    my $codelist=sumcode_generate($h);
                    MyDef::compileutil::parseblock({source=>$codelist, name=>"sumcode"});
                    return;
                }
                elsif($func eq "sumcode"){
                    if($debug){
                        print "parsecode_sum: [$param]\n";
                    }
                    my $h={};
                    my (%k_hash, @k_list);
                    my %var_hash;
                    my (@left_idx, @right_idx);
                    $h->{style}="perl";
                    my ($left, $right);
                    if($param=~/(.*?)\s*(?<![\+\-\*\/%&\|><=])=(?!=)\s*(.*)/){
                        ($left, $right)=($1, $2);
                    }
                    else{
                        $left=$param;
                    }
                    my @segs=split /(\w+\[[ijkl,]*?\])/, $left;
                    foreach my $s (@segs){
                        if($s=~/^(\w+)\[([ijkl,]*?)\]$/){
                            if($var_hash{$s}){
                                $s=$var_hash{$s};
                            }
                            else{
                                my ($v, $idx_str)=($1, $2);
                                my @idxlist=split /,/, $idx_str;
                                my $var=find_var($v);
                                my $i=0;
                                foreach my $idx (@idxlist){
                                    $i++;
                                    my $dim;
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
                                        $h->{"$idx-var"}="\$_$idx";
                                    }
                                    else{
                                        if($h->{"$idx-dim"} ne $dim){
                                            my $old_dim=$h->{"$idx-dim"};
                                            print "sumcode dimesnion mismatch: $old_dim != $dim\n";
                                        }
                                    }
                                }
                                my $t;
                                if(@idxlist==1){
                                    my $idx=$idx_str;
                                    $t="$v\[\$_$idx\]";
                                }
                                else{
                                    my $s;
                                    foreach my $idx (@idxlist){
                                        if(!$s){
                                            $s="\$_$idx";
                                        }
                                        else{
                                            my $dim=$h->{"$idx-dim"};
                                            if($s=~/\+/){
                                                $s="($s)";
                                            }
                                            $s= "$s*$dim+\$_$idx";
                                        }
                                    }
                                    $t="$v\[$s\]";
                                }
                                $var_hash{$s}=$t;
                                $s=$t;
                            }
                        }
                    }
                    $left=join '', @segs;
                    $left=~s/\b([ijkl])\b/\$_$1/g;
                    if($right){
                        my @segs=split /(\w+\[[ijkl,]*?\])/, $right;
                        foreach my $s (@segs){
                            if($s=~/^(\w+)\[([ijkl,]*?)\]$/){
                                if($var_hash{$s}){
                                    $s=$var_hash{$s};
                                }
                                else{
                                    my ($v, $idx_str)=($1, $2);
                                    my @idxlist=split /,/, $idx_str;
                                    my $var=find_var($v);
                                    my $i=0;
                                    foreach my $idx (@idxlist){
                                        $i++;
                                        my $dim;
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
                                            $h->{"$idx-var"}="\$_$idx";
                                        }
                                        else{
                                            if($h->{"$idx-dim"} ne $dim){
                                                my $old_dim=$h->{"$idx-dim"};
                                                print "sumcode dimesnion mismatch: $old_dim != $dim\n";
                                            }
                                        }
                                    }
                                    my $t;
                                    if(@idxlist==1){
                                        my $idx=$idx_str;
                                        $t="$v\[\$_$idx\]";
                                    }
                                    else{
                                        my $s;
                                        foreach my $idx (@idxlist){
                                            if(!$s){
                                                $s="\$_$idx";
                                            }
                                            else{
                                                my $dim=$h->{"$idx-dim"};
                                                if($s=~/\+/){
                                                    $s="($s)";
                                                }
                                                $s= "$s*$dim+\$_$idx";
                                            }
                                        }
                                        $t="$v\[$s\]";
                                    }
                                    $var_hash{$s}=$t;
                                    $s=$t;
                                }
                            }
                        }
                        $right=join '', @segs;
                        $right=~s/\b([ijkl])\b/\$_$1/g;
                    }
                    $h->{left}=$left;
                    $h->{left_idx}=\@left_idx;
                    $h->{right}=$right;
                    $h->{right_idx}=\@right_idx;
                    my $codelist=sumcode_generate($h);
                    MyDef::compileutil::parseblock({source=>$codelist, name=>"sumcode"});
                    return;
                }
            }
            elsif($func eq "source-$param"){
                return "SKIPBLOCK";
            }
            elsif($func =~ /^loopvar$/){
                my @tlist=MyDef::utils::proper_split($param);
                my $block=MyDef::compileutil::get_named_block("...");
                foreach my $v (@tlist){
                    push @$block, "my $v;";
                }
                return 0;
            }
            elsif($func eq "print"){
                my $str=$param;
                my $printf_args;
                my $need_escape;
                if($str=~/^\s*\"(.*)\"\s*$/){
                    $str=$1;
                }
                elsif($str=~/^\s*\"([^"]+)\",\s*(.+)$/){
                    $str = $1;
                    $printf_args=$2;
                    check_fcall($2);
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
                    if($str=~/\G$/sgc){
                        last;
                    }
                    elsif($str=~/\G\$/sgc){
                        if($str=~/\G(red|green|yellow|blue|magenta|cyan)/sgc){
                            push @fmt_list, "\\x1b[$colors{$1}m";
                            $n_escape++;
                            if($str=~/\G\{/sgc){
                                push @group, $1;
                            }
                        }
                        else{
                            push @fmt_list, '$';
                        }
                    }
                    elsif($str=~/\G(\\.)/sgc){
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
                    elsif($str=~/\G\}/sgc){
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
                    else{
                        die "parse_loop: nothing matches! [$str]\n";
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
                my $p;
                if($printf_args){
                    $p = "printf";
                }
                else{
                    $p = "print";
                }
                my $print_target = MyDef::compileutil::get_macro_word("print_to", 1);
                if($print_target){
                    $p.=" $print_target";
                }
                if($printf_args){
                    push @$out, "$p \"".join('',@fmt_list)."\", $printf_args;";
                }
                else{
                    push @$out, "$p \"".join('',@fmt_list).'";';
                }
                return;
            }
        }
        elsif($l=~/^NOOP POST_MAIN/){
            my $old_out=MyDef::compileutil::set_output($fn_block);
            if($page->{autolist}){
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
                        if($params and @$params){
                            my $pline=join(", ", @$params);
                            push @$out, "my ($pline) = \@_;";
                        }
                        $code->{scope}="list_sub";
                        MyDef::compileutil::list_sub($code);
                        push @$out, "DEDENT";
                        push @$out, "}";
                        push @$out, "NEWLINE";
                    }
                }
            }
            else{
                while(my $name = pop @functions){
                    my $code = $functions{$name};
                    push @$out, "sub $name {";
                    push @$out, "INDENT";
                    my $params=$code->{params};
                    if($params and @$params){
                        my $pline=join(", ", @$params);
                        push @$out, "my ($pline) = \@_;";
                    }
                    $code->{scope}="list_sub";
                    MyDef::compileutil::list_sub($code);
                    push @$out, "DEDENT";
                    push @$out, "}";
                    push @$out, "NEWLINE";
                }
            }
            MyDef::compileutil::set_output($old_out);
            return 0;
        }
        if($l=~/^\s*$/){
        }
        elsif($l=~/^break\s*((not|flag)_\w+)?\s*$/){
            if($1){
                my $blkname=MyDef::compileutil::get_macro_word("stub");
                my $blk = MyDef::compileutil::get_named_block($blkname);
                my $t = "my \$$1;";
                my $flag_exist;
                foreach my $_l (@$blk){
                    if($_l eq $t){
                        $flag_exist = 1;
                        last;
                    }
                }
                if(!$flag_exist){
                    push @$blk, $t;
                }
                push @$out, "\$$1 = 1;";
            }
            $l="last;";
        }
        elsif($l=~/^continue\s*$/){
            $l="next;";
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
    }
    check_fcall($l);
    push @$out, $l;
    return 0;
}
sub dumpout {
    my ($f, $out)=@_;
    my $dump={out=>$out,f=>$f};
    parsecode("NOOP");
    if($out->[0] eq "EVAL"){
        shift @$out;
    }
    else{
        my $pagetype = $page->{_pageext};
        if(!$pagetype or $pagetype eq "pl"){
            push @$f, "#!$perl\n";
        }
        if(!$MyDef::page->{relax}){
            push @$f, "use strict;\n";
        }
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
