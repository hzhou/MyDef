package MyDef::compileutil;
our %named_blocks;
sub get_named_block {
    my $name=shift;
    if(!$named_blocks{$name}){
        $named_blocks{$name}=[];
    }
    return $named_blocks{$name};
}
our $f_init;
our $f_parse;
our $f_modeswitch;
our $f_dumpout;
sub set_interface {
    ($f_init, $f_parse, $f_modeswitch, $f_dumpout)=@_;
}
our $deflist;
our $modelist;
our @block_stack;
our @callback_stack;
my $debug;
our $out;
our @output_list;
sub init_output {
    @output_list=([]);
    $out=$output_list[0];
    return $output_list[0];
}
sub new_output {
    my $flag_nest=shift;
    my $out=[];
    push @output_list, $out;
    if($flag_nest and @callback_stack){
        my $outlist=$callback_stack[-1];
        push @$outlist, $out;
    }
    my $nidx=$#output_list;
    return $nidx;
}
sub fetch_output {
    my $n=shift;
    return $output_list[$n];
}
sub get_def {
    my ($name)=@_;
    for (my $i=$#$deflist; $i>=0; $i--){
        if(defined $deflist->[$i]->{$name}){
            return $deflist->[$i]->{$name};
        }
    }
    return undef;
}
sub get_def_attr {
    my ($name, $attr)=@_;
    for (my $i=$#$deflist; $i>=0; $i--){
        my $t=$deflist->[$i]->{$name};
        if($t and $t->{$attr}){
            return $t->{$attr};
        }
    }
    return undef;
}
sub expand_macro {
    my ($lref, $macros)=@_;
    my $hasmacro=0;
    while ($$lref=~/\$\([^)]+\)/){
        my @segs=split /(\$\([^)]+\))/, $$lref;
        my $j=0;
        my $flag=0;
        foreach my $s (@segs){
            if($s=~/^\$\((\w+)\.(\w+)\)/){
                my $t=$macros->{$1};
                if($t){
                    my $tt=$MyDef::def->{fields}->{$t};
                    if($tt){
                        if($tt->{$2}){
                            $segs[$j]=$tt->{$2};
                            $flag++;
                        }
                        elsif($2 eq "title"){
                            $segs[$j]=$t;
                            $flag++;
                        }
                        else{
                            $segs[$j]="";
                        }
                    }
                    else{
                        if($2 eq "title"){
                            $segs[$j]=$t;
                            $flag++;
                        }
                        else{
                        }
                    }
                }
            }
            elsif($s=~/^\$\((\w+):(\d+)-(\d+)\)/){
                my $t=$macros->{$1};
                if($t){
                    $segs[$j]=substr($t, $2, $3-$2+1);
                    $flag++;
                }
            }
            elsif($s=~/^\$\((.+)\)/){
                if(exists($macros->{$1})){
                    my $t=$macros->{$1};
                    if($t eq $s){
                        die "Looping macro $1 in \"$$lref\"!\n";
                    }
                    $segs[$j]=$t;
                    $flag++;
                }
            }
            $j++;
        }
        if($flag){
            $$lref=join '', @segs;
        }
        else{
            $hasmacro=1;
            last;
        }
    }
    return $hasmacro;
}
sub expand_macro_recurse {
    my $lref=shift;
    my $hasmacro;
    for(my $j=$#$deflist; $j>=0; $j--){
        $hasmacro=expand_macro($lref, $deflist->[$j]);
        if(!$hasmacro){
            last;
        }
    }
    if($hasmacro){
        while($$lref=~/(\$\([^)]+\))/g){
            if(substr($`, -1) ne "\\"){
                warn "Macro $1 not defined in $$lref\n";
            }
        }
    }
}
sub testcondition {
    my ($name)=@_;
    if(!$name){
        return 0;
    }
    elsif($name=~/ or /){
        my @nlist=split / or /, $name;
        foreach my $n(@nlist){
            if(testcondition($n)){
                return 1;
            }
        }
        return 0;
    }
    elsif($name=~/,/){
        my @nlist=split /,/, $name;
        foreach my $n(@nlist){
            if(!testcondition($n)){
                return 0;
            }
        }
        return 1;
    }
    elsif($name=~/(\w+)\.(\w+)/){
        if($1 eq "fields"){
            if ($MyDef::def->{fields}->{$2}){
                return 1;
            }
        }
        else{
            my $t=get_def($1);
            if($t){
                if ($MyDef::def->{fields}->{$t}->{$2}){
                    return 1;
                }
            }
        }
    }
    elsif($name=~/(\w+)(:\d+)?(~|=|!=|<|>)(.*)/){
        my $t=get_def($1);
        my ($tail, $test, $value)=($2, $3, $4);
        if($tail=~/:(\d+)/){
            $t=substr($t, 0, $1);
        }
        if($test eq "="){
            if($t eq $value){ return 1;};
        }
        elsif($test eq "!="){
            if($t ne $value){ return 1;};
        }
        elsif($test eq ">"){
            if($t > $value){ return 1;};
        }
        elsif($test eq "<"){
            if($t < $value){ return 1;};
        }
        elsif($test eq "~"){
            if($t=~/$value/){ return 1;};
        }
    }
    else{
        if(get_def($name)){
            return 1;
        }
    }
    return 0;
}
sub modepush {
    my ($mode)=@_;
    my $pmode=$modelist->[-1];
    push @$modelist, $mode;
    if($pmode ne $mode){
        $f_modeswitch->($pmode, $mode, $out);
    }
}
sub modepop {
    my $pmode=pop @$modelist;
    my $mode=$modelist->[-1];
    if($pmode ne $mode){
        $f_modeswitch->($pmode, $mode, $out);
    }
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
    while($lindex<@$block){
        if($block->[$lindex]=~/SOURCE_DEDENT/){
            $indent-- if $indent>0;
            if($indent==0){
                $lindex++;
                last;
            }
        }
        if($block->[$lindex]=~/SOURCE_INDENT/){
            $indent++;
        }
        push @sub, $block->[$lindex];
        $lindex++;
    }
    $$index_ref=$lindex;
    return \@sub;
}
sub compile {
    my ($pagename)=@_;
    my $page=$MyDef::def->{pages}->{$pagename};
    init_output();
    my ($ext, $mode)=$f_init->($page);
    print STDERR "PAGE: $pagename\n";
    my %varsave;
    while(my ($k, $v)=each %$page){
        $varsave{$k}=$MyDef::var->{$k};
        $MyDef::var->{$k}=$v;
    }
    $deflist=[$MyDef::def, $MyDef::def->{macros}, $page];
    $modelist=[$mode];
    my $codelist=$MyDef::def->{codes};
        if($codename=~/_autoload$/){
            parse_code($codelist->{$codename});
        }
    my $maincode=$page->{codes}->{main};
    if(!$maincode){
        $maincode=$MyDef::def->{codes}->{main};
    }
    parse_code($maincode);
    while(my ($k, $v)=each %varsave){
        $MyDef::var->{$k}=$v;
    }
    if(!$page->{subpage}){
        my @buffer;
        $f_dumpout->(\@buffer, fetch_output(0));
        return (\@buffer, $ext);
    }
}
sub output {
    my ($pagename, $plines, $ext)=@_;
    my $page=$MyDef::def->{pages}->{$pagename};
    my $outdir=".";
    if($MyDef::var->{output_dir}){
        $outdir=$MyDef::var->{output_dir};
    }
    if($page->{output_dir}){
        if($page->{output_dir}=~/^\//){
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
    my $outname=$outdir."/".$pagename;
    if($ext){
        $outname.=".$ext";
    }
    print "  --> [$outname]\n";
    my $subfile=0;
    open Out, ">$outname" or die "Can't write $outname\n";
    foreach my $l (@$plines){
        if(!$subfile and $l!~/^START_/){
            print Out $l;
        }
        else{
            if($subfile){
                if($l=~/^END_SUBFILE/){
                    $subfile=0;
                    close Subfile;
                }
                else{
                    print Subfile $l;
                }
            }
            else{
                if($l=~/^START_Makefile/){
                    if(!-f "$outdir/Makefile"){
                        print "Write $outdir/Makefile\n";
                        open Subfile, ">$outdir/Makefile" or die "Can't write $outdir/Makefile";
                        $subfile=1;
                        print Subfile "$pagename: $pagename.$ext\n";
                    }
                    else{
                        open Subfile, ">/dev/null";
                        $subfile=1;
                    }
                }
                elsif($l=~/^START_h/){
                    open Subfile, ">$outdir/$pagename.h" or die "Can't write $outdir/$pagename.h";
                    $subfile=1;
                }
            }
        }
    }
    close Out;
}
sub parse_code {
    my ($code)=@_;
    my $srclist=$code->{source};
    modepush($code->{type});
    parseblock($srclist);
    modepop();
}
sub parseblock {
    my ($block)=@_;
    my $indent=0;
    my $context;
    my $lindex=0;
    my @indent_stack;
    my @output_stack;
    push @block_stack, {out=>$out};
    while($lindex<@$block){
        my $l=$block->[$lindex];
        if($debug eq "compile"){
            my $yellow="\033[33;1m";
            my $normal="\033[0m";
            print "$yellow compile: [$l]$normal\n";
        }
        $lindex++;
        if($l =~ /^DEBUG (\w+)/){
            $block_stack[-1]->{debug}=1;
            $debug=$1;
            $f_parse->("DEBUG $1");
            next;
        }
        if(@indent_stack and $indent==$indent_stack[-1]){
            if($l eq "SOURCE_INDENT"){
                $out=$output_stack[-1];
                $indent++;
                next;
            }
            else{
                pop @indent_stack;
                pop @output_stack;
            }
        }
        elsif(@indent_stack and $indent-1==$indent_stack[-1]){
            if($l eq "SOURCE_DEDENT"){
                pop @indent_stack;
                pop @output_stack;
                if(@output_stack){
                    $out=$output_stack[-1];
                }
                else{
                    $out=$block_stack[-1]->{out};
                }
                $indent--;
                next;
            }
        }
        if($l eq "SOURCE_INDENT"){
            $indent++;
        }
        elsif($l eq "SOURCE_DEDENT"){
            $indent-- if $indent>0;
        }
        elsif($l eq "BLOCK"){
            my $n=new_output(1);
            $l="BLOCK_$n";
        }
        if($l=~/^\$\((else|\w+:.*)\)/){
            my $preproc=$1;
            if($preproc=~/^for:\s*(\S+)\s+in\s+(.*)/){
                my $vname=$1;
                my $vparam=$2;
                my @tlist=split /,\s*/, $vparam;
                my $subblock=grabblock($block, \$lindex);
                foreach my $t(@tlist){
                    my $macro={$vname=>$t};
                    push @$deflist, $macro;
                    parseblock($subblock);
                    pop @$deflist;
                }
            }
            elsif($preproc=~/^export:\s*([^)]+)=(.*)/){
                $deflist->[-2]->{$1}=$2;
            }
            elsif($preproc=~/^export:\s*([^)]+)/){
                my $t=get_def($1);
                $deflist->[-2]->{$1}=$t;
            }
            elsif($preproc=~/^set:\s*([^)]+)=(.*)/){
                $deflist->[-1]->{$1}=$2;
            }
            elsif($preproc=~/^set:\s*([^)]+)\+=(\d+)/){
                my $i=@$deflist;
                while($i>0 and !defined $deflist->[$i]->{$1}){
                    $i--;
                }
                $deflist->[$i]->{$1}+=$2;
            }
            elsif($preproc=~/^preset:([^:]+):(.*)/){
                my $preset=$1;
                my $t=$2;
                foreach my $tt(split /,/, $t){
                    $deflist->[-1]->{$tt}="$preset$tt";
                }
            }
            elsif($preproc=~/^if:\s*(.*)/){
                my $subblock=grabblock($block, \$lindex);
                if(testcondition($1)){
                    parseblock($subblock);
                    $context="switch_off";
                }
                else{
                    $context="switch_on";
                }
            }
            elsif($preproc=~/^els?e?if:\s*(.*)/){
                my $subblock=grabblock($block, \$lindex);
                if($context eq "switch_on"){
                    if(testcondition($1)){
                        parseblock($subblock);
                        $context="switch_off";
                    }
                    else{
                        $context="switch_on";
                    }
                }
            }
            elsif($preproc=~/^else/){
                my $subblock=grabblock($block, \$lindex);
                if($context eq "switch_on"){
                    parseblock($subblock);
                    undef $context;
                }
            }
            elsif($preproc=~/^block:(\w+)/){
                my $name=$1;
                my $subblock=grabblock($block, \$lindex);
                my $n=new_output();
                if(!$named_blocks{$name}){
                    $named_blocks{$name}=[];
                }
                push @{$named_blocks{$name}}, "BLOCK_$n";
                my $temp=$out;
                $out=$output_list[-1];
                $f_parse->("SCOPE: $name", $modelist->[-1], $out);
                parseblock($subblock);
                $f_parse->("SCOPE: NONE", $modelist->[-1], $out);
                $out=$temp;
            }
        }
        else{
            undef $context;
            expand_macro_recurse(\$l);
            if($l=~/^(&call|\$call|\$map|\$list)\s+(.*)$/){
                my ($func, $param)=($1, $2);
                $param=~s/\s*$//;
                if($func eq "\$map"){
                    call_sub($param, 1);
                }
                elsif($func eq "\$call"){
                    call_sub($param, 0);
                }
                elsif($func eq "\$list"){
                    list_sub($param);
                }
                elsif($func eq "\&call"){
                    my @tlist;
                    push @callback_stack, \@tlist;
                    call_sub($param, 0);
                    pop @callback_stack;
                    while(my $o=shift @tlist){
                        push @indent_stack, $indent;
                        push @output_stack, $o;
                    }
                }
            }
            else{
                my $idx=$#$out+1;
                my $output;
                my $msg=$f_parse->($l, $modelist->[-1], $out);
                if($msg){
                    if(ref($msg) eq "ARRAY"){
                        $output=$msg;
                        $idx=0;
                    }
                    elsif($msg=~/^NEWBLOCK/){
                        $output=$out;
                    }
                    elsif($msg=~/^SET:(\w+)=(.*)/){
                        $deflist->[-1]->{$1}=$2;
                    }
                    if($output){
                        for(my $i=$idx; $i<=$#$output; $i++){
                            if($output->[$i]=~/^BLOCK$/){
                                my $n=new_output();
                                $output->[$i]="BLOCK_$n";
                                push @indent_stack, $indent;
                                push @output_stack, $output_list[-1];
                            }
                            elsif($output->[$i]=~/^CALL\s+(.+)/){
                                my $n=new_output();
                                $output->[$i]="BLOCK_$n";
                                my $temp=$out;
                                $out=$output_list[-1];
                                call_sub($1, 0);
                                $out=$temp;
                            }
                        }
                    }
                }
            }
        }
    }
    my $blk=pop @block_stack;
    if($blk->{debug}){
        $f_parse->("DEBUG OFF");
        $debug=0;
    }
    if(@indent_stack){
        die "Indent_stack mismatch [$block->[0]...$block->[-1]\n";
        while(pop @indent_stack){
            pop @output_stack;
        }
    }
}
sub list_sub {
    my ($param)=@_;
    my @plist=split(/,\s*/, $param);
    foreach my $codename (@plist){
        my $codelib=get_def_attr("codes", $codename);
        my $params=$codelib->{params};
        my $source=$codelib->{source};
        my $line=$codename."-".join(",", @$params);
        push @$modelist, "$codelib->{type}";
        $f_modeswitch->($codelib->{type}, $line, $out);
        parseblock(["SOURCE_INDENT"]);
        parseblock($source);
        parseblock(["SOURCE_DEDENT"]);
        pop @$modelist;
    }
}
sub call_sub {
    my ($param, $domap)=@_;
    my $codename;
    my $attr;
    my (@pre_plist, $pline, @plist);
    if($param=~/^(@)?(\w+)(.*)/){
        $attr=$1;
        $codename=$2;
        my $t=$3;
        if($t=~/\(([^\)]*)\)/){
            my $t1=$1;
            my $t-$';
            @pre_plist=split /,\s*/, $t1;
        }
        $t=~s/^\s*,?\s*//;
        $pline=$t;
        if($codename=~/_f$/){
            $t=~s/^\s*,\s*//;
            push @plist, $t;
        }
        elsif($t=~/\|/){
            @plist=split /\s*\|\s*/, $t;
        }
        else{
            @plist=split /,\s*/, $t;
        }
    }
    else{
        print STDERR "    call_sub [$param] parse failure\n";
        return;
    }
    my $codelib=get_def_attr("codes", $codename);
    if(!$codelib and $attr ne '@'){
        print STDERR "    Code $codename not found!\n";
        return;
    }
    modepush($codelib->{type});
    my $params=$codelib->{params};
    my $source=$codelib->{source};
    my $np=@pre_plist;
    if(1==@$params and $params->[0]=~/^@(\w+)/){
        my $macro={$1=>$pline};
        push @$deflist, $macro;
        parseblock($source);
        pop @deflist;
    }
    elsif($domap){
        if(1+@pre_plist!=@$params){
            warn " Code $codename parameter mismatch.\n";
        }
        foreach my $item (@plist){
            my $macro={$params->[$np]=>$item};
            if($np){
                for(my $i=0; $i<$np; $i++){
                    $macro->{$params->[$i]}=$pre_plist[$i];
                }
            }
            push @$deflist, $macro;
            parseblock($source);
            pop @$deflist;
        }
    }
    else{
        if($np+@plist!=@$params){
            my $n2=@plist;
            my $n3=@$params;
            my $pline=join(', ', @plist);
            warn "    code $codename parameter mismatch ($np + $n2) != $n3. [pline:$pline]\n";
        }
        my $macro={};
        for(my $i=0; $i<$np; $i++){
            $macro->{$params->[$i]}=$pre_plist[$i];
        }
        for(my $j=0; $j<@$params-$np; $j++){
            my $p=$params->[$np+$j];
            $macro->{$p}=$plist[$j];
        }
        push @$deflist, $macro;
        parseblock($source);
        pop @$deflist;
    }
    modepop();
}
1;
