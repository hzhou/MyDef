use strict;
use warnings;
package MyDef::parseutil;
our $debug=0;
our $defname="default";
our $code_index=0;
our @path;
our %path;
our @indent_stack=(0);

sub import_data {
    my ($file) = @_;
    if($file=~/([^\/]+)\.def/){
        $defname=$1;
    }
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
    import_file($file, $def, \@includes,\%includes, "main");
    my @standard_includes;
    if($MyDef::var->{'include'} and !$includes{"noconfig"}){
        push @standard_includes, split(/[:,]\s*/, $MyDef::var->{'include'});
    }
    my $stdinc="std_".$MyDef::var->{module}.".def";
    push @standard_includes, $stdinc;
    while(1){
        if(@includes){
            my $file=shift(@includes);
            import_file($file, $def, \@includes,\%includes, "include");
        }
        elsif(@standard_includes){
            my $file=shift(@standard_includes);
            import_file($file, $def, \@includes,\%includes, "standard_include");
        }
        else{
            last;
        }
    }
    post_foreachfile($def);
    post_matchblock($def);
    if($debug){
        foreach my $k (keys %$debug){
            if($k eq "def"){
                debug_def($def);
            }
            elsif($k=~/^code:\s*(\w+)/){
                debug_code($def->{codes}->{$1});
            }
        }
    }
    return $def;
}

sub import_file {
    my ($f, $def, $include_list, $include_hash, $file_type) = @_;
    my $page;
    my $curindent=0;
    my $codetype = "top";
    my $codeindent = 0;
    my $codeitem = $def;
    my @indent_stack;
    my $pages=$def->{pages};
    my $pagelist=$def->{pagelist};
    my $codes=$def->{codes};
    my $macros=$def->{macros};
    my $lastindent;
    my $source;
    my $code_prepend;
    my $plines=get_lines($f);
    push @$plines, "END";
    my $cur_file=$f;
    my $cur_line=0;
    while($cur_line < @$plines){
        my $line = $plines->[$cur_line];
        $cur_line++;
        if($line=~/^\s*\/\*/){
            if($line !~ /\*\/\s*$/){
                while($cur_line < @$plines){
                    my $line = $plines->[$cur_line];
                    $cur_line++;
                    if($line=~/\*\/\s*$/){
                        last;
                    }
                }
            }
            next;
        }
        if($line=~/^\s*$/){
            $line="";
        }
        elsif($line=~/^(\s*)(.*)/){
            my $indent=get_indent($1);
            $line=$2;
            if($line=~/^#(?!(define|undef|include|line|error|pragma|if|ifdef|ifndef|elif|else|endif)\b)/){
                if($indent != $curindent){
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
        while($curindent <$codeindent){
            if($codetype eq "code"){
                while($codeindent<$lastindent){
                    $lastindent--;
                    push @$source, "SOURCE_DEDENT";
                }
                if($code_prepend){
                    push @$source, @$code_prepend;
                }
            }
            my $t = pop @indent_stack;
            ($codetype, $codeindent, $codeitem) = @$t;
            if($codetype eq "code"){
                $lastindent = $codeindent;
                $source = $codeitem->{source};
                my $src_location="SOURCE: $cur_file - $cur_line";
                push @$source, $src_location;
            }
        }
        if($codeindent>0 and $codetype eq "code"){
            while($curindent>$lastindent){
                $lastindent++;
                push @$source, "SOURCE_INDENT";
            }
            while($curindent<$lastindent){
                $lastindent--;
                push @$source, "SOURCE_DEDENT";
            }
        }
        if($line=~/^\w+code:/ && $curindent == $codeindent and $codetype ne "macro"){
            if($curindent==1 && $codetype eq "code" && $indent_stack[-1]->[0] eq "page"){
                while($codeindent<$lastindent){
                    $lastindent--;
                    push @$source, "SOURCE_DEDENT";
                }
                if($code_prepend){
                    push @$source, @$code_prepend;
                }
                my $t = pop @indent_stack;
                ($codetype, $codeindent, $codeitem) = @$t;
            }
            if(!$codeitem->{codes}){
                $codeitem->{codes}={};
            }
            my $codes = $codeitem->{codes};
            my $t_code;
            if($line=~/^(\w+)code:([:-@]?)\s*(\w+)(.*)/){
                my ($type, $dblcolon, $name, $t)=($1, $2, $3, $4);
                if($name eq "_autoload"){
                    $dblcolon=":";
                }
                my $src_location="SOURCE: $cur_file - $cur_line";
                $source=[$src_location];
                undef $code_prepend;
                if($codes->{$name} and (!$codes->{$name}->{attr} or $codes->{$name}->{attr} ne "default")){
                    $t_code=$codes->{$name};
                    if($dblcolon eq "@"){
                    }
                    elsif($dblcolon eq ":"){
                        $source=$t_code->{source};
                        push @$source, $src_location;
                    }
                    elsif($dblcolon eq "-"){
                        $code_prepend=$t_code->{source};
                        $t_code->{source} = $source;
                    }
                    elsif($codes->{$name}->{attr} and $codes->{$name}->{attr} eq "optional"){
                        $t_code->{attr}=undef;
                        $source=$t_code->{source};
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
                    $code_index++;
                    $t_code={'type'=>$type, 'index'=>$code_index, 'source'=>$source, 'params'=>\@params, 'name'=>$name};
                    if($dblcolon eq "@"){
                        $t_code->{attr}="default";
                    }
                    elsif($dblcolon eq ":" or $dblcolon eq "-"){
                        $t_code->{attr}="optional";
                    }
                    if($codetype eq "page" && $name eq "main"){
                        if($page->{codes}->{main}){
                            $page->{codes}->{'main2'}=$t_code;
                        }
                        else{
                            $page->{codes}->{"main"}=$t_code;
                        }
                    }
                    else{
                        $codes->{$name}=$t_code;
                    }
                }
            }
            push @indent_stack, [$codetype, $codeindent, $codeitem];
            $codetype   = "code";
            $codeindent = $curindent+1;
            $codeitem   = $t_code;
            $lastindent = $curindent+1;
            $curindent=$curindent+1;
        }
        elsif($line=~/^macros:/ && $curindent == $codeindent and $codetype ne "macro"){
            if(!$codeitem->{macros}){
                $codeitem->{macros}={};
            }
            $macros = $codeitem->{macros};
            push @indent_stack, [$codetype, $codeindent, $codeitem];
            $codetype   = "macro";
            $codeindent = $curindent+1;
            $codeitem   = $macros;
        }
        elsif($codeindent>0 and $codetype eq "code"){
            push @$source, $line;
        }
        elsif($codeindent>0 and $codetype eq "macro"){
            if($line=~/^(\w+):(:)?\s*(.*\S)/){
                my ($k,$dblcolon, $v)=($1, $2, $3);
                expand_macro(\$v, $macros);
                if($macros->{$k}){
                    if($dblcolon){
                        $macros->{$k}.=", $v";
                    }
                    elsif($debug){
                        print "Denied overwriting macro $k\n";
                    }
                }
                else{
                    $macros->{$k}=$v;
                }
            }
        }
        elsif($curindent==0){
            if($line=~/^include:? (.*)/){
                if(!$include_hash->{$1}){
                    if($1 ne "noconfig"){
                        push @$include_list, $1;
                    }
                    $include_hash->{$1}=1;
                }
            }
            elsif($line=~/^path:\s*(.+)/){
                add_path($1);
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
                if($file_type eq "main"){
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
                push @indent_stack, [$codetype, $codeindent, $codeitem];
                $codetype   = "page";
                $codeindent = 1;
                $codeitem   = $page;
            }
            elsif($line=~/^resource:\s+(\w+)(.*)/){
                my $grab;
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
                my $grab_indent=$curindent;
                my @grab;
                while($cur_line < @$plines){
                    my $line = $plines->[$cur_line];
                    $cur_line++;
                    if($line=~/^\s*$/){
                        $line="";
                    }
                    elsif($line=~/^(\s*)(.*)/){
                        my $indent=get_indent($1);
                        $line=$2;
                        if($line=~/^#(?!(define|undef|include|line|error|pragma|if|ifdef|ifndef|elif|else|endif)\b)/){
                            if($indent != $curindent){
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
                    if($curindent>$grab_indent){
                        my $i=$curindent-$grab_indent-1;
                        push @grab, "$i:$line";
                    }
                    else{
                        grab_ogdl($grab, \@grab);
                    }
                }
                $cur_line--;
            }
            elsif($line=~/^DEBUG\s*(.*)/){
                if($1){
                    $debug->{$1}=1;
                }
                else{
                    $debug->{def}=1;
                }
            }
        }
        elsif($codeindent==1 and $codetype eq "page"){
            if($line=~/^(\w+):\s*(.*)/){
                my $k=$1;
                my $v=$2;
                expand_macro(\$v, $macros);
                $page->{$k}=$v;
            }
            elsif($line=~/^\s*$/){
                next;
            }
            else{
                my $src_location="SOURCE: $cur_file - $cur_line";
                $source=[$src_location];
                if($line=~/\S/){
                    push @$source, $line;
                }
                my $t_code={'type'=>"sub", 'source'=>$source, 'params'=>[], 'name'=>"main"};
                if($page->{codes}->{main}){
                    $page->{codes}->{'main2'}=$t_code;
                }
                else{
                    $page->{codes}->{"main"}=$t_code;
                }
                push @indent_stack, [$codetype, $codeindent, $codeitem];
                $codetype   = "code";
                $codeindent = 1;
                $codeitem   = $t_code;
                $lastindent = 1;
                $curindent=1;
            }
        }
    }
}

sub expand_macro {
    my ($lref, $macros) = @_;
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
    my ($file) = @_;
    if($file eq "-pipe"){
        my @lines=<STDIN>;
        return \@lines;
    }
    else{
        my $filename=find_file($file);
        my @lines;
        {
            open In, "$filename" or die "Can't open $filename.\n";
            @lines=<In>;
            close In;
        }
        return \@lines;
    }
}

sub debug_def {
    my ($def) = @_;
    print_def_node($def, 0);
}

sub print_def_node {
    my ($node, $indent, $continue) = @_;
    if(ref($node) eq "HASH"){
        if($continue){
            print "\n";
        }
        while (my ($k, $v) = each %$node){
            print "    "x$indent;
            print "$k: ";
            print_def_node($v, $indent+1, 1);
        }
    }
    elsif(ref($node) eq "ARRAY"){
        my $n = @$node;
        if($continue){
            print "$n elements\n";
        }
        for(my $i=0; $i <3; $i++){
            if($i<$n){
                print_def_node($node->[$i], $indent+1);
            }
        }
        if($n>3){
            print_def_node("...", $indent+1);
        }
    }
    else{
        if(!$continue){
            print "    "x$indent;
        }
        print $node, "\n";
    }
}

sub debug_code {
    my ($code) = @_;
    print "$code->{name}:\n";
    foreach my $l (@{$code->{source}}){
        print "    $l\n";
    }
    if($code->{codes}){
        while (my ($k, $v) = each %{$code->{codes}}){
            print "---------\n";
            debug_code($v);
        }
    }
}

sub add_path {
    my ($dir) = @_;
    if(!$dir){
        return;
    }
    my $deflib=$ENV{MYDEFLIB};
    my $defsrc=$ENV{MYDEFSRC};
    if($dir=~/\$\(MYDEFSRC\)/){
        if(!$defsrc){
            die "MYDEFSRC not defined (in environment)!\n";
        }
        $dir=~s/\$\(MYDEFSRC\)/$defsrc/g;
    }
    my @tlist = split /:/, $dir;
    foreach my $t (@tlist){
        if(!$path{$t}){
            if(-d $t){
                $path{$t}=1;
                push @path, $t;
            }
            else{
                warn "add_path: [$t] not a directory\n";
            }
        }
    }
}

sub find_file {
    my ($file) = @_;
    if(-f $file){
        return $file;
    }
    if(@path){
        foreach my $dir (@path){
            if(-f "$dir/$file"){
                return "$dir/$file";
            }
        }
    }
    if(1){
        warn "$file not found\n";
        warn "  search path: ".join(":", @path)."\n";
    }
    return undef;
}

sub get_indent {
    my ($s) = @_;
    my $i=get_indent_spaces($s);
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

sub get_indent_spaces {
    my ($t) = @_;
    use integer;
    my $n=length($t);
    my $count=0;
    for(my $i=0; $i <$n; $i++){
        if(substr($t, $i, 1) eq ' '){
            $count++;
        }
        elsif(substr($t, $i, 1) eq "\t"){
            $count=($count/8+1)*8;
        }
        else{
            return $count;
        }
    }
    return $count;
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
