use strict;
package MyDef::parseutil;
our @includes;
our %includes;
our $in_default_page;
our $page;
our $code_index=0;
our $template_index = 0;
our $debug={};
our @path;
our %path;
our @indent_stack=(0);
our $time_start = time();

sub import_data {
    my ($file) = @_;
    my $def={"resource"=>{},
        "pages"=>{},
        "pagelist"=>[],
        "codes"=>{},
        "macros"=>{},
        };
    if($file=~/([^\/]+)\.def/){
        $def->{name}=$1;
        $def->{file}=find_file($file);
    }
    else{
        $def->{name}="default";
    }
    my $macros=$def->{macros};
    while(my ($k, $v)=each %$MyDef::var){
        if($k=~/macro_(\w+)/){
            $macros->{$1}=$v;
        }
    }
    import_file($file, $def, "main");
    my $module = $MyDef::var->{module};
    my @standard_includes;
    if($MyDef::var->{'include'} and !$includes{"noconfig"}){
        push @standard_includes, split(/[:,]\s*/, $MyDef::var->{'include'});
    }
    my $stdinc="std_$module.def";
    push @standard_includes, $stdinc;
    while(1){
        if(@includes){
            my $file=shift(@includes);
            import_file($file, $def, "include");
        }
        elsif(@standard_includes){
            my $file=shift(@standard_includes);
            import_file($file, $def, "standard_include");
        }
        else{
            last;
        }
    }
    if($in_default_page){
        if($def->{codes}->{basic_frame}){
            my $codes=$in_default_page->{codes};
            my $code={name=>"_frame", type=>"sub", params=>[]};
            $code->{source}=["\$call basic_frame"];
            $codes->{main2}=$codes->{main};
            $codes->{main} =$code;
        }
    }
    post_foreachfile($def);
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
    my ($f, $def, $file_type) = @_;
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
    if($file_type eq "main"){
        $page={_pagename=>$def->{name}, codes=>{}, main_name=>"main"};
        $in_default_page = $page;
        if(!@indent_stack){
            push @indent_stack, [$codetype, $codeindent, $codeitem];
        }
        $codetype   = "page";
        $codeindent = 0;
        $codeitem   = $page;
        $curindent=0;
        $lastindent = $curindent;
        $codetype   = "page";
        $codeindent = 0;
        $curindent = 0;
        $lastindent = 0;
    }
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
        while($curindent <$codeindent or ($in_default_page and $line=~/^END/ and $curindent==0 and @indent_stack)){
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
            $lastindent = $codeindent;
            if($codetype eq "code"){
                $source = $codeitem->{source};
                my $src_location="SOURCE: $cur_file - $cur_line";
                push @$source, $src_location;
            }
        }
        if(!@indent_stack){
            undef $page;
        }
        if($codetype eq "code" and ($codeindent>0 or $in_default_page)){
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
            my $parent;
            if($in_default_page and $curindent==0){
                $parent = $def;
            }
            elsif(!$in_default_page and $curindent==1 and $page){
                $parent = $page;
            }
            else{
                $parent = $codeitem;
            }
            if(!$parent->{codes}){
                $codes = {};
                $parent->{codes}=$codes;
            }
            else{
                $codes = $parent->{codes};
            }
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
                        print STDERR "[$src_location] overwiritten $type code: $name\n";
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
                        my $main_name = $page->{main_name};
                        my $t_code;
                        if($page->{codes}->{$main_name}){
                            $t_code = $page->{codes}->{$main_name};
                            $source = $t_code->{source};
                        }
                        else{
                            $source=[];
                            $t_code={'type'=>"sub", 'source'=>$source, 'params'=>[], 'name'=>"main"};
                            $page->{codes}->{$main_name}=$t_code;
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
            $curindent=$curindent+1;
            $lastindent = $curindent;
        }
        elsif($line=~/^macros:/ && $curindent == $codeindent and $codetype ne "macro"){
            my $parent;
            if($in_default_page and $curindent==0){
                $parent = $def;
            }
            elsif(!$in_default_page and $curindent==1 and $page){
                $parent = $page;
            }
            else{
                $parent = $codeitem;
            }
            if(!$parent->{macros}){
                $macros = {};
                $parent->{macros}=$macros;
            }
            else{
                $macros = $parent->{macros};
            }
            push @indent_stack, [$codetype, $codeindent, $codeitem];
            $codetype   = "macro";
            $codeindent = $curindent+1;
            $codeitem   = $macros;
            $curindent=$curindent+1;
            $lastindent = $curindent;
        }
        elsif($line=~/^template:/ && $curindent == $codeindent and $codetype ne "macro"){
            if(!$codeitem->{codes}){
                $codeitem->{codes}={};
            }
            my $codes = $codeitem->{codes};
            my @grab;
            my $t_code = {type=>"template",source=>\@grab};
            if($line =~ /^template:\s*(\w+)/){
                $codes->{$1}=$t_code;
            }
            else{
                warn "parseutil: template missing name\n";
            }
            my $grab_indent=$curindent;
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
                if($line eq ""){
                    push @grab, $line;
                }
                elsif($curindent>$grab_indent){
                    push @grab, '    'x($curindent-$grab_indent-1) . $line;
                }
                else{
                    last;
                }
            }
            $cur_line--;
        }
        elsif($curindent==0 and $line=~/^include:? (.*)/){
            if($1 eq "noconfig"){
                $includes{$1}=1;
            }
            else{
                if(!$includes{$1}){
                    $includes{$1}=1;
                    push @includes, $1;
                }
            }
        }
        elsif($curindent==0 and $line=~/^(sub)?page:\s*(.*)/){
            my ($subpage, $t)=($1, $2);
            my ($pagename, $framecode);
            if($t=~/([\w\-\$\.]+),\s*(\w.*)/){
                $pagename=$1;
                $framecode=$2;
            }
            elsif($t=~/([\w\-\$\.]+)/){
                $pagename=$1;
            }
            my $codes={};
            undef $in_default_page;
            $page={_pagename=>$pagename, codes=>$codes, main_name=>"main"};
            if($pagename=~/(.+)\.(.+)/){
                $page->{type}='';
            }
            if($framecode){
                my $code={name=>"_frame", type=>"sub", params=>[]};
                $codes->{main}=$code;
                if($framecode=~/^from\s+(\S+)/){
                    my $sub_name = get_template_sub_name();
                    $code->{source}=["\$call $sub_name"];
                    my $sub_definition = parse_template($def, $codes, $1, $sub_name);
                    push @includes, $sub_definition;
                    $page->{main_name}="main2";
                }
                else{
                    $code->{source}=["\$call $framecode"];
                    $page->{main_name}="main2";
                }
            }
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
            if(!@indent_stack){
                push @indent_stack, [$codetype, $codeindent, $codeitem];
            }
            $codetype   = "page";
            $codeindent = 1;
            $codeitem   = $page;
            $curindent=1;
            $lastindent = $curindent;
        }
        elsif($curindent==0 and $line=~/^DEBUG\s*(.*)/){
            parse_DEBUG($1);
        }
        elsif($codetype eq "code" and ($codeindent>0 or $in_default_page)){
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
        elsif($codetype eq "page" and (($in_default_page and $codeindent==0)  or (!$in_default_page and $codeindent==1))){
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
                my $main_name = $page->{main_name};
                my $t_code;
                if($page->{codes}->{$main_name}){
                    $t_code = $page->{codes}->{$main_name};
                    $source = $t_code->{source};
                }
                else{
                    $source=[];
                    $t_code={'type'=>"sub", 'source'=>$source, 'params'=>[], 'name'=>"main"};
                    $page->{codes}->{$main_name}=$t_code;
                }
                push @indent_stack, [$codetype, $codeindent, $codeitem];
                $codetype   = "code";
                $codeindent = $curindent;
                $codeitem   = $t_code;
                $curindent=$curindent;
                $lastindent = $curindent;
                push @$source, "SOURCE: $cur_file - $cur_line";
                if($line=~/\S/){
                    push @$source, $line;
                }
            }
        }
    }
    if($file_type eq "main"){
        if($in_default_page){
            my $pagename = $def->{name};
            $def->{pages}->{$pagename} = $in_default_page;
            push @{$def->{pagelist}}, $pagename;
        }
    }
}

sub get_lines {
    my ($file) = @_;
    if(ref($file) eq "ARRAY"){
        return $file;
    }
    elsif($file eq "-pipe"){
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

sub get_template_sub_name {
    my $sub_name = "TMP_$template_index";
    $template_index++;
    return $sub_name;
}

sub parse_template {
    my ($def, $pagecodes, $template_file, $sub_name) = @_;
    my $template_dir;
    if($def->{macros}->{TemplateDir}){
        $template_dir=$def->{macros}->{TemplateDir};
    }
    elsif($MyDef::var->{TemplateDir}){
        $template_dir=$MyDef::var->{TemplateDir};
    }
    if($template_dir){
        if($template_file!~/^\.*\//){
            $template_file = $template_dir.'/'.$template_file;
        }
    }
    my @new_source;
    push @new_source, "subcode: $sub_name";
    my $t_idx = 0;
    $t_idx++;
    my $cur_source=[];
    $pagecodes->{"_T_$t_idx"} = {type=>'template', source=>$cur_source, 'params'=>[]};
    push @new_source, "    \$call _T_$t_idx";
    my $cur_grab_spaces;
    my $start_grab;
    my $cur_grab;
    open In, "$template_file" or die "Can't open $template_file.\n";
    while(<In>){
        if($start_grab){
            if(/^\s*$/){
                push @$cur_grab, $_;
            }
            elsif(/^(\s*)(.*)/){
                my $n= get_indent_spaces($1);
                if($n <= $cur_grab_spaces){
                    if($start_grab eq "mydef"){
                        my $len = $cur_grab_spaces;
                        my $n=int($len/4);
                        if($len % 4){
                            $n++;
                        }
                        for(my $i=0; $i<$n; $i++){
                            push @new_source, "    INDENT";
                        }
                        push @new_source, @$cur_grab;
                        for(my $i=0; $i<$n; $i++){
                            push @new_source, "    DEDENT";
                        }
                        $t_idx++;
                        my $cur_source=[];
                        $pagecodes->{"_T_$t_idx"} = {type=>'template', source=>$cur_source, 'params'=>[]};
                        push @new_source, "    \$call _T_$t_idx";
                        push @$cur_source, $_;
                    }
                    undef $start_grab;
                    next;
                }
                else{
                    my $new_spaces = $n-$cur_grab_spaces;
                    if($start_grab eq "mydef"){
                        if($new_spaces<4){
                            push @$cur_grab, "    $2\n";
                        }
                        else{
                            push @$cur_grab, ' 'x$new_spaces . "$2\n";
                        }
                    }
                    elsif($start_grab eq "template"){
                        if($new_spaces<4){
                            push @$cur_grab, "$2\n";
                        }
                        else{
                            push @$cur_grab, ' 'x($new_spaces-4) . "$2\n";
                        }
                    }
                }
            }
        }
        elsif(/^(\s*)(mydef):/){
            $cur_grab_spaces=get_indent_spaces($1);
            $start_grab = $2;
            $cur_grab=[];
        }
        elsif(/^(\s*)template:\s*(\w+)/){
            $cur_grab_spaces=get_indent_spaces($1);
            $start_grab = "template";
            $cur_grab=[];
            $pagecodes->{$2}={type=>"template", source=>$cur_grab, 'params'=>[]};
        }
        else{
            if(/^\s*DUMP_STUB\s+(\w+)/){
                $page->{"has_stub_$1"}=1;
            }
            push @$cur_source, $_;
        }
    }
    close In;
    return \@new_source;
}

sub parse_DEBUG {
    my ($t) = @_;
    if($t=~/^(\d+)/){
        $debug->{def}=1;
        $debug->{n}=$1;
    }
    elsif($t){
        $debug->{$t}=1;
    }
    else{
        $debug->{def}=1;
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
        my $m = $debug->{n};
        if(!$m){
            $m = 3;
        }
        elsif($m>$n){
            $m = $n;
        }
        if($continue){
            print "$n elements\n";
        }
        for(my $i=0; $i<$m; $i++){
            if($i<$n){
                print_def_node($node->[$i], $indent+1);
            }
        }
        if($n>$m){
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
    for(my $i=0; $i<$n; $i++){
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

@includes=();
%includes=();
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
sub dupe_page {
    my ($def, $orig, $n, @pat_list)=@_;
    my $pagename=dupe_line($orig->{name}, $n, @pat_list);
    print "    foreach file $pagename $n: ", join(",", @pat_list), "\n";
    my $page={};
    while(my ($k, $v)=each(%$orig)){
        if($k eq "pagename"){
            $page->{name}=$pagename;
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
1;
