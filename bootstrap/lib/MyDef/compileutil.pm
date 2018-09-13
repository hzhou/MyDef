use strict;
package MyDef::compileutil;
our $deflist;
our %misc_vars;
our $debug=0;
our $f_init;
our $f_parse;
our $f_setout;
our $f_modeswitch;
our $f_dumpout;
our @interface_stack;
our %list_list;
our %list_hash;
our $cur_file;
our $cur_line;
our $out;
our @output_list;
our %named_blocks;
our @mode_stack=("sub");
our $cur_mode;
our $in_autoload;
our $warn_count;
our $main_called;
our @callsub_stack;
our @callback_block_stack;
our %eval_sub_cache;
our %eval_sub_error;
our $cur_ogdl;
our @stub;
our $stub_idx;
our %named_macros=(def=>0,macro=>1,page=>2);
our $parse_capture;
our $block_index=0;
our @block_stack;
our $n_get_macro;
our $STUB_idx=0;

sub output {
    my ($plines) = @_;
    my $page=$MyDef::page;
    my $pagename=$page->{_pagename};
    my $pageext=$page->{_pageext};
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

sub compile {
    my $page=$MyDef::page;
    my $pagename=$page->{_pagename};
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
    $deflist=[$MyDef::def, $MyDef::def->{macros}, $page];
    $deflist->[0]->{_name_}="def_root";
    $deflist->[1]->{_name_}="macros";
    $deflist->[2]->{_name_}="page $page->{_pagename}";
    if($page->{macros}){
        while (my ($k, $v) = each %{$page->{macros}}){
            if(!defined $page->{$k}){
                $page->{$k} = $v;
            }
        }
    }
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
    $in_autoload=1;
    my $codelist=$MyDef::def->{codes};
    foreach my $codename (sort keys %$codelist){
        if($codename=~/_autoload$/){
            call_sub($codename);
        }
    }
    $in_autoload=0;
    $main_called = 0;
    if($page->{_frame}){
        call_sub($page->{_frame});
    }
    if(!$main_called){
        call_sub("main");
    }
    $f_parse->("NOOP POST_MAIN");
    while(my ($k, $v)=each %varsave){
        $MyDef::var->{$k}=$v;
    }
    if(!$page->{subpage}){
        my @buffer;
        $f_dumpout->(\@buffer, fetch_output(0));
        return \@buffer;
    }
    if($warn_count>20){
        print STDERR "[$warn_count] warnings!\n";
    }
}

sub set_output {
    my ($output) = @_;
    my $old=$out;
    $out=$output;
    $f_setout->($out);
    return $old;
}

sub set_interface {
    ($f_init, $f_parse, $f_setout, $f_modeswitch, $f_dumpout)=@_;
}

sub set_interface_partial {
    my $t;
    ($f_init, $f_parse, $f_setout, $t, $f_dumpout)=@_;
}

sub push_interface {
    my ($module) = @_;
    push @interface_stack, [$f_init, $f_parse, $f_setout, $f_modeswitch, $f_dumpout];
    if($module eq "general"){
        require MyDef::output_general;
        set_interface_partial(MyDef::output_general::get_interface());
    }
    elsif($module eq "perl"){
        require MyDef::output_perl;
        set_interface_partial(MyDef::output_perl::get_interface());
    }
    elsif($module eq "c"){
        require MyDef::output_c;
        set_interface_partial(MyDef::output_c::get_interface());
    }
    elsif($module eq "sh"){
        require MyDef::output_sh;
        set_interface_partial(MyDef::output_sh::get_interface());
    }
    elsif($module eq "xs"){
        require MyDef::output_xs;
        set_interface_partial(MyDef::output_xs::get_interface());
    }
    elsif($module eq "php"){
        require MyDef::output_php;
        set_interface_partial(MyDef::output_php::get_interface());
    }
    elsif($module eq "js"){
        require MyDef::output_js;
        set_interface_partial(MyDef::output_js::get_interface());
    }
    elsif($module eq "cpp"){
        require MyDef::output_cpp;
        set_interface_partial(MyDef::output_cpp::get_interface());
    }
    elsif($module eq "java"){
        require MyDef::output_java;
        set_interface_partial(MyDef::output_java::get_interface());
    }
    elsif($module eq "go"){
        require MyDef::output_go;
        set_interface_partial(MyDef::output_go::get_interface());
    }
    elsif($module eq "awk"){
        require MyDef::output_awk;
        set_interface_partial(MyDef::output_awk::get_interface());
    }
    elsif($module eq "ino"){
        require MyDef::output_ino;
        set_interface_partial(MyDef::output_ino::get_interface());
    }
    elsif($module eq "glsl"){
        require MyDef::output_glsl;
        set_interface_partial(MyDef::output_glsl::get_interface());
    }
    elsif($module eq "asm"){
        require MyDef::output_asm;
        set_interface_partial(MyDef::output_asm::get_interface());
    }
    elsif($module eq "tcl"){
        require MyDef::output_tcl;
        set_interface_partial(MyDef::output_tcl::get_interface());
    }
    elsif($module eq "lua"){
        require MyDef::output_lua;
        set_interface_partial(MyDef::output_lua::get_interface());
    }
    elsif($module eq "latex"){
        require MyDef::output_latex;
        set_interface_partial(MyDef::output_latex::get_interface());
    }
    elsif($module eq "tex"){
        require MyDef::output_tex;
        set_interface_partial(MyDef::output_tex::get_interface());
    }
    elsif($module eq "as"){
        require MyDef::output_as;
        set_interface_partial(MyDef::output_as::get_interface());
    }
    elsif($module eq "www"){
        require MyDef::output_www;
        set_interface_partial(MyDef::output_www::get_interface());
    }
    elsif($module eq "win32"){
        require MyDef::output_win32;
        set_interface_partial(MyDef::output_win32::get_interface());
    }
    elsif($module eq "win32rc"){
        require MyDef::output_win32rc;
        set_interface_partial(MyDef::output_win32rc::get_interface());
    }
    elsif($module eq "apple"){
        require MyDef::output_apple;
        set_interface_partial(MyDef::output_apple::get_interface());
    }
    elsif($module eq "matlab"){
        require MyDef::output_matlab;
        set_interface_partial(MyDef::output_matlab::get_interface());
    }
    elsif($module eq "autoit"){
        require MyDef::output_autoit;
        set_interface_partial(MyDef::output_autoit::get_interface());
    }
    elsif($module eq "python"){
        require MyDef::output_python;
        set_interface_partial(MyDef::output_python::get_interface());
    }
    elsif($module eq "fortran"){
        require MyDef::output_fortran;
        set_interface_partial(MyDef::output_fortran::get_interface());
    }
    elsif($module eq "f90"){
        require MyDef::output_f90;
        set_interface_partial(MyDef::output_f90::get_interface());
    }
    elsif($module eq "pascal"){
        require MyDef::output_pascal;
        set_interface_partial(MyDef::output_pascal::get_interface());
    }
    elsif($module eq "plot"){
        require MyDef::output_plot;
        set_interface_partial(MyDef::output_plot::get_interface());
    }
    elsif($module eq "rust"){
        require MyDef::output_rust;
        set_interface_partial(MyDef::output_rust::get_interface());
    }
    else{
        $warn_count++;
        if($warn_count<20){
            print "[$cur_file:$cur_line]\x1b[32m   push_interface: module $module not found\n\x1b[0m";
        }
        else{
        }
        return undef;
    }
    $f_setout->($out);
}

sub pop_interface {
    if(@interface_stack){
        my $interface = pop @interface_stack;
        set_interface_partial(@$interface);
    }
    else{
        $warn_count++;
        if($warn_count<20){
            print "[$cur_file:$cur_line]\x1b[32m    pop_interface: stack empty\n\x1b[0m";
        }
        else{
        }
    }
}

sub test_op {
    my ($a, $test) = @_;
    if($debug eq "preproc"){
        print "preproc test_op: $a: $test\n";
    }
    if($test=~/^:(\d+)/){
        $test=$';
        $a=substr($a, 0, $1);
    }
    if($test=~/^\s*(!?)~(.*)/){
        my ($not, $b) = ($1, $2);
        if($b=~/(.*)\$$/){
            if($a=~/$1$/){ return !$not;};
        }
        else{
            if($a=~/^$b/){ return !$not;};
        }
        return $not;
    }
    elsif($test=~/^\s*in\s+(.*)/){
        return test_in($a, $1);
    }
    elsif($test=~/^\s*([!=<>]+)(.*)/){
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
        else{
            $warn_count++;
            if($warn_count<20){
                print "[$cur_file:$cur_line]\x1b[32m test_op: unsupported op $op\n\x1b[0m";
            }
            else{
            }
            return 0;
        }
    }
    else{
        return defined $a;
    }
}

sub test_in {
    my ($a, $test) = @_;
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
    my ($cond, $has_macro) = @_;
    if($debug eq "preproc"){
        print "preproc testcondition: $cond [$has_macro]\n";
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
            return (defined $t && $t ne '');
        }
        elsif(!defined $t and $has_macro){
            return test_op($1, $2);
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

sub call_sub {
    my ($param) = @_;
    if($param eq "main"){
        $main_called++;
    }
    my ($codename, $attr, $codelib);
    if($param=~/^(@)?(\w+)(.*)/){
        ($codename, $attr, $param)=($2, $1, $3);
        $param=~s/^\s*,\s*//;
        $codelib=get_def_attr("codes", $codename);
        if(!$codelib){
            set_current_macro("notfound", 1);
            if(!$attr or $attr ne '@'){
                print "[$cur_file:$cur_line] Code $codename not found!\n";
                if($debug){
                    debug_def_stack();
                }
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
            if(!$codeparams){
                $codeparams=[];
            }
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
            my $macro={_name_=>"sub $codelib->{name}"};
            if(1==$n_param && $codeparams->[0] eq "\@plist"){
                $macro->{np}=$#plist+1;
                my $i=0;
                foreach my $p (@plist){
                    $i++;
                    $macro->{"p$i"}=$p;
                }
            }
            my $n_p=@plist;
            if($n_pre+$n_p != $n_param){
                my $n0=$n_param-$n_pre-1;
                if($codeparams->[$n_param-1]=~/^\@(\w+)/ and $n_p>=$n0){
                    if($n_p>$n0){
                        for(my $i=0; $i<$n0; $i++){
                            $pline=~s/^[^,]*,//;
                        }
                        $pline=~s/^\s*//;
                        $plist[$n0]=$pline;
                    }
                    else{
                        $plist[$n0]="";
                    }
                }
                else{
                    my $param=join(', ', @$codeparams);
                    $warn_count++;
                    if($warn_count<20){
                        print "[$cur_file:$cur_line]\x1b[32m Code $codename parameter mismatch ($n_pre + $n_p) != $n_param. [pline:$pline]($param)\n\x1b[0m";
                    }
                    else{
                    }
                }
            }
            if($n_pre>0){
                for(my $i=0; $i<$n_pre; $i++){
                    $macro->{$codeparams->[$i]}=$pre_plist[$i];
                }
            }
            for(my $j=0; $j<$n_param-$n_pre; $j++){
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

sub map_sub {
    my ($param, $map_n) = @_;
    if($map_n < 1){
        $map_n = 1;
    }
    my ($codename, $attr, $codelib);
    if($param=~/^(@)?(\w+)(.*)/){
        ($codename, $attr, $param)=($2, $1, $3);
        $param=~s/^\s*,\s*//;
        $codelib=get_def_attr("codes", $codename);
        if(!$codelib){
            set_current_macro("notfound", 1);
            if(!$attr or $attr ne '@'){
                print "[$cur_file:$cur_line] Code $codename not found!\n";
                if($debug){
                    debug_def_stack();
                }
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
            if(!$codeparams){
                $codeparams=[];
            }
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
            if($map_n+@pre_plist!=$n_param){
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
            my $i=0;
            while($i<@plist){
                my $macro={_name_=>"sub $codelib->{name}"};
                for(my $j=0; $j<$n_pre; $j++){
                    $macro->{$codeparams->[$j]}=$pre_plist[$j];
                }
                for(my $j=0; $j<$map_n; $j++){
                    $macro->{$codeparams->[$n_pre+$j]}=$plist[$i];
                    $i++;
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

sub call_back {
    my ($param, $sub_blk) = @_;
    my ($codename, $attr, $codelib);
    if($param=~/^(@)?(\w+)(.*)/){
        ($codename, $attr, $param)=($2, $1, $3);
        $param=~s/^\s*,\s*//;
        $codelib=get_def_attr("codes", $codename);
        if(!$codelib){
            set_current_macro("notfound", 1);
            if(!$attr or $attr ne '@'){
                print "[$cur_file:$cur_line] Code $codename not found!\n";
                if($debug){
                    debug_def_stack();
                }
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
            $named_blocks{last_grab}=$sub_blk->{source};
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
            if(!$codeparams){
                $codeparams=[];
            }
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
            push @callback_block_stack, $sub_blk;
            my $macro={_name_=>"sub $codelib->{name}"};
            if(1==$n_param && $codeparams->[0] eq "\@plist"){
                $macro->{np}=$#plist+1;
                my $i=0;
                foreach my $p (@plist){
                    $i++;
                    $macro->{"p$i"}=$p;
                }
            }
            my $n_p=@plist;
            if($n_pre+$n_p != $n_param){
                my $n0=$n_param-$n_pre-1;
                if($codeparams->[$n_param-1]=~/^\@(\w+)/ and $n_p>=$n0){
                    if($n_p>$n0){
                        for(my $i=0; $i<$n0; $i++){
                            $pline=~s/^[^,]*,//;
                        }
                        $pline=~s/^\s*//;
                        $plist[$n0]=$pline;
                    }
                    else{
                        $plist[$n0]="";
                    }
                }
                else{
                    my $param=join(', ', @$codeparams);
                    $warn_count++;
                    if($warn_count<20){
                        print "[$cur_file:$cur_line]\x1b[32m Code $codename parameter mismatch ($n_pre + $n_p) != $n_param. [pline:$pline]($param)\n\x1b[0m";
                    }
                    else{
                    }
                }
            }
            if($n_pre>0){
                for(my $i=0; $i<$n_pre; $i++){
                    $macro->{$codeparams->[$i]}=$pre_plist[$i];
                }
            }
            for(my $j=0; $j<$n_param-$n_pre; $j++){
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
            if($sub_blk->{parsed_counter}==0){
                $warn_count++;
                if($warn_count<20){
                    print "[$cur_file:$cur_line]\x1b[32m Callback missing BLOCK?\n\x1b[0m";
                }
                else{
                }
            }
            pop @callback_block_stack;
            modepop();
            pop @callsub_stack;
            $codelib->{recurse}--;
        }
    }
}

sub multi_call_back {
    my ($param, $sub_blks) = @_;
    my ($codename, $attr, $codelib);
    if($param=~/^(@)?(\w+)(.*)/){
        ($codename, $attr, $param)=($2, $1, $3);
        $param=~s/^\s*,\s*//;
        $codelib=get_def_attr("codes", $codename);
        if(!$codelib){
            set_current_macro("notfound", 1);
            if(!$attr or $attr ne '@'){
                print "[$cur_file:$cur_line] Code $codename not found!\n";
                if($debug){
                    debug_def_stack();
                }
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
            if(!$codeparams){
                $codeparams=[];
            }
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
            push @callback_block_stack, $sub_blks;
            my $macro={_name_=>"sub $codelib->{name}"};
            if(1==$n_param && $codeparams->[0] eq "\@plist"){
                $macro->{np}=$#plist+1;
                my $i=0;
                foreach my $p (@plist){
                    $i++;
                    $macro->{"p$i"}=$p;
                }
            }
            my $n_p=@plist;
            if($n_pre+$n_p != $n_param){
                my $n0=$n_param-$n_pre-1;
                if($codeparams->[$n_param-1]=~/^\@(\w+)/ and $n_p>=$n0){
                    if($n_p>$n0){
                        for(my $i=0; $i<$n0; $i++){
                            $pline=~s/^[^,]*,//;
                        }
                        $pline=~s/^\s*//;
                        $plist[$n0]=$pline;
                    }
                    else{
                        $plist[$n0]="";
                    }
                }
                else{
                    my $param=join(', ', @$codeparams);
                    $warn_count++;
                    if($warn_count<20){
                        print "[$cur_file:$cur_line]\x1b[32m Code $codename parameter mismatch ($n_pre + $n_p) != $n_param. [pline:$pline]($param)\n\x1b[0m";
                    }
                    else{
                    }
                }
            }
            if($n_pre>0){
                for(my $i=0; $i<$n_pre; $i++){
                    $macro->{$codeparams->[$i]}=$pre_plist[$i];
                }
            }
            for(my $j=0; $j<$n_param-$n_pre; $j++){
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
            if($sub_blks->{parsed_counter}==0){
                $warn_count++;
                if($warn_count<20){
                    print "[$cur_file:$cur_line]\x1b[32m Callback missing BLOCK?\n\x1b[0m";
                }
                else{
                }
            }
            pop @callback_block_stack;
            modepop();
            pop @callsub_stack;
            $codelib->{recurse}--;
        }
    }
}

sub list_sub {
    my ($codelib) = @_;
    my $macro={_name_=>"sub $codelib->{name}"};
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

sub eval_sub {
    my ($codename, $use_module) = @_;
    if($eval_sub_cache{$codename}){
        return $eval_sub_cache{$codename};
    }
    else{
        my $codelib=get_def_attr("codes", $codename);
        if(!$codelib){
            warn "    eval_sub: Code $codename not found\n";
            return undef;
        }
        my @t;
        my $save_out=$out;
        $out=[];
        if(!$use_module){
            $use_module = $codelib->{type};
        }
        push_interface($use_module);
        if($use_module eq "perl"){
            push @$out, "EVAL";
        }
        list_sub($codelib);
        $f_dumpout->(\@t, $out, "eval");
        pop_interface();
        $out=$save_out;
        $f_setout->($out);
        my $t=join("", @t);
        $eval_sub_cache{$codename}=$t;
        return $t;
    }
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
    my $lindex=0;
    while(1){
        my $l;
        if(@stub){
            $l=shift @stub;
        }
        else{
            if($lindex>=@$block){
                last;
            }
            $l=$block->[$lindex];
            $lindex++;
            if($l!~/^SOURCE/){
                $cur_line++;
            }
        }
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
        elsif($l =~/^SOURCE: (.*) - (\d+)$/){
            $cur_file=$1;
            $cur_line=$2;
            next;
        }
        elsif($l=~/^\.\.\.\s*$/){
            $stub_idx++;
            push @$out, "DUMP_STUB stub_$stub_idx";
            $deflist->[-1]->{stub} = "stub_$stub_idx";
            next;
        }
        if($l eq "SOURCE_INDENT"){
            $indent++;
        }
        elsif($l eq "SOURCE_DEDENT"){
            $indent-- if $indent>0;
        }
        if($cur_mode eq "template"){
            if($l=~/^(\s*)(\$call|DUMP_STUB)\s+(.+)/){
                my $len = MyDef::parseutil::get_indent_spaces($1);
                my $n = int($len/4);
                if($len%4){
                    $n++;
                }
                for(my $i=0; $i<$n; $i++){
                    push @$out, "INDENT";
                }
                if($2 eq "DUMP_STUB"){
                    $MyDef::page->{"has_stub_$3"} = 1;
                    push @$out, "DUMP_STUB $3";
                }
                else{
                    my ($func, $param)=("\$call", $3);
                    $param=~s/\s*$//;
                    if($func eq "\$map"){
                        map_sub($param, 1);
                    }
                    elsif($func =~ /^\$call/){
                        call_sub($param);
                    }
                    elsif($func eq "\&call"){
                        my $subblock=grabblock($block, \$lindex);
                        my $blk = {source=>$subblock, name=>"BLOCK", cur_file=>$cur_file, cur_line=>$cur_line, parsed_counter=>0};
                        call_back($param, $blk);
                    }
                    elsif($func =~ /^\$map(\d+)/){
                        map_sub($param, $1);
                    }
                    elsif($func =~ /^\&call(\d+)/){
                        my $n=$1;
                        my @sub_blocks;
                        for(my $i=0; $i<$n; $i++){
                            my $subblock=grabblock($block, \$lindex);
                            my $blk = {source=>$subblock, name=>"BLOCK$i", cur_file=>$cur_file, cur_line=>$cur_line, parsed_counter=>0};
                            push @sub_blocks, $blk;
                            if($i<$n-1){
                                if($block->[$lindex]=~/.*:\s*$/){
                                    $lindex++;
                                }
                                else{
                                    my $blkno = $i+1;
                                    $warn_count++;
                                    if($warn_count<20){
                                        print "[$cur_file:$cur_line]\x1b[32m &call$n missing block $blkno - $block->[$lindex]\n\x1b[0m";
                                    }
                                    else{
                                    }
                                }
                            }
                        }
                        my $multi_blk = {blocks=>\@sub_blocks, name=>"MULTIBLOCK", parsed_counter=>0};
                        multi_call_back($param, $multi_blk);
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
                        for(my $i=0; $i<$n; $i++){
                            push @t_block, "SOURCE_DEDENT";
                        }
                        my $blk = {source=>\@t_block, name=>"BLOCK", cur_file=>$cur_file, cur_line=>$cur_line, parsed_counter=>0};
                        call_back("$codename, $param_0", $blk);
                    }
                }
                for(my $i=0; $i<$n; $i++){
                    push @$out, "DEDENT";
                }
            }
            else{
                push @$out, $l;
            }
        }
        elsif($l){
            if($l=~/^\$\((.*)\)/){
                my $preproc=$1;
                my $tail=$';
                my $has_macro;
                if($preproc =~ /\$\(/ and $preproc !~ /^set:/){
                    $has_macro = expand_macro(\$preproc);
                }
                if($preproc=~/^(if(each)?:|els?e?if:|else\b)\s*(.*)/){
                    my $subblock=grabblock($block, \$lindex);
                    if($preproc=~/^if:\s*(.*)/){
                        if(testcondition($1, $has_macro)){
                            parseblock({source=>$subblock, name=>"\${if:}"});
                            $switch_context="off";
                        }
                        else{
                            $switch_context="on";
                        }
                    }
                    elsif($preproc=~/^els?e?if:\s*(.*)/){
                        if($switch_context eq "on"){
                            if(testcondition($1, $has_macro)){
                                parseblock({source=>$subblock, name=>"\${if:}"});
                                $switch_context="off";
                            }
                            else{
                                $switch_context="on";
                            }
                        }
                    }
                    elsif($preproc=~/^else/){
                        if($switch_context eq "on"){
                            parseblock({source=>$subblock, name=>"\${else}"});
                            undef $switch_context;
                        }
                    }
                    elsif($preproc=~/^ifeach:\s*(.*)/){
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
                        die "Error: parse_preproc_switch\n";
                    }
                    goto Done_Parse;
                }
                else{
                    undef $switch_context;
                }
                my $flag_done = 1;
                if($preproc=~/^for:\s*(.*)/){
                    my ($t) = ($1);
                    my $subblock=grabblock($block, \$lindex);
                    if($t=~/^(\w+)\s+in\s+(.*)/){
                        my ($vname, $vparam)=($1,$2);
                        my @tlist = MyDef::utils::get_tlist($vparam);
                        my $i=0;
                        foreach my $t (@tlist){
                            my $macro={$vname=>$t, _i=>$i};
                            push @$deflist, $macro;
                            parseblock({source=>$subblock, name=>"foreach_p"});
                            pop @$deflist;
                            $i++;
                        }
                    }
                    else{
                        my @plist;
                        if($t=~/(.+?)\s+in\s+(.*)/){
                            $t = $2;
                            @plist = split /,\s*/, $1;
                        }
                        my @vlist=split /\s+and\s+/, $t;
                        my $n;
                        my @tlist;
                        foreach my $v (@vlist){
                            my @t = MyDef::utils::get_tlist($v);
                            if(!$n){
                                $n=@t;
                            }
                            push @tlist, \@t;
                        }
                        my $m = @tlist;
                        if(@plist){
                            for(my $i=0; $i<$n; $i++){
                                my $macro={_i=>$i};
                                for(my $j=0; $j<@plist; $j++){
                                    $macro->{$plist[$j]}=$tlist[$j]->[$i];
                                }
                                push @$deflist, $macro;
                                parseblock({source=>$subblock, name=>"for_list"});
                                pop @$deflist;
                            }
                        }
                        else{
                            my $block_ref = $subblock;
                            for(my $i=0; $i<$n; $i++){
                                push @$deflist, {_i=>$i};
                                my @block = @$block_ref;
                                foreach my $l (@block){
                                    if($l and $l!~/^SOURCE:/){
                                        my $j=1;
                                        foreach my $tlist (@tlist){
                                            $l=~s/\$$j/$tlist->[$i]/g;
                                            $j++;
                                        }
                                    }
                                }
                                my $subblock = \@block;
                                parseblock({source=>$subblock, name=>"for_list"});
                                pop @$deflist;
                            }
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
                elsif($preproc=~/^assert:(.*)/){
                    if(!testcondition($1)){
                        $warn_count++;
                        if($warn_count<20){
                            print "[$cur_file:$cur_line]\x1b[32m Assert Err: [$1]\n\x1b[0m";
                        }
                        else{
                        }
                    }
                }
                elsif($preproc=~/^set:\s*(.*)/){
                    set_macro($deflist->[-1], $1);
                }
                elsif($preproc=~/^set(-?\d+|def|macro|page):\s*(.*)/){
                    my ($i, $t) = ($1, $2);
                    if($debug eq "macro"){
                        print "set[$i]: $t\n";
                    }
                    if($i=~/^-/){
                        $i-=1;
                    }
                    elsif($i!~/^\d/){
                        $i=$named_macros{$i};
                    }
                    set_macro($deflist->[$i], $t);
                }
                elsif($preproc=~/^unset:\s*(.*)/){
                    my @t = split /,\s*/, $1;
                    if($debug eq "macro"){
                        print "unset: $deflist->[-1] @t\n";
                    }
                    foreach my $t (@t){
                        if($t=~/^(\w+)/){
                            $deflist->[-1]->{$t}=undef;
                        }
                        else{
                            $warn_count++;
                            if($warn_count<20){
                                print "[$cur_file:$cur_line]\x1b[32m unset only accepts single word(s)\n\x1b[0m";
                            }
                            else{
                            }
                        }
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
                elsif($preproc=~/^eval:\s*(\S+)=(.*)/){
                    my ($t1,$t2)=($1,$2);
                    expand_eval(\$t2);
                    $t2 = eval($t2);
                    set_macro($deflist->[-1], "$t1=$t2");
                }
                elsif($preproc=~/^split:\s*(\w+)$/){
                    my $p = get_macro_word($1);
                    my @tlist=MyDef::utils::proper_split($p);
                    my $n=@tlist;
                    $deflist->[-1]->{p_n}=$n;
                    for(my $i=1; $i<$n+1; $i++){
                        $deflist->[-1]->{"p_$i"}=$tlist[$i-1];
                    }
                }
                elsif($preproc=~/^split:([^:]+):\s*(\w+)/){
                    my $p = get_macro_word($2);
                    my @tlist=split /$1/, $p;
                    my $n=@tlist;
                    $deflist->[-1]->{p_n}=$n;
                    for(my $i=1; $i<$n+1; $i++){
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
                elsif($preproc=~/^block_release/){
                    $block_stack[-1]->{eindex}=$block_stack[-2]->{eindex};
                }
                elsif($preproc=~/^block:\s*(\w+|\.\.\.)/){
                    my $name=$1;
                    my $subblock=grabblock($block, \$lindex);
                    my $save_mode;
                    if($name eq "..."){
                        $name = get_macro_word("stub");
                    }
                    elsif($name eq "STUB"){
                        $name = get_STUB_name();
                        my $sep=' ';
                        if($preproc=~/^block:\s*STUB:(.*)$/){
                            $sep=$1;
                        }
                        push @$out, "INSERT_STUB[$sep] $name";
                        $save_mode = $cur_mode;
                        $cur_mode = "bypass";
                        unshift @$subblock, "\x24(mode:bypass)";
                    }
                    my $output=get_named_block($name);
                    my $temp=$out;
                    set_output($output);
                    parseblock({source=>$subblock, name=>"block:$name"});
                    set_output($temp);
                    if($save_mode){
                        $cur_mode = $save_mode;
                    }
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
                elsif($preproc=~/^mode:(.*)/){
                    $cur_mode = $1;
                }
                else{
                    $flag_done = undef;
                }
                if($flag_done){
                    goto Done_Parse;
                }
            }
            if($l=~/^BLOCK(\d*)\s*$/){
                my $callback_idx=$1;
                if($#callback_block_stack <0){
                    print "\@block_stack:\n";
                    foreach my $blk (@block_stack){
                        print "    $blk->{code}->{name} $blk->{file}:$blk->{line}\n";
                    }
                    print "[$cur_file:$cur_line] \x1b[33mBLOCK called out of context!\x1b[0m\n";
                }
                else{
                    my $block=pop @callback_block_stack;
                    my $src_block;
                    if($block->{name} eq "MULTIBLOCK"){
                        if(!$callback_idx){
                            $callback_idx=1;
                        }
                        $src_block = $block->{blocks}->[$callback_idx-1];
                    }
                    else{
                        $src_block = $block;
                    }
                    my $depth=$#callback_block_stack+1;
                    if($debug){
                        print "BLOCK [$cur_file:$cur_line] -> [$block->{cur_file}: $block->{cur_line}] depth=$depth: ";
                        foreach my $b (@callback_block_stack){
                            print "$b->{name}, ";
                        }
                        print $block->{name}, "\n";
                    }
                    parseblock($src_block);
                    $block->{parsed_counter}++;
                    push @callback_block_stack, $block;
                }
                goto Done_Parse;
            }
            my $bypass;
            if($cur_mode=~/^(bypass)/){
                $bypass = "::";
            }
            elsif($l=~/^\$([:\.]+) (.*)/){
                $bypass=$1;
                $l=$2;
            }
            if($bypass){
                if($bypass eq "::" or $bypass eq ":."){
                    expand_macro(\$l);
                }
                if($bypass eq ":."){
                    $out->[-1] .= " $l";
                }
                else{
                    push @$out, $l;
                }
                goto Done_Parse;
            }
            expand_macro(\$l);
            while(1){
                if($l=~/^(&call\d?|\$call|\$map\d?|\$nest)\s+(.*)$/i){
                    my ($func, $param)=(lc($1), $2);
                    $param=~s/\s*$//;
                    if($func eq "\$map"){
                        map_sub($param, 1);
                    }
                    elsif($func =~ /^\$call/){
                        call_sub($param);
                    }
                    elsif($func eq "\&call"){
                        my $subblock=grabblock($block, \$lindex);
                        my $blk = {source=>$subblock, name=>"BLOCK", cur_file=>$cur_file, cur_line=>$cur_line, parsed_counter=>0};
                        call_back($param, $blk);
                    }
                    elsif($func =~ /^\$map(\d+)/){
                        map_sub($param, $1);
                    }
                    elsif($func =~ /^\&call(\d+)/){
                        my $n=$1;
                        my @sub_blocks;
                        for(my $i=0; $i<$n; $i++){
                            my $subblock=grabblock($block, \$lindex);
                            my $blk = {source=>$subblock, name=>"BLOCK$i", cur_file=>$cur_file, cur_line=>$cur_line, parsed_counter=>0};
                            push @sub_blocks, $blk;
                            if($i<$n-1){
                                if($block->[$lindex]=~/.*:\s*$/){
                                    $lindex++;
                                }
                                else{
                                    my $blkno = $i+1;
                                    $warn_count++;
                                    if($warn_count<20){
                                        print "[$cur_file:$cur_line]\x1b[32m &call$n missing block $blkno - $block->[$lindex]\n\x1b[0m";
                                    }
                                    else{
                                    }
                                }
                            }
                        }
                        my $multi_blk = {blocks=>\@sub_blocks, name=>"MULTIBLOCK", parsed_counter=>0};
                        multi_call_back($param, $multi_blk);
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
                        for(my $i=0; $i<$n; $i++){
                            push @t_block, "SOURCE_DEDENT";
                        }
                        my $blk = {source=>\@t_block, name=>"BLOCK", cur_file=>$cur_file, cur_line=>$cur_line, parsed_counter=>0};
                        call_back("$codename, $param_0", $blk);
                    }
                }
                elsif($l=~/^(\S+)\s*=\s*\$call\s+(.*)/){
                    my ($var, $param)=($1, $2);
                    call_sub($param);
                    if($out->[-1]=~/^YIELD\s+(.+)/){
                        $out->[-1]="$var = $1";
                    }
                    else{
                        $warn_count++;
                        if($warn_count<20){
                            print "[$cur_file:$cur_line]\x1b[32m \x1b[33mMISSING YIELD!\x1b[0m\n";
                        }
                        else{
                        }
                    }
                }
                elsif(defined $parse_capture){
                    push @$parse_capture, $l;
                }
                else{
                    my $callback_output;
                    my $callback_scope;
                    my $msg=$f_parse->($l);
                    if($msg){
                        if(ref($msg) eq "ARRAY"){
                            $warn_count++;
                            if($warn_count<20){
                                print "[$cur_file:$cur_line]\x1b[32m return [ARRAY] deprecated. Use NEWBLOCK and &replace_output instead.\n\x1b[0m";
                            }
                            else{
                            }
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
                            my $old_out;
                            if($callback_output->[0]=~/^OUTPUT:\s*(\S+)/){
                                my $output = get_named_block($1);
                                $old_out = set_output($output);
                                shift @$callback_output;
                            }
                            foreach my $l (@$callback_output){
                                if($l=~/^BLOCK$/){
                                    push @$deflist, {};
                                    parseblock({source=>$subblock, name=>"BLOCK", scope=>$callback_scope});
                                    pop @$deflist;
                                }
                                elsif($l=~/^PARSE:(.*)/){
                                    if($1=~/\s*\MODEPOP/){
                                        modepop();
                                    }
                                    else{
                                        $f_parse->($1);
                                    }
                                }
                                else{
                                    $f_parse->($l);
                                }
                            }
                            if($old_out){
                                set_output($old_out);
                            }
                        }
                    }
                }
                last;
            }
            Done_Parse: 1;
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

sub set_macro {
    my ($m, $p) = @_;
    if($debug eq "macro"){
        print "set_macro $m: [$p]\n";
    }
    if($p=~/(\w+)([\+\-\*\/\.]?)=(.+)/){
        my ($t1, $op, $t2)=($1, $2, $3);
        my $t = get_macro_word($t1, 1);
        if($op){
            $m->{$t1} = calc_op($t, $op, $t2);
        }
        else{
            if($t2=~/\$\(.*\)/){
                expand_macro(\$t2);
            }
            $m->{$t1} = $t2;
        }
    }
    elsif($p=~/(\w+)\[(.*?)\]=(.+)/){
        my ($t1, $sep, $item)=($1, $2, $3);
        if($m->{$t1}){
            $m->{$t1}.="$sep$item";
        }
        else{
            $m->{$t1}=$item;
        }
    }
    elsif($p=~/(\S+?):=(.*)/){
        $m->{$1}=$2;
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
            $m->{$p}=1;
        }
    }
}

sub calc_op {
    my ($v, $op, $t) = @_;
    if($op eq "."){
        return $v . $t;
    }
    my $ret=get_numeric($v);
    if($op eq "+"){
        $ret+=get_numeric($t);
    }
    elsif($op eq "-"){
        $ret-=get_numeric($t);
    }
    elsif($op eq "*"){
        $ret*=get_numeric($t);
    }
    elsif($op eq "/"){
        $ret/=get_numeric($t);
    }
    if($v=~/^0x/){
        return sprintf("0x%x", $ret);
    }
    else{
        return $ret;
    }
}

sub get_numeric {
    my ($v) = @_;
    if($v=~/^0x(.*)/){
        return hex($v);
    }
    else{
        return $v;
    }
}

sub set_current_macro {
    my ($name, $val) = @_;
    $deflist->[-1]->{$name}=$val;
}

sub export_macro {
    my ($i, $name, $val) = @_;
    $deflist->[$i]->{$name}=$val;
}

sub get_current_macro {
    my ($name) = @_;
    return $deflist->[-1]->{$name};
}

sub expand_eval {
    my ($lref) = @_;
    if($$lref=~/\$(\(\w|\.)|[\x80-\xff]/){
        $$lref = MyDef::utils::expand_macro($$lref, \&get_macro);
        return 1;
    }
    my @t=split /(\w+)/, $$lref;
    my $flag;
    foreach my $t (@t){
        if($t=~/^[_a-zA-Z]\w*$/){
            if($t!~/abs|atan2|cos|exp|hex|int|log|oct|rand|sin|sqrt|srand|chr|ord|lc|lcfirst|uc|uc_first|substr|sprintf/){
                my $s = get_macro_word($t, 1);
                if(defined $s){
                    $t=$s;
                    $flag=1;
                }
            }
        }
    }
    if($flag){
        $$lref = join('', @t);
    }
}

sub expand_macro {
    my ($lref) = @_;
    if($$lref=~/\$(\(\w|\.)|[\x80-\xff]/){
        $$lref = MyDef::utils::expand_macro($$lref, \&get_macro);
        return 1;
    }
    else{
        return 0;
    }
}

sub get_macro {
    my ($s, $nowarn) = @_;
    $n_get_macro++;
    if($debug eq "macro"){
        print "get_macro: [$s], nowarn: [$nowarn]\n";
    }
    if($s=~/^x(\d+)([^:]*):(.*)/){
        if($1>1){
            return "$3$2" x ($1-1) . $3;
        }
        elsif($1==1){
            return $3;
        }
        else{
            return "";
        }
    }
    elsif($s=~/^((nest|join|subst|eval|sym):.+)/){
        my $t=$1;
        if($t=~/^eval:\s*(.*)/){
            return eval($1);
        }
        elsif($t=~/^nest:(\d+):(.+):(.*)/){
            my ($n, $pat, $x)=($1, $2, $3);
            if($pat=~/^(.*)\*(.*)$/){
                return ($1 x $n).$x.($2 x $n);
            }
            else{
                $warn_count++;
                if($warn_count<20){
                    print "[$cur_file:$cur_line]\x1b[32m nest macro not supported\n\x1b[0m";
                }
                else{
                }
                return;
            }
        }
        elsif($t=~/^join:(.*):(.*):(.*)/){
            my ($pat, $sep, $t) = ($1, $2, $3);
            if(!$pat){
                my @tlist = MyDef::utils::get_tlist($t);
                return join($sep, @tlist);
            }
            elsif($pat=~/^rot(-?\d+)/){
                my @tlist = MyDef::utils::get_tlist($t);
                if($1==0){
                    return join($sep, @tlist);
                }
                elsif($1>0){
                    return join($sep, @tlist[$1..$#tlist, 0..($1-1)]);
                }
                else{
                    return join($sep, @tlist[$1..-1, 0..($#tlist+$1)]);
                }
            }
            else{
                my $plist = MyDef::utils::for_list_expand($pat, $t);
                return join($sep, @$plist);
            }
        }
        elsif($t =~ /^subst:(.+):(.+):(.*)/){
            my ($w, $pat, $rpl)=($1,$2,$3);
            if($w=~/^\w+$/){
                my $t = get_macro_word($w,1);
                if($t){
                    $w = $t;
                }
            }
            $w =~s/$pat/$rpl/g;
            return $w;
        }
        elsif($t =~ /^sym:(.+)/){
            return MyDef::utils::string_symbol_name($1);
        }
        else{
            $warn_count++;
            if($warn_count<20){
                print "[$cur_file:$cur_line]\x1b[32m syntax error: [$s]\n\x1b[0m";
            }
            else{
            }
            return undef;
        }
    }
    elsif($s=~/^def:(.*)/){
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
    elsif($s=~/^stub:(.*)/){
        my ($t) = ($1);
        my $sep=' ';
        if($t=~/^(.*):(.*)/){
            ($sep, $t) = ($1, $2);
        }
        my $name = get_STUB_name();
        my $output=get_named_block($name);
        my $temp=$out;
        set_output($output);
        call_sub($t);
        set_output($temp);
        push @stub, "INSERT_STUB[$sep] $name";
        return "{STUB}";
    }
    elsif($s=~/^(\w+):(.*)/){
        my $p=$2;
        my $t=get_macro_word($1, $nowarn);
        if($t){
            if($p=~/(\d+):(\d+|word|number)?/){
                if($2>0){
                    $s=substr($t, $1, $2);
                }
                else{
                    $s=substr($t, $1);
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
                }
                return $s;
            }
            elsif($p eq "strlen"){
                if($t=~/^['"].*['"]$/){
                    return eval "length($t)";
                }
                else{
                    return length($t);
                }
            }
            elsif($p eq "strip"){
                return substr($t, 1, -1);
            }
            elsif($p eq "lc"){
                return lc($t);
            }
            elsif($p eq "uc"){
                return uc($t);
            }
            elsif($p eq "uc_first"){
                return uc_first($t);
            }
            elsif($p eq "length"){
                return length($t);
            }
            elsif($p =~ /regex:(.*)/){
                my $re = qr/$1/;
                if($t=~ /$re/){
                    return $1;
                }
                else{
                    return '';
                }
            }
            elsif($p=~/list:(.*)/){
                my $idx=$1;
                my @tlist=MyDef::utils::proper_split($t);
                if($idx eq "n"){
                    return scalar(@tlist);
                }
                elsif($idx=~/^(-?\d+)$/){
                    return $tlist[$1];
                }
                elsif($idx=~/^shift\s+(\d+)$/){
                    splice(@tlist, 0, $1);
                    return join(", ", @tlist);
                }
                elsif($idx=~/^pop\s+(\d+)$/){
                    splice(@tlist, -$1);
                    return join(", ", @tlist);
                }
                elsif($idx=~/^(.*)\*(.*)$/){
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
    for(my $j=$#$deflist; $j>=-1; $j--){
        my $macros=$deflist->[$j];
        if(exists($macros->{$name})){
            return $macros->{$name};
        }
    }
    if(!$nowarn){
        $warn_count++;
        if($warn_count<20){
            print "[$cur_file:$cur_line]\x1b[32m Macro $name not defined\n\x1b[0m";
        }
        else{
        }
    }
    return undef;
}

sub get_ogdl {
    my ($name) = @_;
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
    my ($name) = @_;
    return get_macro_word($name, 1);
}

sub get_def_attr {
    my ($name, $attr) = @_;
    for(my $i=$#$deflist; $i>=0; $i--){
        my $t=$deflist->[$i]->{$name};
        if($t and $t->{$attr}){
            return $t->{$attr};
        }
    }
    return undef;
}

sub debug_def_stack {
    for(my $i=$#$deflist; $i>=0; $i--){
        my $name = $deflist->[$i]->{_name_};
        if(!$name){
            $name="Unknown";
        }
        print "    [$i] $name\n";
    }
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

sub set_named_block {
    my ($name, $block) = @_;
    $named_blocks{$name}=$block;
}

sub get_named_block {
    my ($name) = @_;
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
    my ($mode) = @_;
    $cur_mode=$mode;
    push @mode_stack, $mode;
    $f_modeswitch->($mode, 1);
}

sub modepop {
    pop @mode_stack;
    $cur_mode=$mode_stack[-1];
    $f_modeswitch->($cur_mode, 0);
}

sub get_STUB_name {
    $STUB_idx++;
    return "_stub_$STUB_idx";
}

sub grabblock {
    my ($block, $index_ref) = @_;
    my $lindex=$$index_ref;
    if($block->[$lindex] ne "SOURCE_INDENT"){
        return [];
    }
    $lindex++;
    my $indent=1;
    my @sub;
    push @sub, "SOURCE: $cur_file - $cur_line";
    while(1){
        my $l;
        if(@stub){
            $l=shift @stub;
        }
        else{
            if($lindex>=@$block){
                last;
            }
            $l=$block->[$lindex];
            $lindex++;
            if($l!~/^SOURCE/){
                $cur_line++;
            }
        }
        if($l eq "SOURCE_DEDENT"){
            $indent--;
            if($indent==0){
                last;
            }
        }
        if($l eq "SOURCE_INDENT"){
            $indent++;
        }
        push @sub, $l;
    }
    $$index_ref=$lindex;
    return \@sub;
}

1;
