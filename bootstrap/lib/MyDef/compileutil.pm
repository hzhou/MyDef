use strict;
package MyDef::compileutil;
our %list_list;
our %list_hash;
our $cur_file;
our $cur_line;
our $f_init;
our $f_parse;
our $f_setout;
our $f_modeswitch;
our $f_dumpout;
our $deflist;
our %misc_vars;
our $debug=0;
our $out;
our @output_list;
our %named_blocks;
our @mode_stack=("sub");
our $cur_mode;
our $in_autoload;
our @callsub_stack;
our @callback_block_stack;
our %eval_sub_cache;
our %eval_sub_error;
our $cur_ogdl;
our $parse_capture;
our $MAKE_STRING;
our $block_index=0;
our @block_stack;

sub call_back {
    my ($param, $subblock) = @_;
    my ($codename, $attr, $codelib);
    if($param=~/^(@)?(\w+)(.*)/){
        ($codename, $attr, $param)=($2, $1, $3);
        $param=~s/^\s*,\s*//;
        $codelib=get_def_attr("codes", $codename);
        if(!$codelib){
            set_current_macro("notfound", 1);
            if(!$attr or $attr ne '@'){
                print "[$cur_file:$cur_line] Code $codename not found!\n";
            }
        }
        else{
            set_current_macro("notfound", 0);
        }
    }
    else{
        warn "    call_sub [$param] parse failure\n";
    }
    if($codelib){
        if($codelib->{type} eq "perl"){
            $param=~s/^\s*,\s*//;
            $named_blocks{last_grab}=$subblock;
            $f_parse->("\$eval $codename, $param");
            $named_blocks{last_grab}=undef;
        }
        elsif($codelib->{type} eq "template"){
            modepush("template");
            parseblock($codelib);
            modepop();
        }
        else{
            my $codeparams=$codelib->{params};
            my $n_param = @$codeparams;
            my ($pline, @plist);
            $param=~s/^\s*,?\s*//;
            $pline=$param;
            if($n_param==1 and $codeparams->[0]=~/^@/){
                push @plist, $param;
            }
            else{
                @plist=MyDef::utils::smart_split($param, $n_param);
            }
            my @pre_plist;
            my $n_pre=0;
            $codelib->{recurse}++;
            push @callsub_stack, $codename;
            modepush($codelib->{type});
            push @callback_block_stack, {source=>$subblock, name=>"$codename", cur_file=>$cur_file, cur_line=>$cur_line};
            my $macro={};
            if(1==$n_param && $codeparams->[0] eq "\@plist"){
                $macro->{np}=$#plist+1;
                my $i=0;
                foreach my $p (@plist){
                    $i++;
                    $macro->{"p$i"}=$p;
                }
            }
            if($n_pre+@plist!=$n_param){
                my $n2=@plist;
                my $n3=$n_param;
                if($codeparams->[$n3-1]=~/^\@(\w+)/ and $n2>$n3-$n_pre){
                    my $n0=$n3-$n_pre-1;
                    for(my $i=0; $i <$n0; $i++){
                        $pline=~s/^[^,]*,//;
                    }
                    $pline=~s/^\s*//;
                    $plist[$n0]=$pline;
                }
                else{
                    my $param=join(', ', @$codeparams);
                    warn "    [$cur_file:$cur_line] Code $codename parameter mismatch ($n_pre + $n2) != $n3. [pline:$pline]($param)\n";
                }
            }
            for(my $i=0; $i <$n_pre; $i++){
                $macro->{$codeparams->[$i]}=$pre_plist[$i];
            }
            for(my $j=0; $j <$n_param-$n_pre; $j++){
                my $p=$codeparams->[$n_pre+$j];
                if($p=~/^\@(\w+)/){
                    $p=$1;
                }
                if($plist[$j]=~/q"(.*)"/){
                    $macro->{$p}=$1;
                }
                else{
                    $macro->{$p}=$plist[$j];
                }
            }
            $macro->{recurse_level}=$codelib->{recurse};
            if($codelib->{macros}){
                while (my ($k, $v) = each %{$codelib->{macros}}){
                    $macro->{$k}=$v;
                }
            }
            if($codelib->{codes}){
                $macro->{"codes"}=$codelib->{codes};
            }
            if($debug eq "macro"){
                print "Code $codename: ";
                while(my ($k, $v)=each %$macro){
                    print "$k=$v, ";
                }
                print "\n";
            }
            push @$deflist, $macro;
            parseblock($codelib);
            pop @$deflist;
            pop @callback_block_stack;
            modepop();
            pop @callsub_stack;
            $codelib->{recurse}--;
        }
    }
}

sub map_sub {
    my ($param) = @_;
    my ($codename, $attr, $codelib);
    if($param=~/^(@)?(\w+)(.*)/){
        ($codename, $attr, $param)=($2, $1, $3);
        $param=~s/^\s*,\s*//;
        $codelib=get_def_attr("codes", $codename);
        if(!$codelib){
            set_current_macro("notfound", 1);
            if(!$attr or $attr ne '@'){
                print "[$cur_file:$cur_line] Code $codename not found!\n";
            }
        }
        else{
            set_current_macro("notfound", 0);
            if($codelib->{recurse} and $codelib->{recurse}>5){
                if($codelib->{allow_recurse} < $codelib->{recurse}){
                    die "Recursive subcode: $codename [$codelib->{recurse}]\n";
                }
            }
        }
    }
    else{
        warn "    call_sub [$param] parse failure\n";
    }
    if($codelib){
        if($codelib->{type} eq "perl"){
            $param=~s/^\s*,\s*//;
            $f_parse->("\$eval $codename, $param");
        }
        elsif($codelib->{type} eq "template"){
            modepush("template");
            parseblock($codelib);
            modepop();
        }
        else{
            my $codeparams=$codelib->{params};
            my $n_param = @$codeparams;
            my (@pre_plist, $pline, @plist);
            if($param=~/^\(([^\)]*)\)/){
                $param=$';
                @pre_plist=MyDef::utils::proper_split($1);
            }
            $param=~s/^\s*,?\s*//;
            $pline=$param;
            @plist=MyDef::utils::proper_split($param);
            my $n_pre=@pre_plist;
            $codelib->{recurse}++;
            push @callsub_stack, $codename;
            modepush($codelib->{type});
            if(1+@pre_plist!=$n_param){
                warn " Code $codename parameter mismatch.\n";
            }
            if($plist[0]=~/^subcode:(.*)/){
                my $prefix=$1;
                @plist=();
                my $codes=$MyDef::def->{codes};
                foreach my $k (sort(keys(%$codes))){
                    if($k=~/^$prefix(\w+)/){
                        push @plist, $1;
                    }
                }
            }
            foreach my $item (@plist){
                my $macro={};
                $macro->{$codeparams->[$n_pre]}=$item;
                if($n_pre){
                    for(my $i=0; $i <$n_pre; $i++){
                        $macro->{$codeparams->[$i]}=$pre_plist[$i];
                    }
                }
                push @$deflist, $macro;
                parseblock($codelib);
                pop @$deflist;
            }
            modepop();
            pop @callsub_stack;
            $codelib->{recurse}--;
        }
    }
}

sub call_sub {
    my ($param) = @_;
    my ($codename, $attr, $codelib);
    if($param=~/^(@)?(\w+)(.*)/){
        ($codename, $attr, $param)=($2, $1, $3);
        $param=~s/^\s*,\s*//;
        $codelib=get_def_attr("codes", $codename);
        if(!$codelib){
            set_current_macro("notfound", 1);
            if(!$attr or $attr ne '@'){
                print "[$cur_file:$cur_line] Code $codename not found!\n";
            }
        }
        else{
            set_current_macro("notfound", 0);
            if($codelib->{recurse} and $codelib->{recurse}>5){
                if($codelib->{allow_recurse} < $codelib->{recurse}){
                    die "Recursive subcode: $codename [$codelib->{recurse}]\n";
                }
            }
        }
    }
    else{
        warn "    call_sub [$param] parse failure\n";
    }
    if($codelib){
        if($codelib->{type} eq "perl"){
            $param=~s/^\s*,\s*//;
            $f_parse->("\$eval $codename, $param");
        }
        elsif($codelib->{type} eq "template"){
            modepush("template");
            parseblock($codelib);
            modepop();
        }
        else{
            my $codeparams=$codelib->{params};
            my $n_param = @$codeparams;
            my ($pline, @plist);
            $param=~s/^\s*,?\s*//;
            $pline=$param;
            if($n_param==1 and $codeparams->[0]=~/^@/){
                push @plist, $param;
            }
            else{
                @plist=MyDef::utils::smart_split($param, $n_param);
            }
            my @pre_plist;
            my $n_pre=0;
            $codelib->{recurse}++;
            push @callsub_stack, $codename;
            modepush($codelib->{type});
            my $macro={};
            if(1==$n_param && $codeparams->[0] eq "\@plist"){
                $macro->{np}=$#plist+1;
                my $i=0;
                foreach my $p (@plist){
                    $i++;
                    $macro->{"p$i"}=$p;
                }
            }
            if($n_pre+@plist!=$n_param){
                my $n2=@plist;
                my $n3=$n_param;
                if($codeparams->[$n3-1]=~/^\@(\w+)/ and $n2>$n3-$n_pre){
                    my $n0=$n3-$n_pre-1;
                    for(my $i=0; $i <$n0; $i++){
                        $pline=~s/^[^,]*,//;
                    }
                    $pline=~s/^\s*//;
                    $plist[$n0]=$pline;
                }
                else{
                    my $param=join(', ', @$codeparams);
                    warn "    [$cur_file:$cur_line] Code $codename parameter mismatch ($n_pre + $n2) != $n3. [pline:$pline]($param)\n";
                }
            }
            for(my $i=0; $i <$n_pre; $i++){
                $macro->{$codeparams->[$i]}=$pre_plist[$i];
            }
            for(my $j=0; $j <$n_param-$n_pre; $j++){
                my $p=$codeparams->[$n_pre+$j];
                if($p=~/^\@(\w+)/){
                    $p=$1;
                }
                if($plist[$j]=~/q"(.*)"/){
                    $macro->{$p}=$1;
                }
                else{
                    $macro->{$p}=$plist[$j];
                }
            }
            $macro->{recurse_level}=$codelib->{recurse};
            if($codelib->{macros}){
                while (my ($k, $v) = each %{$codelib->{macros}}){
                    $macro->{$k}=$v;
                }
            }
            if($codelib->{codes}){
                $macro->{"codes"}=$codelib->{codes};
            }
            if($debug eq "macro"){
                print "Code $codename: ";
                while(my ($k, $v)=each %$macro){
                    print "$k=$v, ";
                }
                print "\n";
            }
            push @$deflist, $macro;
            parseblock($codelib);
            pop @$deflist;
            modepop();
            pop @callsub_stack;
            $codelib->{recurse}--;
        }
    }
}

sub list_sub {
    my ($codelib) = @_;
    my $macro={};
    if($codelib->{macros}){
        while (my ($k, $v) = each %{$codelib->{macros}}){
            $macro->{$k}=$v;
        }
    }
    if($codelib->{codes}){
        $macro->{"codes"}=$codelib->{codes};
    }
    push @$deflist, $macro;
    parseblock($codelib);
    pop @$deflist;
}

sub special_sub {
    my ($param, $mode) = @_;
    if($param=~/^(@)?(\w+)(.*)/){
        my $codename=$1;
        my $codelib=get_def_attr("codes", $codename);
        if($codelib){
            modepush($mode);
            parseblock($codelib);
            modepop();
        }
    }
}

sub eval_sub {
    my ($codename) = @_;
    if($eval_sub_cache{$codename}){
        return $eval_sub_cache{$codename};
    }
    else{
        my $codelib=get_def_attr("codes", $codename);
        if(!$codelib){
            warn "    eval_sub: Code $codename not found\n";
        }
        my $t= eval_sub_string($codelib);
        $eval_sub_cache{$codename}=$t;
        return $t;
    }
}

sub eval_sub_string {
    my ($codelib) = @_;
    require MyDef::output_perl;
    my $save_out=$out;
    my @save_interface=get_interface();
    set_interface(MyDef::output_perl::get_interface());
    $out=[];
    $f_setout->($out);
    list_sub($codelib);
    my @t;
    $f_dumpout->(\@t, $out, "eval");
    set_interface(@save_interface);
    $out=$save_out;
    $f_setout->($out);
    my $t=join("", @t);
    return $t;
}

sub parseblock {
    my ($code) = @_;
    my $block=$code->{source};
    if(!$block){
        warn "parseblock: undefined block [$code]\n";
    }
    my $switch_context;
    my @ogdl_stack;
    my @ogdl_path;
    my $ogdl_path_index_base;
    my %ogdl_path_index;
    my $indent=0;
    parse_stack_push($code);
    my @last_line;
    my $lindex=0;
    my @callback_stack;
    my $pending_mode_pop;
    while($lindex<@$block){
        my $l=$block->[$lindex];
        if($debug eq "compile"){
            my $yellow="\033[33;1m";
            my $normal="\033[0m";
            print "$yellow compile: [$l]$normal\n";
        }
        $lindex++;
        $cur_line++;
        if($l =~ /^DEBUG (\w+)/){
            if($1 eq "OFF"){
                if($debug){
                    if(!$block_stack[-1]->{debug}){
                        $block_stack[-1]->{debug_off}=$debug;
                    }
                    $debug=0;
                    $f_parse->("DEBUG OFF");
                }
            }
            elsif($1 eq "MACRO"){
                for(my $i=0;$i<=$#$deflist;$i++){
                    print "DUMP DEFLIST $i:\n";
                    my $h=$deflist->[$i];
                    foreach my $k (keys(%$h)){
                        print "    $k: $h->{$k}\n";
                    }
                }
            }
            else{
                $debug=$1;
                $block_stack[-1]->{debug}=$debug;
                $f_parse->("DEBUG $debug");
            }
            next;
        }
        elsif($l =~ /^BLOCK RELEASE/i){
            $block_stack[-1]->{eindex}=$block_stack[-2]->{eindex};
            next;
        }
        elsif($l =~/^SOURCE: (.*) - (\d+)$/){
            $cur_file=$1;
            $cur_line=$2;
            next;
        }
        if($l eq "SOURCE_INDENT"){
            $indent++;
        }
        elsif($l eq "SOURCE_DEDENT"){
            $indent-- if $indent>0;
        }
        if($cur_mode eq "PRINT"){
            my $callback_output;
            my $callback_scope;
            my $msg=$f_parse->($l);
            if($msg){
                if(ref($msg) eq "ARRAY"){
                    print "[$cur_file:$cur_line]\x1b[32m return [ARRAY] deprecated. Use NEWBLOCK and &replace_output instead.\n\x1b[0m";
                }
                elsif($msg=~/^NEWBLOCK(.*)/){
                    if($1=~/^-(.*)/){
                        $callback_scope=$1;
                    }
                    $callback_output=$named_blocks{NEWBLOCK};
                }
                elsif($msg=~/^SKIPBLOCK(.*)/){
                    my $blk=grabblock($block, \$lindex);
                    if($1=~/^-(\w+)/){
                        $named_blocks{$1}=$blk;
                    }
                    last;
                }
                elsif($msg=~/^CALLBACK\b/){
                    my $blk=grabblock($block, \$lindex);
                    $parse_capture=[];
                    parseblock({source=>$blk, name=>"capture"});
                    $named_blocks{last_grab}=$parse_capture;
                    undef $parse_capture;
                    $f_parse->($msg);
                    $named_blocks{last_grab}=undef;
                }
                elsif($msg=~/^SET:(\w+)=(.*)/){
                    $deflist->[-1]->{$1}=$2;
                    last;
                }
                elsif($msg=~/^PARSE:(.*)/){
                    $l=$1;
                    next;
                }
                if($callback_output){
                    my $subblock=grabblock($block, \$lindex);
                    foreach my $l (@$callback_output){
                        if($l=~/^BLOCK$/){
                            parseblock({source=>$subblock, name=>"BLOCK", scope=>$callback_scope});
                        }
                        elsif($l=~/^PARSE:(.*)/){
                            $f_parse->($1);
                        }
                        else{
                            $f_parse->($l);
                        }
                    }
                }
            }
        }
        elsif($cur_mode eq "template"){
            if($l=~/^(\s*)\$call\s+(.+)/){
                my ($func, $param)=("\$call", $2);
                my $len = MyDef::parseutil::get_indent_spaces($1);
                my $n = int($len/4);
                if($len%4){
                    $n++;
                }
                for(my $i=0; $i <$n; $i++){
                    push @$out, "INDENT";
                }
                $param=~s/\s*$//;
                if($func eq "\$map"){
                    map_sub($param, $func);
                }
                elsif($func =~ "^\$call-(PRINT|template)"){
                    special_sub($param, $1);
                }
                elsif($func =~ /^\$call/){
                    call_sub($param);
                }
                elsif($func eq "\&call"){
                    my $subblock=grabblock($block, \$lindex);
                    call_back($param, $subblock);
                }
                elsif($func eq "\$nest"){
                    my $subblock=grabblock($block, \$lindex);
                    my @tlist = MyDef::utils::proper_split($param);
                    my $codename=shift @tlist;
                    my $param_0 = shift @tlist;
                    my @t_block;
                    my $n = @tlist;
                    foreach my $t (@tlist){
                        push @t_block, "&call $codename, $t";
                        push @t_block, "SOURCE_INDENT";
                    }
                    foreach my $l (@$subblock){
                        push @t_block, $l;
                    }
                    for(my $i=0; $i <$n; $i++){
                        push @t_block, "SOURCE_DEDENT";
                    }
                    call_back("$codename, $param_0", \@t_block);
                }
                for(my $i=0; $i <$n; $i++){
                    push @$out, "DEDENT";
                }
            }
            else{
                push @$out, $l;
            }
        }
        else{
            if(!$l){
            }
            elsif($l=~/^\$\((.*)\)/){
                my $preproc=$1;
                my $tail=$';
                expand_macro(\$preproc);
                my $flag_done;
                $flag_done=1;
                if($preproc=~/^if:\s*(.*)/){
                    my $subblock=grabblock($block, \$lindex);
                    if(testcondition($1)){
                        parseblock({source=>$subblock, name=>"\${if:}"});
                        $switch_context="off";
                    }
                    else{
                        $switch_context="on";
                    }
                    if($debug eq "preproc"){
                        print "parse_preproc_if: ($1) -> $switch_context\n";
                    }
                }
                elsif($preproc=~/^els?e?if:\s*(.*)/){
                    my $subblock=grabblock($block, \$lindex);
                    if($switch_context eq "on"){
                        if(testcondition($1)){
                            parseblock({source=>$subblock, name=>"\${if:}"});
                            $switch_context="off";
                        }
                        else{
                            $switch_context="on";
                        }
                        if($debug eq "preproc"){
                            print "parse_preproc_if: ($1) -> $switch_context\n";
                        }
                    }
                }
                elsif($preproc=~/^else/){
                    my $subblock=grabblock($block, \$lindex);
                    if($switch_context eq "on"){
                        parseblock({source=>$subblock, name=>"\${else}"});
                        undef $switch_context;
                    }
                }
                elsif($preproc=~/^ifeach:\s*(.*)/){
                    my $subblock=grabblock($block, \$lindex);
                    my $cond=$1;
                    my $plist=$deflist->[-1]->{plist};
                    undef $switch_context;
                    my $cond_var="p";
                    if($cond=~/^(\w+)/){
                        $cond_var=$1;
                    }
                    if($plist){
                        my @plist=split /,\s*/, $plist;
                        foreach my $p (@plist){
                            my $macro={$cond_var=>$p};
                            push @$deflist, $macro;
                            if(testcondition($cond)){
                                parseblock({source=>$subblock, name=>"\${ifeach:}"});
                                $switch_context="off";
                            }
                            pop @$deflist;
                        }
                    }
                    if(!$switch_context){
                        $switch_context="on";
                    }
                }
                else{
                    $flag_done=0;
                    undef $switch_context;
                }
                if(!$flag_done){
                    undef $switch_context;
                    if($preproc=~/^for:\s*(.*)/){
                        my $t=$1;
                        my $subblock=grabblock($block, \$lindex);
                        if($t=~/(\w+)\s+in\s+(.*)/){
                            my ($vname, $vparam)=($1,$2);
                            my @tlist;
                            if($vparam=~/(\d+)\.\.(\d+)/){
                                for(my $i=$1;$i<=$2;$i++){
                                    push @tlist, $i;
                                }
                            }
                            else{
                                @tlist=split /,\s*/, $vparam;
                            }
                            my $i=0;
                            foreach my $t (@tlist){
                                my $macro={$vname=>$t, _i=>$i};
                                push @$deflist, $macro;
                                parseblock({source=>$subblock, name=>"\${for}"});
                                pop @$deflist;
                                $i++;
                            }
                        }
                        else{
                            my @vlist=split /\s+and\s+/, $t;
                            my $n;
                            my @tlist;
                            foreach my $v (@vlist){
                                my @t=split /,\s*/, $v;
                                if(!$n){
                                    $n=@t;
                                }
                                push @tlist, \@t;
                            }
                            my $m = @tlist;
                            for(my $i=0; $i <$n; $i++){
                                my @block = @$subblock;
                                foreach my $l (@block){
                                    if($l and $l!~/^SOURCE:/){
                                        my $j=1;
                                        foreach my $tlist (@tlist){
                                            $l=~s/\$$j/$tlist->[$i]/g;
                                            $j++;
                                        }
                                    }
                                }
                                parseblock({source=>\@block, name=>"\${for:list}"});
                            }
                        }
                    }
                    elsif($preproc=~/^foreach:p/){
                        my $subblock=grabblock($block, \$lindex);
                        my $plist=$deflist->[-1]->{plist};
                        if($plist){
                            my @plist=MyDef::utils::proper_split($plist);
                            my $i=0;
                            foreach my $p (@plist){
                                my $macro={"p"=>$p, "i"=>$i};
                                push @$deflist, $macro;
                                parseblock({source=>$subblock, name=>"\${foreach}"});
                                pop @$deflist;
                                $i++;
                            }
                        }
                        else{
                            warn "[$cur_file:$cur_line]\x24(foreach:p) missing \x24(plist)\n";
                        }
                    }
                    elsif($preproc=~/^set:\s*(\w+)$/){
                        my $name=$1;
                        if(!$tail){
                            $deflist->[-1]->{$name}="";
                        }
                        else{
                            $tail=~s/^\s+//;
                            my @tlist=MyDef::utils::proper_split($tail);
                            my $verb=shift @tlist;
                            if($verb eq "join"){
                                my $sep=shift @tlist;
                                my $pat=shift @tlist;
                                if($sep=~/^["'](.*)["']$/){
                                    $sep=$1;
                                }
                                if($pat=~/^["'](.*)["']$/){
                                    $pat=$1;
                                }
                                my $subblock=grabblock($block, \$lindex);
                                my @out_list;
                                if($pat){
                                    foreach my $t (@$subblock){
                                        if($t!~/^SOURCE:/){
                                            push @tlist, MyDef::utils::proper_split($t);
                                        }
                                    }
                                    foreach my $t2 (@tlist){
                                        my $t3=$pat;
                                        $t3=~s/\*/$t2/g;
                                        push @out_list, $t3;
                                    }
                                }
                                else{
                                    foreach my $t (@$subblock){
                                        if($t!~/^SOURCE:/){
                                            expand_macro(\$t);
                                            push @out_list, $t;
                                        }
                                    }
                                }
                                $deflist->[-1]->{$name}= join($sep, @out_list);
                            }
                        }
                    }
                    elsif($preproc=~/^set:\s*(\w+)\)/){
                        my $name=$1;
                        if($l=~/^\$\(set:\s*\w+\)(.*)/){
                            $tail=$1;
                        }
                        if(!$tail){
                            $deflist->[-1]->{$name}="";
                        }
                        else{
                            $tail=~s/^\s+//;
                            my @tlist=MyDef::utils::proper_split($tail);
                            my $verb=shift @tlist;
                            if($verb eq "join"){
                                my $sep=shift @tlist;
                                my $pat=shift @tlist;
                                if($sep=~/^["'](.*)["']$/){
                                    $sep=$1;
                                }
                                if($pat=~/^["'](.*)["']$/){
                                    $pat=$1;
                                }
                                my $subblock=grabblock($block, \$lindex);
                                my @out_list;
                                if($pat){
                                    foreach my $t (@$subblock){
                                        if($t!~/^SOURCE:/){
                                            push @tlist, MyDef::utils::proper_split($t);
                                        }
                                    }
                                    foreach my $t2 (@tlist){
                                        my $t3=$pat;
                                        $t3=~s/\*/$t2/g;
                                        push @out_list, $t3;
                                    }
                                }
                                else{
                                    foreach my $t (@$subblock){
                                        if($t!~/^SOURCE:/){
                                            expand_macro(\$t);
                                            push @out_list, $t;
                                        }
                                    }
                                }
                                $deflist->[-1]->{$name}= join($sep, @out_list);
                            }
                        }
                    }
                    elsif($preproc=~/^set:\s*(.*)/){
                        set_macro($deflist->[-1], $1);
                    }
                    elsif($preproc=~/^set([012]):\s*(.*)/){
                        set_macro($deflist->[$1], $2);
                    }
                    elsif($preproc=~/^setmacro:\s*(.*)/){
                        set_macro($deflist->[2], $1);
                    }
                    elsif($preproc=~/^unset:\s*(.*)/){
                        my @t = split /,\s*/, $1;
                        foreach my $t (@t){
                            if($t=~/^(\w+)/){
                                $deflist->[-1]->{$t}=undef;
                            }
                            else{
                                print "[$cur_file:$cur_line]\x1b[32m unset only accepts single word(s)\n\x1b[0m";
                            }
                        }
                    }
                    elsif($preproc=~/^autoinc:\s*(\w+)/){
                        my $page=$deflist->[2];
                        $page->{$1}++;
                    }
                    elsif($preproc=~/^enuminc:\s*(\w+)/){
                        my $page=$deflist->[2];
                        if(!$page->{$1}){
                            my $key = $1;
                            my $base = "_enumbase_";
                            if($key=~/^([^_]+)_/){
                                $base = $1;
                            }
                            $page->{$base}++;
                            $page->{$key}=$page->{$base};
                        }
                    }
                    elsif($preproc=~/^enumset:\s*(.*)/){
                        my @t = split /,\s*/, $1;
                        my $base = 1;
                        my $m = $deflist->[-1];
                        foreach my $t (@t){
                            $m->{$t}=$base;
                            $base++;
                        }
                    }
                    elsif($preproc=~/^export:\s*(.*)/){
                        my $t=$1;
                        if($t=~/^\w+,/){
                            my @plist=split /,\s*/, $t;
                            foreach my $p (@plist){
                                set_macro($deflist->[-2], $p);
                            }
                        }
                        else{
                            set_macro($deflist->[-2], $t);
                        }
                    }
                    elsif($preproc=~/^mset:\s*(.*)/){
                        my @plist=split /,\s*/, $1;
                        foreach my $p (@plist){
                            set_macro($deflist->[-1], $p);
                        }
                    }
                    elsif($preproc=~/^mexport:\s*(.*)/){
                        my @plist=split /,\s*/, $1;
                        foreach my $p (@plist){
                            set_macro($deflist->[-2], $p);
                        }
                    }
                    elsif($preproc=~/^reset:\s*(\w+)([\.\+\-])?=(.*)/){
                        my ($v, $op, $d)=($1, $2, $3, $4);
                        expand_macro(\$d);
                        my $i=$#$deflist;
                        while($i>0 and !defined $deflist->[$i]->{$v}){
                            $i--;
                        }
                        if($i==0){
                            $i=-1;
                        }
                        if($op){
                            $deflist->[$i]->{$v}=calc_op($deflist->[$i]->{$v}, $op, $d);
                        }
                        else{
                            $deflist->[$i]->{$v}=$d;
                        }
                    }
                    elsif($preproc=~/^unset:\s*(\w+)/){
                        foreach my $m (@$deflist){
                            delete $m->{$1};
                        }
                    }
                    elsif($preproc=~/^eval:\s*(\w+)=(.*)/){
                        my ($t1,$t2)=($1,$2);
                        expand_macro(\$t2);
                        $deflist->[-1]->{$t1}=eval($t2);
                    }
                    elsif($preproc=~/^split:\s*(\w+)$/){
                        my $p="\$($1)";
                        expand_macro(\$p);
                        my @tlist=MyDef::utils::proper_split($p);
                        my $n=@tlist;
                        $deflist->[-1]->{p_n}=$n;
                        for(my $i=1; $i <$n+1; $i++){
                            $deflist->[-1]->{"p_$i"}=$tlist[$i-1];
                        }
                    }
                    elsif($preproc=~/^split:([^:]+):\s*(\w+)/){
                        my $p="\$($2)";
                        expand_macro(\$p);
                        my @tlist=split /$1/, $p;
                        my $n=@tlist;
                        $deflist->[-1]->{p_n}=$n;
                        for(my $i=1; $i <$n+1; $i++){
                            $deflist->[-1]->{"p_$i"}=$tlist[$i-1];
                        }
                    }
                    elsif($preproc=~/^ogdl_/){
                        expand_macro(\$preproc);
                        if($preproc=~/^ogdl_load:\s*(\w+)/){
                            get_ogdl($1);
                        }
                        elsif($preproc=~/^ogdl_each/){
                            my $subblock=grabblock($block, \$lindex);
                            my $itemlist=$cur_ogdl->{_list};
                            push @ogdl_stack, $cur_ogdl;
                            foreach my $item (@$itemlist){
                                $cur_ogdl=$item;
                                parseblock({source=>$subblock, name=>"\${ogdl_each}"});
                            }
                            $cur_ogdl=pop @ogdl_stack;
                        }
                        elsif($preproc=~/^ogdl_set_path:(\d+)=(.*)/){
                            $ogdl_path[$1]=$2;
                        }
                        elsif($preproc=~/^ogdl_path_init/){
                            $ogdl_path_index_base=0;
                        }
                        elsif($preproc=~/^ogdl_path:(\d+)/){
                            splice @ogdl_path, $1+1;
                            my $path=join('/', @ogdl_path);
                            $ogdl_path_index{$path}=$ogdl_path_index_base;
                            $deflist->[-1]->{path}=$path;
                            $deflist->[-1]->{path_index}=$ogdl_path_index_base;
                            $ogdl_path_index_base++;
                        }
                        elsif($preproc=~/^ogdl_get:(\w+)=(.*)/){
                            my $key=$1;
                            my $val;
                            my @klist=split /,\s*/, $2;
                            foreach my $k (@klist){
                                if(defined $cur_ogdl->{$k}){
                                    $val=$cur_ogdl->{$k};
                                }
                                else{
                                    $val=$k;
                                }
                            }
                            $deflist->[-1]->{$key}=$val;
                        }
                        elsif($preproc=~/^ogdl_get:(\w+)/){
                            $deflist->[-1]->{$1}=$cur_ogdl->{$1};
                        }
                    }
                    elsif($preproc=~/^list_init:(\w+)/){
                        $list_list{$1}=[];
                    }
                    elsif($preproc=~/^list_push:(\w+)=(.*)/){
                        push @{$list_list{$1}}, $2;
                    }
                    elsif($preproc=~/^list_set:(\w+),(\d+)=(.*)/){
                        $list_list{$1}->[$2]=$3;
                    }
                    elsif($preproc=~/^list_each:(\w+)/){
                        my $key=$1;
                        my $subblock=grabblock($block, \$lindex);
                        my $idx=0;
                        foreach my $val (@{$list_list{$key}}){
                            $deflist->[-1]->{idx}=$idx;
                            $deflist->[-1]->{val}=$val;
                            parseblock({source=>$subblock, name=>"list_each $key"});
                            $idx++;
                        }
                    }
                    elsif($preproc=~/^hash_init:(\w+)/){
                        $list_hash{$1}={};
                    }
                    elsif($preproc=~/^hash_set:(\w+),([^=]+)=(.*)/){
                        $list_hash{$1}->{$2}=$3;
                    }
                    elsif($preproc=~/^allow_recurse:(\d+)/){
                        my $code=$block_stack[-1]->{code};
                        if($code->{allow_recurse}){
                            $deflist->[-1]->{recurse}=$code->{recurse};
                        }
                        else{
                            $code->{allow_recurse}=$1;
                            $deflist->[-1]->{recurse}=0;
                        }
                    }
                    elsif($preproc=~/^_init_block$/){
                        my $idx=$block_stack[-1]->{eindex};
                        push @$out, "DUMP_STUB _init_$idx";
                        my $page=$deflist->[2];
                        $page->{_init_block}="_init_$idx";
                    }
                    elsif($preproc=~/^block:\s*(\w+)/){
                        my $name=$1;
                        my $subblock=grabblock($block, \$lindex);
                        my $output=get_named_block($name);
                        my $temp=$out;
                        set_output($output);
                        parseblock({source=>$subblock, name=>"block:$name"});
                        set_output($temp);
                    }
                    else{
                        goto NormalParse;
                    }
                }
            }
            elsif($l=~/^\$:\s+(.*)/){
                push @$out, $1;
            }
            elsif($l=~/^BLOCK\s*$/){
                if($#callback_block_stack <0){
                    print "\@block_stack:\n";
                    foreach my $blk (@block_stack){
                        print "    $blk->{code}->{name} $blk->{file}:$blk->{line}\n";
                    }
                    print "[$cur_file:$cur_line] \x1b[33mBLOCK called out of context!\x1b[0m\n";
                }
                else{
                    my $block=pop @callback_block_stack;
                    my $depth=$#callback_block_stack+1;
                    if($debug){
                        print "BLOCK [$cur_file:$cur_line] -> [$block->{cur_file}: $block->{cur_line}] depth=$depth: ";
                        foreach my $b (@callback_block_stack){
                            print "$b->{name}, ";
                        }
                        print $block->{name}, "\n";
                    }
                    parseblock($block);
                    push @callback_block_stack, $block;
                }
            }
            else{
                NormalParse:
                expand_macro(\$l);
                while(1){
                    if($l=~/^(&call|\$call|\$map|\$nest|\$call-PRINT|\$call-template)\s+(.*)$/){
                        my ($func, $param)=($1, $2);
                        $param=~s/\s*$//;
                        if($func eq "\$map"){
                            map_sub($param, $func);
                        }
                        elsif($func =~ "^\$call-(PRINT|template)"){
                            special_sub($param, $1);
                        }
                        elsif($func =~ /^\$call/){
                            call_sub($param);
                        }
                        elsif($func eq "\&call"){
                            my $subblock=grabblock($block, \$lindex);
                            call_back($param, $subblock);
                        }
                        elsif($func eq "\$nest"){
                            my $subblock=grabblock($block, \$lindex);
                            my @tlist = MyDef::utils::proper_split($param);
                            my $codename=shift @tlist;
                            my $param_0 = shift @tlist;
                            my @t_block;
                            my $n = @tlist;
                            foreach my $t (@tlist){
                                push @t_block, "&call $codename, $t";
                                push @t_block, "SOURCE_INDENT";
                            }
                            foreach my $l (@$subblock){
                                push @t_block, $l;
                            }
                            for(my $i=0; $i <$n; $i++){
                                push @t_block, "SOURCE_DEDENT";
                            }
                            call_back("$codename, $param_0", \@t_block);
                        }
                    }
                    elsif($l=~/^\$-:\s*(.*)/){
                        push @$out, "MAKE_STRING:$1";
                        my $subblock=grabblock($block, \$lindex);
                        $MAKE_STRING++;
                        parseblock({source=>$subblock, name=>"MAKE_STRING"});
                        $MAKE_STRING--;
                        push @$out, "POP_STRING";
                    }
                    elsif(defined $parse_capture){
                        push @$parse_capture, $l;
                    }
                    elsif($MAKE_STRING>0){
                        push @$out, $l;
                    }
                    else{
                        my $callback_output;
                        my $callback_scope;
                        my $msg=$f_parse->($l);
                        if($msg){
                            if(ref($msg) eq "ARRAY"){
                                print "[$cur_file:$cur_line]\x1b[32m return [ARRAY] deprecated. Use NEWBLOCK and &replace_output instead.\n\x1b[0m";
                            }
                            elsif($msg=~/^NEWBLOCK(.*)/){
                                if($1=~/^-(.*)/){
                                    $callback_scope=$1;
                                }
                                $callback_output=$named_blocks{NEWBLOCK};
                            }
                            elsif($msg=~/^SKIPBLOCK(.*)/){
                                my $blk=grabblock($block, \$lindex);
                                if($1=~/^-(\w+)/){
                                    $named_blocks{$1}=$blk;
                                }
                                last;
                            }
                            elsif($msg=~/^CALLBACK\b/){
                                my $blk=grabblock($block, \$lindex);
                                $parse_capture=[];
                                parseblock({source=>$blk, name=>"capture"});
                                $named_blocks{last_grab}=$parse_capture;
                                undef $parse_capture;
                                $f_parse->($msg);
                                $named_blocks{last_grab}=undef;
                            }
                            elsif($msg=~/^SET:(\w+)=(.*)/){
                                $deflist->[-1]->{$1}=$2;
                                last;
                            }
                            elsif($msg=~/^PARSE:(.*)/){
                                $l=$1;
                                next;
                            }
                            if($callback_output){
                                my $subblock=grabblock($block, \$lindex);
                                foreach my $l (@$callback_output){
                                    if($l=~/^BLOCK$/){
                                        parseblock({source=>$subblock, name=>"BLOCK", scope=>$callback_scope});
                                    }
                                    elsif($l=~/^PARSE:(.*)/){
                                        $f_parse->($1);
                                    }
                                    else{
                                        $f_parse->($l);
                                    }
                                }
                            }
                        }
                    }
                    last;
                }
            }
        }
    }
    parse_stack_pop();
}

sub parse_stack_push {
    my ($code) = @_;
    $block_index++;
    my $blk= {out=>$out, index=>$block_index, eindex=>$block_index, file=>$cur_file, line=>$cur_line, code=>$code};
    push @block_stack, $blk;
    if($code->{"scope"}){
        my $idx=$block_index;
        my $scope=$code->{scope};
        $blk->{scope}=$scope;
        $f_parse->("SUBBLOCK BEGIN $idx $scope");
        push @$out, "DUMP_STUB block$idx\_pre";
    }
}

sub parse_stack_pop {
    my $blk=$block_stack[-1];
    my $idx=$blk->{index};
    if($blk->{scope}){
        $f_parse->("SUBBLOCK END $blk->{index} $blk->{scope}");
    }
    pop @block_stack;
    $cur_file=$blk->{file};
    $cur_line=$blk->{line};
    if($named_blocks{"block$idx\_post"}){
        push @$out, "DUMP_STUB block$idx\_post";
    }
    if($blk->{debug}){
        $debug=0;
        $f_parse->("DEBUG OFF");
    }
    elsif($blk->{debug_off}){
        $debug=$blk->{debug_off};
        $f_parse->("DEBUG $debug");
    }
}

sub curfile_curline {
    return "$cur_file:$cur_line";
}

sub protect_key {
    my ($key) = @_;
    foreach my $blk (@block_stack){
        if($blk->{$key}){
            die "[$cur_file:$cur_line] Block Key Collision: [$key]\n";
        }
    }
    $block_stack[-1]->{$key}=1;
}

sub expand_macro {
    my ($lref) = @_;
    $$lref=~s/(?<=\$)\.(?=\w)/(this)/g;
    while($$lref=~/\$\(\w/){
        my $t=$$lref;
        $$lref=MyDef::utils::expand_macro($t, \&get_macro);
        if($t eq $$lref){
            last;
        }
    }
}

sub get_macro {
    my ($s, $nowarn) = @_;
    if($s=~/^((rep|perl|eval|map|or|and|sym|def)\b.+)/){
        my $t=$1;
        if($t=~/^rep\[(.*?)\](\d+):(.*)/){
            if($2>1){
                return "$3$1" x ($2-1) . $3;
            }
            else{
                die "Illegal rep macro in \"$s\"!\n";
            }
        }
        elsif($t=~/^perl:(.*)/){
            my $outdir=".";
            if($MyDef::var->{output_dir}){
                $outdir=$MyDef::var->{output_dir};
            }
            my $defname=$MyDef::def->{name};
            my $t=$1;
            $t=~s/,/ /g;
            if(open In, "perl $outdir/perl-$defname.pl $t|"){
                my $t=<In>;
                close In;
                return $t;
            }
            else{
                die "Failed perl $outdir/perl-$defname.pl\n";
            }
        }
        elsif($t=~/^eval:\s+(.*)/){
            return eval($1);
        }
        elsif($t=~/^map\s+(.*):(.*):(.*)/){
            my ($pat, $sep)=($1, $3);
            my @tlist=split /\|/, $2;
            my @segs;
            foreach my $t (@tlist){
                my $p=$pat;
                $p=~s/\$1/$t/g;
                push @segs, $p;
            }
            return join(" $sep ", @segs);
        }
        elsif($t =~ /^(or|and):\s*(.*?):\s*(.*)/){
            my $sep=" $1 ";
            my $pat=$2;
            my @tlist=split /,\s*/, $3;
            my @segs;
            foreach my $t (@tlist){
                my $tt=$pat;
                $tt=~s/\*/$t/g;
                push @segs, $tt;
            }
            return join($sep, @segs);
        }
        elsif($t =~ /^sym:(.+)/){
            return MyDef::utils::string_symbol_name($1);
        }
        elsif($t =~ /^def:(.+)/){
            my $t;
            if($MyDef::def->{file}){
                my @t = stat($MyDef::def->{file});
                $t=$t[9];
            }
            else{
                $t = time;
            }
            my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($t);
            if($1 eq "date"){
                return sprintf("%4d-%02d-%02d", $year+1900, $mon+1, $mday);
            }
            elsif($1 eq "datetime"){
                return sprintf("%4d-%02d-%02d %02d:%02d", $year+1900, $mon+1, $mday, $hour, $min);
            }
            elsif($1 eq "name"){
                return $MyDef::def->{name};
            }
            else{
                return "";
            }
        }
        else{
            warn " [$cur_file:$cur_line] syntax error: [$s]\n";
            return undef;
        }
    }
    elsif($s=~/^(\w+):(.*)/){
        my $p=$2;
        my $t=get_macro_word($1, $nowarn);
        if($t){
            if($p=~/(\d+)-(\d+)/){
                my $s=substr($t, $1, $2-$1+1);
                return $s;
            }
            elsif($p=~/(\d+):(\d+|word|number|strip)/){
                my $s=substr($t, $1);
                if($2 eq "word"){
                    if($s=~/^\s*(\w+)/){
                        $s=$1;
                    }
                }
                elsif($2 eq "number"){
                    if($s=~/^\s*([+-]?\d+)/){
                        $s=$1;
                    }
                }
                elsif($2 ne "strip"){
                    $s=substr($s, 0, $2);
                }
                return $s;
            }
            elsif($p eq "len"){
                return length($t);
            }
            elsif($p eq "strlen"){
                if($t=~/^".*"$/){
                    return eval "length($t)";
                }
                else{
                    return length($t);
                }
            }
            elsif($p eq "strip"){
                return substr($t, 1, -1);
            }
            elsif($p=~/list:(.*)/){
                my $idx=$1;
                my @tlist=MyDef::utils::proper_split($t);
                if($idx eq "n"){
                    return scalar(@tlist);
                }
                elsif($idx=~/(\d+)/){
                    return $tlist[$1];
                }
                elsif($idx=~/(.*)\*(.*)/){
                    foreach my $t (@tlist){
                        $t = "$1$t$2";
                    }
                    return join(", ", @tlist);
                }
            }
            else{
                my @plist;
                @plist=MyDef::utils::proper_split($p);
                my $i=1;
                foreach my $pp (@plist){
                    $t=~s/\$$i/$pp/g;
                    $i++;
                }
                return $t;
            }
        }
    }
    elsif($s=~/^([mg])([\|&]+):(.*)/){
        my ($m, $sep, $t)=($1, $2, $3);
        my @tlist;
        if($t=~/^(.*==\s*)(.*)$/){
            my ($pre, $t)=($1, $2);
            my @t = split /,\s*/, $t;
            foreach my $tt (@t){
                push @tlist, "$pre$tt";
            }
        }
        else{
            print "failed to parse multiplex macro [$sep][$t]\n";
        }
        if($m eq "g"){
            return '('.join(" $sep ", @tlist).')';
        }
        else{
            return join(" $sep ", @tlist);
        }
    }
    elsif($s=~/^(.+)/){
        return get_macro_word($1, $nowarn);
    }
}

sub get_macro_word {
    my ($name, $nowarn) = @_;
    for(my $j=$#$deflist; $j >=-1; $j--){
        my $macros=$deflist->[$j];
        if(exists($macros->{$name})){
            return $macros->{$name};
        }
    }
    if(!$nowarn){
        warn "[$cur_file:$cur_line] Macro $name not defined\n";
    }
    return undef;
}

sub set_interface {
    ($f_init, $f_parse, $f_setout, $f_modeswitch, $f_dumpout)=@_;
}
sub get_interface {
    return ($f_init, $f_parse, $f_setout, $f_modeswitch, $f_dumpout);
}
sub set_output {
    my ($output)=@_;
    my $old=$out;
    $out=$output;
    $f_setout->($out);
    return $old;
}
sub init_output {
    @output_list=([]);
    set_output($output_list[0]);
    %named_blocks=();
}
sub new_output {
    my $new_out=[];
    push @output_list, $new_out;
    my $nidx=$#output_list;
    return $nidx;
}
sub fetch_output {
    my $n=shift;
    return $output_list[$n];
}
sub test_op {
    my ($a, $test)=@_;
    if($debug eq "preproc"){
        print "preproc test_op: $a: $test\n";
    }
    if($test=~/^:(\d+)/){
        $test=$';
        $a=substr($a, 0, $1);
    }
    if($test=~/\s*(~|=|!=|<=?|>=?)(.*)/){
        my ($op, $b)=($1, $2);
        if($op eq "="){
            if($a eq $b){ return 1;};
        }
        elsif($op eq "!="){
            if($a ne $b){ return 1;};
        }
        elsif($op eq ">"){
            if($a > $b){ return 1;};
        }
        elsif($op eq "<"){
            if($a < $b){ return 1;};
        }
        elsif($op eq ">="){
            if($a >= $b){ return 1;};
        }
        elsif($op eq "<="){
            if($a <= $b){ return 1;};
        }
        elsif($op eq "~"){
            if($a=~/^$b/){ return 1;};
        }
        else{
            return 0;
        }
    }
    elsif($test=~/\s*in\s+(.*)/){
        return test_in($a, $1);
    }
    else{
        return defined $a;
    }
}
sub test_in {
    my ($a, $test)=@_;
    my @tlist=split /,\s*/, $test;
    foreach my $t (@tlist){
        if($t=~/(\S)-(\S)/){
            if(ord($a)>=ord($1) and ord($a)<=ord($2)){
                return 1;
            }
        }
        elsif($a eq $t){
            return 1;
        }
    }
    return 0;
}
sub testcondition {
    my ($cond)=@_;
    if($debug eq "preproc"){
        print "preproc testcondition: $cond\n";
    }
    if(!$cond){
        return 0;
    }
    elsif($cond=~/^ogdl_/){
        if($cond=~/^ogdl_text/){
            return !ref($cur_ogdl);
        }
        elsif($cond=~/^ogdl_list/){
            if(ref($cur_ogdl) eq "HASH"){
                my $tlist=$cur_ogdl->{_list};
                if(@$tlist){
                    return 1;
                }
            }
            return 0;
        }
        elsif($cond=~/^ogdl_text:(.*)/){
            if(ref($cur_ogdl) eq "SCALAR"){
                return $cur_ogdl eq $1;
            }
            else{
                return ($cur_ogdl->{_name} eq $1);
            }
        }
        elsif($cond=~/^ogdl_attr:(\w+)(.*)/){
            if(ref($cur_ogdl) ne "HASH"){
                if($1 eq "_text"){
                    return test_op($cur_ogdl, $2);
                }
                else{
                    return 0;
                }
            }
            else{
                my $t=$cur_ogdl->{$1};
                return test_op($t, $2);
            }
        }
    }
    elsif($cond=~/^\s*!(.*)/){
        return !testcondition($1);
    }
    elsif($cond=~/ or /){
        my @nlist=split / or /, $cond;
        foreach my $n (@nlist){
            if(testcondition($n)){
                return 1;
            }
        }
        return 0;
    }
    elsif($cond=~/ and /){
        my @nlist=split / and /, $cond;
        foreach my $n (@nlist){
            if(!testcondition($n)){
                return 0;
            }
        }
        return 1;
    }
    elsif($cond=~/^([01])$/){
        return $1;
    }
    elsif($cond=~/^hascode:\s*(\w+)/){
        my $codelib = get_def_attr("codes", $1);
        if($codelib){
            return 1;
        }
    }
    elsif($cond=~/^(string|number|word):(.*)/){
        my $test=$1;
        my $t=get_def($2);
        if($test eq "string" and $t=~/^['"]/){
            return 1;
        }
        elsif($test eq "number" and $t=~/^\d+/){
            return 1;
        }
        elsif($test eq "word" and $t=~/^[a-zA-Z_]\w*$/){
            return 1;
        }
    }
    elsif($cond=~/^\s*(\w+)(.*)/){
        my $t=get_def($1);
        if(!$2){
            return defined $t;
        }
        else{
            return test_op($t, $2);
        }
    }
    else{
        return 0;
    }
    return 0;
}
sub calc_op {
    my ($v, $op, $d)=@_;
    if($op eq "."){
        return $v . $d;
    }
    my $ret=get_numeric($v);
    if($op eq "+"){
        $ret+=get_numeric($d);
    }
    elsif($op eq "-"){
        $ret-=get_numeric($d);
    }
    if($v=~/^0x/){
        return sprintf("0x%lx", $ret);
    }
    else{
        return $ret;
    }
}
sub get_numeric {
    my ($v)=@_;
    if($v=~/0x(.*)/){
        return hex($v);
    }
    else{
        return $v;
    }
}
sub set_macro {
    my ($m, $p)=@_;
    if($debug eq "macro"){
        print "set_macro: [$p]\n";
    }
    if($p=~/(\w+)([\+\-\*\/\.])=(\d+)/){
        my ($t1, $op, $num)=($1, $2, $3);
        if($op eq "+"){
            $m->{$t1}+=$num;
        }
        elsif($op eq "*"){
            $m->{$t1}*=$num;
        }
        elsif($op eq "."){
            $m->{$t1}.=$num;
        }
        elsif($op eq "/"){
            $m->{$t1}/=$num;
        }
        elsif($op eq "-"){
            $m->{$t1}/=$num;
        }
    }
    elsif($p=~/(\S+?)=(.*)/){
        my ($t1, $t2)=($1, $2);
        if($t1=~/\$\(.*\)/){
            expand_macro(\$t1);
        }
        if($t2=~/\$\(.*\)/){
            expand_macro(\$t2);
        }
        $m->{$t1}=$t2;
    }
    else{
        my $t=get_def($p);
        if(defined $t){
            $m->{$p}=$t;
        }
        else{
            print "[$cur_file:$cur_line]\x1b[32m set_macro parse error: [$p]\n\x1b[0m";
        }
    }
}
sub set_current_macro {
    my ($name, $val)=@_;
    $deflist->[-1]->{$name}=$val;
}
sub export_macro {
    my ($i, $name, $val)=@_;
    $deflist->[$i]->{$name}=$val;
}
sub get_current_macro {
    my ($name)=@_;
    return $deflist->[-1]->{$name};
}
sub get_ogdl {
    my ($name)=@_;
    $cur_ogdl=$MyDef::def->{resource}->{$name};
    if(!$cur_ogdl){
        die "Resource $name does not exist!\n";
    }
    else{
        if($cur_ogdl->{_parents}){
            my @parent_list=@{$cur_ogdl->{_parents}};
            while(my $pname=pop @parent_list){
                my $ogdl=$MyDef::def->{resource}->{$pname};
                if($ogdl){
                    while(my ($k, $v)=each %$ogdl){
                        if(!$cur_ogdl->{$k}){
                            $cur_ogdl->{$k}=$v;
                        }
                        elsif($k eq "_list"){
                            if(@$v){
                                unshift @{$cur_ogdl->{_list}}, @$v;
                            }
                        }
                    }
                }
            }
        }
        return $cur_ogdl;
    }
}
sub get_cur_code {
    return ($block_stack[-1]->{code}, $cur_file, $cur_line);
}
sub get_def {
    my ($name)=@_;
    return get_macro_word($name, 1);
}
sub get_def_attr {
    my ($name, $attr)=@_;
    for(my $i=$#$deflist; $i >=-1; $i--){
        my $t=$deflist->[$i]->{$name};
        if($t and $t->{$attr}){
            return $t->{$attr};
        }
    }
    return undef;
}
sub set_named_block {
    my ($name, $block)=@_;
    $named_blocks{$name}=$block;
}
sub get_named_block {
    my ($name)=@_;
    if($name=~/^_(post|pre)(\d*)$/){
        my $idx;
        if(!$2){
            $idx=$block_stack[-1]->{eindex};
        }
        else{
            $idx=$block_stack[-$2]->{eindex};
        }
        $name="block$idx\_$1";
    }
    elsif($name=~/^_init_block$/){
        my $page=$deflist->[2];
        $name=$page->{_init_block};
    }
    if(!$named_blocks{$name}){
        $named_blocks{$name}=[];
    }
    return $named_blocks{$name};
}
sub trigger_block_post {
    my $cur_idx=$block_stack[-1]->{eindex};
    my $name="block$cur_idx\_post";
    if($named_blocks{$name}){
        my $new_name=$name.'_';
        push @$out, "DUMP_STUB $new_name";
        $named_blocks{$new_name}=$named_blocks{$name};
        undef $named_blocks{$name};
    }
}
sub modepush {
    my ($mode)=@_;
    $cur_mode=$mode;
    push @mode_stack, $mode;
    $f_modeswitch->($mode, 1);
}
sub modepop {
    pop @mode_stack;
    $cur_mode=$mode_stack[-1];
    $f_modeswitch->($cur_mode, 0);
}
sub grabblock {
    my ($block, $index_ref)=@_;
    my @sub;
    my $indent;
    my $lindex=$$index_ref;
    if($block->[$lindex] ne "SOURCE_INDENT"){
        return \@sub;
    }
    else{
        $indent=1;
        $lindex++;
    }
    push @sub, "SOURCE: $cur_file - $cur_line";
    while($lindex<@$block){
        if($block->[$lindex] eq "SOURCE_DEDENT"){
            $indent-- if $indent>0;
            if($indent==0){
                $lindex++;
                last;
            }
        }
        if($block->[$lindex] eq "SOURCE_INDENT"){
            $indent++;
        }
        push @sub, $block->[$lindex];
        $lindex++;
    }
    $$index_ref=$lindex;
    return \@sub;
}
sub compile {
    my $page=$MyDef::page;
    my $pagename=$page->{pagename};
    my $outdir=".";
    if($MyDef::var->{output_dir}){
        $outdir=$MyDef::var->{output_dir};
    }
    if($page->{output_dir}){
        if($page->{output_dir}=~/^[\/\.]/){
            $outdir=$page->{output_dir};
        }
        else{
            $outdir=$outdir."/".$page->{output_dir};
        }
    }
    $outdir=~s/^\s+//;
    if(! -d $outdir){
        my @tdir_list=split /\//, $outdir;
        my $tdir;
        my $slash=0;
        foreach my $t (@tdir_list){
            if(!$slash){
                $tdir=$t;
                $slash=1;
            }
            else{
                $tdir=$tdir.'/'.$t;
            }
            if(!$tdir){next;};
            if(! -d $tdir){
                mkdir $tdir or die "Can't create output directory: $tdir\n";
            }
        }
    }
    $page->{outdir}=$outdir;
    my $mode=$f_init->($page);
    if($mode){
        modepush($mode);
    }
    init_output();
    print STDERR "PAGE: $pagename\n";
    my %varsave;
    while(my ($k, $v)=each %$page){
        $varsave{$k}=$MyDef::var->{$k};
        $MyDef::var->{$k}=$v;
    }
    $deflist=[$MyDef::def, $MyDef::def->{macros}, $page];
    $in_autoload=1;
    my $codelist=$MyDef::def->{codes};
    foreach my $codename (keys %$codelist){
        if($codename=~/_autoload$/){
            parse_code($codelist->{$codename});
        }
    }
    $in_autoload=0;
    my $maincode=$page->{codes}->{main};
    if(!$maincode){
        $maincode=$MyDef::def->{codes}->{main};
    }
    if(!$maincode){
        $maincode=$MyDef::def->{codes}->{basic_frame};
    }
    if(!$maincode){
        die "Missing maincode\n";
    }
    parse_code($maincode);
    $f_parse->("NOOP POST_MAIN");
    while(my ($k, $v)=each %varsave){
        $MyDef::var->{$k}=$v;
    }
    if(!$page->{subpage}){
        my @buffer;
        $f_dumpout->(\@buffer, fetch_output(0), $page->{pageext});
        return \@buffer;
    }
}
sub output {
    my ($plines)=@_;
    my $page=$MyDef::page;
    my $pagename=$page->{pagename};
    my $pageext=$page->{pageext};
    my $outdir=$page->{outdir};
    my $outname=$outdir."/".$pagename;
    if($pageext){
        $outname.=".$pageext";
    }
    print "  --> [$outname]\n";
    my $n=@$plines;
    if($n==0){
        print "Strange, no output!\n";
    }
    else{
        open Out, ">$outname" or die "Can't write $outname.\n";
        foreach my $l (@$plines){
            print Out $l;
        }
        close Out;
        $page->{outname}=$outname;
    }
}
sub parse_code {
    my ($code)=@_;
    modepush($code->{type});
    parseblock($code);
    modepop();
}
1;
