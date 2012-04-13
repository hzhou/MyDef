package MyDef::parseutil;
sub import_data {
    my ($plines, $var)=@_;
    my $def={"resource"=>{},
        "pages"=>{},
        "codes"=>{},
        "macros"=>{},
        };
    while(my ($k, $v)=each %$var){
        if($k=~/macro_(\w+)/){
            $def->{macros}->{$1}=$v;
        }
    }
    my @includes;
    my %includes;
    my @standard_includes;
    if($var->{module} eq "php"){
        push @standard_includes, "std_php.def";
    }
    elsif($var->{module} eq "c"){
        push @standard_includes, "std_c.def";
    }
    elsif($var->{module} eq "xs"){
        push @standard_includes, "std_c.def";
    }
    elsif($var->{module} eq "apple"){
        push @standard_includes, "std_c.def";
    }
    elsif($var->{module} eq "win32"){
        push @standard_includes, "std_c.def";
        push @standard_includes, "std_win32.def";
    }
    import_file($plines, $var, $def, \@includes,\%includes);
    while(1){
        if(my $file=shift(@includes)){
            $plines=get_lines($file, $var);
            import_file($plines, $var, $def, \@includes,\%includes);
        }
        elsif(my $file=shift(@standard_includes)){
            $plines=get_lines($file, $var);
            import_file($plines, $var, $def, \@includes,\%includes);
        }
        else{
            last;
        }
    }
    post_foreachfile($def);
    post_matchblock($def);
    return $def;
}
sub import_file {
    my ($plines, $var, $def, $include_list, $include_hash)=@_;
    my $pages=$def->{pages};
    my $codes=$def->{codes};
    my $macros=$def->{macros};
    my $stage="";
    my $item;
    my $page;
    my $source;
    my $curindent;
    my $codeindent = 0;
    my $lastindent;
    my $grab=undef;
    my $grab_hash;
    my $grab_key;
    my $grab_indent;
    my @grab;
    push @$plines, "END";
    foreach my $line (@$plines){
        if($line=~/^\s*$/){
            next;
        }
        elsif($line=~/^(\s*)(.*)/){
            my $indent=getindent($1);
            $line=$2;
            if($line=~/^#/){
                if($codeindent>0 and $indent>$lastindent){
                    $line="NOOP";
                }
                else{
                    next;
                }
            }
            else{
                $line=~s/\s+$//;
                $line=~s/\s+#\s.*$//;
            }
            $curindent=$indent;
        }
        if($grab){
            if($curindent>$grab_indent){
                my $i=$curindent-$grab_indent-1;
                push @grab, "$i:$line";
                next;
            }
            else{
                if($grab eq "ogdl"){
                    my $ogdl=grab_ogdl($grab_key, \@grab);
                    if(!$grab_hash->{$grab_key}){
                        $grab_hash->{$grab_key}=$ogdl;
                    }
                    else{
                        my $t=$grab_hash->{$grab_key};
                        while(my ($k, $v)=each %$ogdl){
                            if(!defined $t->{$k}){
                                $t->{$k}=$v;
                            }
                        }
                    }
                }
                undef $grab;
                @grab=();
            }
        }
        if($curindent < $codeindent){
            while($codeindent<$lastindent){
                $lastindent--;
                push @$source, "SOURCE_DEDENT";
            }
            $codeindent=0;
        }
        if($codeindent>0){
            while($curindent>$lastindent){
                $lastindent++;
                push @$source, "SOURCE_INDENT";
            }
            while($curindent<$lastindent){
                $lastindent--;
                push @$source, "SOURCE_DEDENT";
            }
            push @$source, $line;
        }
        elsif($line=~/^(\w+)code:(:?)\s+(\w+)(.*)/){
            my ($type, $dblcolon, $name, $t)=($1, $2, $3, $4);
            $source=[];
            $codeindent=$curindent+1;
            $lastindent=$codeindent;
            if($curindent==0 and $codes->{$name}){
                if($dblcolon){
                    $source=$codes->{$name}->{source};
                }
                elsif($debug>1){
                    print STDERR "overwiritten $type code: $name\n";
                }
            }
            else{
                my @params;
                if($t=~/\((.*)\)/){
                    $t=$1;
                    @params=split /,\s*/, $t;
                }
                my $t_code={'type'=>$type, 'source'=>$source, 'params'=>\@params};
                if($curindent == 0){
                    $codes->{$name}=$t_code;
                    $stage='code';
                }
                elsif($stage eq 'page'){
                    $page->{codes}->{$name}=$t_code;
                }
            }
        }
        elsif($curindent==0){
            if($line=~/^include:? (.*)/){
                if(!$include_hash->{$1}){
                    push @$include_list, $1;
                    $include_hash->{$1}=1;
                }
            }
            elsif($line=~/^(sub)?page: (.*)/){
                my ($subpage, $t)=($1, $2);
                my ($pagename, $maincode);
                if($t=~/([a-zA-Z0-9_\-\$]+),\s*(\w.*)/){
                    $pagename=$1;
                    $maincode=$2;
                }
                elsif($t=~/([a-zA-Z0-9_\-\$]+)/){
                    $pagename=$1;
                }
                my $code={};
                if($maincode){
                    $code->{main}={'type'=>'sub', 'source'=>["\$call $maincode"], 'params'=>[]};
                }
                $page={pagename=>$pagename, codes=>$code};
                if($subpage){
                    $page->{subpage}=1;
                }
                if($pages->{$pagename}){
                    my $t=$pagename;
                    my $j=0;
                    while($pages->{$pagename}){
                        $j++;
                        $pagename=$t.$j;
                    }
                }
                $pages->{$pagename}=$page;
                $stage='page';
            }
            elsif($line=~/^resource:\s+(\w+)/){
                $grab="ogdl";
                $grab_indent=$curindent;
                $grab_key=$1;
                $grab_hash=$def->{resource};
            }
            elsif($line=~/^(\w+)/){
                $stage=$1;
                if(!$def->{$stage}){
                    $def->{$stage}={};
                }
            }
        }
        else{
            if($stage =~ /^(fields)$/){
                if($line=~/^optional:(.*)/){
                    my @tlist=split(/,/, $1);
                    foreach my $t (@tlist){
                        if($t=~/(\w+)/){
                            if($def->{$stage}->{$1}){
                                $def->{$stage}->{$1}->{optional}=1;
                            }
                            else{
                                $def->{$stage}->{$1}={optional=>1};
                            }
                        }
                    }
                }
                elsif($curindent==1){
                    if($line=~/^([a-zA-Z0-9-_]+):\s*(.*)$/){
                        if($def->{$stage}->{$1}){
                            $item=$def->{$stage}->{$1};
                        }
                        else{
                            $item={};
                            $def->{$stage}->{$1}=$item;
                        }
                        if($2){
                            $item->{type}=$2;
                            $item->{value}=$2;
                            $item->{title}=$2;
                        }
                    }
                }
                elsif($line=~/^(\w+): (.*)/){
                    my $k=$1;
                    my $v=$2;
                    expand_macro(\$v, $macros);
                    if($item->{$k}){
                        print STDERR " Denied overwriting $k with $v\n" if $debug>1;
                    }
                    else{
                        $item->{$k}=$v;
                    }
                }
            }
            elsif($stage =~/^macros$/){
                if($line=~/^(\w+): (.*\S)/){
                    my $k=$1;
                    my $v=$2;
                    if($macros->{$k}){
                        print STDERR " Overriden macro $k\n" if $debug>1;
                    }
                    else{
                        my $t=$v;
                        expand_macro(\$t, $macros);
                        $macros->{$k}=$t;
                    }
                }
            }
            elsif($stage =~/^(page)$/){
                if($line=~/^source: (.*)/){
                    $page->{codes}->{main}={'type'=>"sub", 'source'=>["\$call $1"], 'params'=>[]};
                }
                elsif($line=~/^(\w+): (.*)/){
                    my $k=$1;
                    my $v=$2;
                    expand_macro(\$v, $macros);
                    $page->{$k}=$v;
                }
            }
        }
    }
}
our @indent_stack=(0);
sub getindent {
    use integer;
    my $s=shift;
    1 while $s=~s/\t+/' ' x (length($&) * 8 - length($`) % 8)/e;
    my $i=length($s);
    if($i==$indent_stack[-1]){
    }
    elsif($i>$indent_stack[-1]){
        push @indent_stack, $i;
    }
    else{
        while($i<$indent_stack[-1]){
            pop @indent_stack;
        }
    }
    return $#indent_stack;
}
sub expand_macro {
    my ($lref, $macros)=@_;
    while($$lref=~/\$\(\w+\)/){
        my @segs=split /(\$\(\w+\))/, $$lref;
        my $j=0;
        my $flag=0;
        foreach my $s (@segs){
            if($s=~/\$\((\w+)\)/){
                my $t=$macros->{$1};
                if($t eq $s){
                    die "Looping macro $1 in \"$$lref\"!\n";
                }
                if($t){
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
            last;
        }
    }
}
sub get_lines {
    my ($file, $var)=@_;
    my $filename="";
    if(-f $file){
        $filename=$file;
    }
    if(!$filename and $var->{'include_path'}){
        my @dirs=split /:/, $var->{'include_path'};
        foreach my $dir (@dirs){
            if(-f "$dir/$file"){
                $filename="$dir/$file";
                last;
            }
        }
    }
    if(!-f $filename){
        print "include_path: $var->{include_path}\n";
        die "$file not found\n";
    }
    open In, $filename or die "Can't open $file.\n";
    my @lines=<In>;
    close In;
    return \@lines;
}
sub post_foreachfile {
    my $def=shift;
    my $pages=$def->{pages};
    while(my ($name, $p)=each(%$pages)){
        if ($p->{foreachfile}){
            my $pat_glob=$p->{foreachfile};
            my $pat_regex=$p->{foreachfile};
            my $n;
            $n=$pat_glob=~s/\(\*\)/\*/g;
            $pat_regex=~s/\(\*\)/\(\.\*\)/g;
            my @files=glob($pat_glob);
            foreach my $f(@files){
                my @pat_list=($f=~/$pat_regex/);
                dupe_page($def, $p, $n, @pat_list);
            }
            delete $pages->{$name};
        }
    }
}
sub post_matchblock {
    my $def=shift;
    my $codes=$def->{codes};
    my @codelist=keys(%$codes);
    foreach $name (@codelist){
        if($name=~/^pre_(\w+)/ and !$codes->{"post_$1"}){
            my $loopname=$1;
            my $params=$codes->{$name}->{params};
            my $type=$codes->{$name}->{type};
            my $presource=$codes->{$name}->{source};
            my $source=[];
            my $t_code={'type'=>$type, 'source'=>$source, 'params'=>$params};
            foreach my $l(@$presource){
                if($l=~/\$openfor/){
                    push @$source, "DEDENT }";
                }
            }
            $codes->{"post_$loopname"}=$t_code;
        }
    }
}
sub dupe_page {
    my ($def, $page, $n, @pat_list)=@_;
    my $pagename=dupe_line($page->{pagename}, $n, @pat_list);
    print "    foreach file $pagename $n: ", join(",", @pat_list), "\n";
    my $p={};
    while(my ($k, $v)=each(%$page)){
        if($k eq "pagename"){
            $p->{pagename}=$pagename;
        }
        elsif($k eq "codes"){
            my $codes={};
            while(my ($tk, $tv)=each(%$v)){
                my $tcode={};
                $tcode->{type}=$tv->{type};
                $tcode->{params}=$tv->{params};
                my @source;
                my $tsource=$tv->{source};
                foreach my $l (@$tsource){
                    push @source, dupe_line($l, $n, @pat_list);
                }
                $tcode->{source}=\@source;
                $codes->{$tk}=$tcode;
            }
            $p->{codes}=$codes;
        }
        elsif($k eq "foreachfile"){
        }
        else{
            $p->{$k}=dupe_line($v);
        }
    }
    my $pages=$def->{pages};
    if($pages->{$pagename}){
        my $t=$pagename;
        my $j=0;
        while($pages->{$pagename}){
            $j++;
            $pagename=$t."_$j";
        }
    }
    $pages->{$pagename}=$p;
}
sub dupe_line {
    my ($l, $n, @pat_list)=@_;
    for (my $i=1; $i<=$n; $i++){
        $rep=$pat_list[$i-1];
        $l=~s/\$$i/$rep/g;
    }
    return $l;
}
sub grab_ogdl {
    my ($name, $llist)=@_;
    my @ogdl_stack;
    my $cur_i=0;
    my $cur_item={"_list"=>[], "_name"=>$name};
    my $last_item;
    my $last_item_type;
    my $last_item_key;
    my $ogdl=$cur_item;
    foreach my $l (@$llist){
        if($l=~/^(\d)+:(.*)/){
            my ($i, $l)=($1, $2);
            if($i>$cur_i){
                push @ogdl_stack, $cur_item;
                $cur_item={"_list"=>[]};
                if($last_item_type eq "array"){
                    $cur_item->{_name}=$last_item->[-1];
                    $last_item->[-1]=$cur_item;
                }
                elsif($last_item_type eq "hash"){
                    $cur_item->{_name}=$last_item->{$last_item_key};
                    $last_item->{$last_item_key}=$cur_item;
                }
                $cur_i=$i;
            }
            elsif($i<$cur_i){
                while($i<$cur_i){
                    $cur_item=pop @ogdl_stack;
                    $cur_i--;
                }
            }
            if($cur_item){
                if($l=~/(^\S+?):\s*(.+)/){
                    my ($k, $v)=($1, $2);
                        $cur_item->{$k}=$v;
                        $last_item=$cur_item;
                        $last_item_type="hash";
                        $last_item_key=$k;
                }
                elsif($l=~/(^\S+):\s*$/){
                    my $k=$1;
                    $cur_item->{$k}="";
                    $last_item=$cur_item;
                    $last_item_type="hash";
                    $last_item_key=$k;
                }
                else{
                    my @t;
                    if($l !~/\(/){
                        @t=split /,\s*/, $l;
                    }
                    else{
                        push @t, $l;
                    }
                    foreach my $t (@t){
                        push @{$cur_item->{_list}}, $t;
                        $last_item=$cur_item->{_list};
                        $last_item_type="array";
                    }
                }
            }
        }
    }
    return $ogdl;
}
sub print_ogdl {
    my $ogdl=shift;
    my $indent=shift;
    if(ref($ogdl) eq "HASH"){
        if($ogdl->{_name} ne "_"){
            print "    "x$indent, $ogdl->{_name}, "\n";
            $indent++;
        }
        while(my ($k, $v) = each %$ogdl){
            if($k!~/^_(list|name)/){
                print "    "x$indent, $k, ":\n";
                print_ogdl($v, $indent+1);
            }
        }
        foreach my $v (@{$ogdl->{_list}}){
            print_ogdl($v, $indent);
        }
    }
    else{
        print "    "x$indent, $ogdl, "\n";
    }
}
1;
