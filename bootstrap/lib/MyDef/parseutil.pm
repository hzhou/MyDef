use strict;
package MyDef::parseutil;
my $debug=0;
my $defname="default";
sub import_data {
    my ($file)=@_;
    if($file=~/([^\/]+)\.def/){
        $defname=$1;
    }
    import_data_lines($file, undef);
}
sub import_data_lines {
    my ($file, $plines)=@_;
    my $def={"resource"=>{},
        "pages"=>{},
        "pagelist"=>[],
        "codes"=>{},
        "macros"=>{},
        "defname"=>$defname,
        };
    while(my ($k, $v)=each %$MyDef::var){
        if($k=~/macro_(\w+)/){
            $def->{macros}->{$1}=$v;
        }
    }
    my @includes;
    my %includes;
    my @standard_includes;
    my $stdinc="std_".$MyDef::var->{module}.".def";
    push @standard_includes, $stdinc;
    import_file($file, $plines, $def, \@includes,\%includes);
    while(1){
        if(my $file=shift(@includes)){
            import_file($file, undef, $def, \@includes,\%includes);
        }
        elsif(my $file=shift(@standard_includes)){
            import_file($file, undef, $def, \@includes,\%includes);
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
    my ($f, $plines, $def, $include_list, $include_hash)=@_;
    my $pages=$def->{pages};
    my $pagelist=$def->{pagelist};
    my $codes=$def->{codes};
    my $macros=$def->{macros};
    my $stage="";
    my $item;
    my $page;
    my $curindent;
    my $codeindent = 0;
    my $lastindent;
    my $grab=undef;
    my $grab_indent;
    my @grab;
    my $multi_line_comment_on;
    my $source;
    my $cur_codename;
    my $code_prepend;
    if(!$plines){
        $plines=get_lines($f);
    }
    push @$plines, "END";
    my $cur_file=$f;
    my $cur_line=0;
    foreach my $line (@$plines){
        $cur_line++;
        if($multi_line_comment_on){
            if($line=~/\*\/\s*$/){
                $multi_line_comment_on=0;
            }
            next;
        }
        elsif($line=~/^\s*\/\*/){
            $multi_line_comment_on=1;
            if($line=~/\*\/\s*$/){
                $multi_line_comment_on=0;
            }
            next;
        }
        if($line=~/^\s*$/){
            $line="NOOP";
        }
        elsif($line=~/^(\s*)(.*)/){
            my $indent=getindent($1);
            $line=$2;
            if($line=~/^#/){
                $line="NOOP";
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
                grab_ogdl($grab, \@grab);
                $grab=undef;
                @grab=();
            }
        }
        if($curindent==0){
            if($stage eq "code"){
                if($code_prepend){
                    my $orig_source=$codes->{$cur_codename}->{source};
                    push @$source, @$orig_source;
                    $codes->{$cur_codename}->{source}=$source;
                }
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
        elsif($line=~/^(\w+)code:([:-@]?)\s*(\w+)(.*)/){
            my ($type, $dblcolon, $name, $t)=($1, $2, $3, $4);
            if($name eq "_autoload"){
                $dblcolon=":";
            }
            my $src_location="SOURCE: $cur_file - $cur_line";
            $source=[$src_location];
            $codeindent=$curindent+1;
            $lastindent=$codeindent;
            if($curindent == 0){
                $stage='code';
                $cur_codename=$name;
                undef $code_prepend;
            }
            if($curindent==0 and $codes->{$name} and $codes->{$name}->{attr} ne "default"){
                if($dblcolon eq "@"){
                }
                elsif($dblcolon eq ":"){
                    $source=$codes->{$name}->{source};
                    push @$source, $src_location;
                }
                elsif($dblcolon eq "-"){
                    $code_prepend=1;
                }
                elsif($codes->{$name}->{attr} eq "optional"){
                    $codes->{$name}->{attr}=undef;
                    $source=$codes->{$name}->{source};
                    push @$source, $src_location;
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
                my $t_code={'type'=>$type, 'source'=>$source, 'params'=>\@params, 'name'=>$name};
                if($dblcolon eq "@"){
                    $t_code->{attr}="default";
                }
                elsif($dblcolon eq ":" or $dblcolon eq "-"){
                    $t_code->{attr}="optional";
                }
                if($curindent == 0){
                    $codes->{$name}=$t_code;
                }
                elsif($stage eq 'page'){
                    if($page->{codes}->{$name} and ($name eq "main")){
                        $page->{codes}->{'main2'}=$t_code;
                    }
                    else{
                        $page->{codes}->{$name}=$t_code;
                    }
                }
            }
            $curindent=$codeindent;
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
                push @$pagelist, $pagename;
                $stage='page';
            }
            elsif($line=~/^resource:\s+(\w+)(.*)/){
                $grab_indent=$curindent;
                if($def->{resource}->{$1}){
                    $grab=$def->{resource}->{$1};
                }
                else{
                    $grab={"_list"=>[], "_name"=>$1};
                    $def->{resource}->{$1}=$grab;
                }
                my $t=$2;
                if($t=~/^\s*,\s*(.*)/){
                    my @tlist=split /,\s*/, $1;
                    $grab->{"_parents"}=\@tlist;
                }
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
                if($line=~/^(\w+):(:)? (.*\S)/){
                    my ($k,$dblcolon, $v)=($1, $2, $3);
                    expand_macro(\$v, $macros);
                    if($macros->{$k}){
                        if($dblcolon){
                            $macros->{$k}.=", ", $v;
                        }
                        else{
                            print STDERR " Overriden macro $k\n" if $debug>1;
                        }
                    }
                    else{
                        $macros->{$k}=$v;
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
sub get_path {
    my ($file)=@_;
}
sub get_lines {
    my ($file)=@_;
    my $filename="";
    if(-f $file){
        $filename=$file;
    }
    if(!$filename and $MyDef::var->{'include_path'}){
        my @dirs=split /:/, $MyDef::var->{'include_path'};
        foreach my $dir (@dirs){
            if(-f "$dir/$file"){
                $filename="$dir/$file";
                last;
            }
        }
    }
    if(!-f $filename){
        print "include_path: $MyDef::var->{include_path}\n";
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
    my $pagelist=$def->{pagelist};
    while(my ($name, $p)=each(%$pages)){
        if($p->{foreachfile}){
            my $pat_glob=$p->{foreachfile};
            my $pat_regex=$p->{foreachfile};
            my $n;
            $n=$pat_glob=~s/\(\*\)/\*/g;
            $pat_regex=~s/\(\*\)/\(\.\*\)/g;
            my @files=glob($pat_glob);
            foreach my $f (@files){
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
    foreach my $name (@codelist){
        if($name=~/^pre_(\w+)/ and !$codes->{"post_$1"}){
            my $loopname=$1;
            my $params=$codes->{$name}->{params};
            my $type=$codes->{$name}->{type};
            my $presource=$codes->{$name}->{source};
            my $source=[];
            my $t_code={'type'=>$type, 'source'=>$source, 'params'=>$params};
            foreach my $l (@$presource){
                if($l=~/\$openfor/){
                    push @$source, "DEDENT }";
                }
            }
            $codes->{"post_$loopname"}=$t_code;
        }
    }
}
sub dupe_page {
    my ($def, $orig, $n, @pat_list)=@_;
    my $pagename=dupe_line($orig->{pagename}, $n, @pat_list);
    print "    foreach file $pagename $n: ", join(",", @pat_list), "\n";
    my $page={};
    while(my ($k, $v)=each(%$orig)){
        if($k eq "pagename"){
            $page->{pagename}=$pagename;
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
            $page->{codes}=$codes;
        }
        elsif($k ne "foreachfile"){
            $page->{$k}=dupe_line($v);
        }
    }
    my $pages=$def->{pages};
    my $pagelist=$def->{pagelist};
    if($pages->{$pagename}){
        my $t=$pagename;
        my $j=0;
        while($pages->{$pagename}){
            $j++;
            $pagename=$t.$j;
        }
    }
    $pages->{$pagename}=$page;
    push @$pagelist, $pagename;
}
sub dupe_line {
    my ($l, $n, @pat_list)=@_;
    for(my $i=1; $i<=$n; $i++){
        my $rep=$pat_list[$i-1];
        $l=~s/\$$i/$rep/g;
    }
    return $l;
}
sub grab_ogdl {
    my ($ogdl, $llist)=@_;
    my $cur_i=0;
    my $cur_item=$ogdl;
    my $last_item;
    my $last_item_type;
    my $last_item_key;
    my @ogdl_stack;
    foreach my $l (@$llist){
        if($l=~/^(\d)+:(.*)/){
            my ($i, $l)=($1, $2);
            if($l=~/^NOOP/){
                next;
            }
            if($i>$cur_i){
                push @ogdl_stack, $cur_item;
                $cur_item={"_list"=>[]};
                if($last_item_type eq "array"){
                    $cur_item->{"_name"}=$last_item->[-1];
                    $last_item->[-1]=$cur_item;
                }
                elsif($last_item_type eq "hash"){
                    $cur_item->{"_name"}=$last_item->{$last_item_key};
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
