use strict;
package MyDef::parseutil;

our @includes;
our %includes;
our $in_default_page;
our $code_index=0;
our $template_idx=0;
our %template_file_hash;
our $debug;
our @path;
our %path;
our @indent_stack=(0);

@includes=();
%includes=();
1;

# ---- subroutines --------------------------------------------
sub import_data {
    my ($file) = @_;
    my $def={
        "pages"=>{},
        "pagelist"=>[],
        "macros"=>{},
        };

    if ($file=~/([^\/]+)\.def/) {
        $def->{_defname}=$1;
        $def->{_deffile}=find_file($file);
    }
    else {
        $def->{_defname}="default";
    }
    my $macros=$def->{macros};
    while(my ($k, $v)=each %$MyDef::var){
        if ($k=~/macro_(\w+)/) {
            $macros->{$1}=$v;
        }
    }
    import_file($file, $def, "main");
    my $module = $MyDef::var->{module};

    my @standard_includes;
    if ($MyDef::var->{'include'}) {
        push @standard_includes, split(/[:,]\s*/, $MyDef::var->{'include'});
    }

    my $stdinc="std_$module.def";
    push @standard_includes, $stdinc;
    while(1){
        if (@includes) {
            my $file=shift(@includes);
            import_file($file, $def, "include");
        }
        elsif (@standard_includes) {
            my $file=shift(@standard_includes);
            import_file($file, $def, "standard_include");
        }
        else {
            last;
        }
    }
    merge_codes($def);
    my $pages=$def->{pages};
    while (my ($k, $v) = each %$pages) {
        merge_codes($v);
    }

    if ($in_default_page) {
        if ($def->{codes}->{basic_frame}) {
            $in_default_page->{_frame}="basic_frame";
        }
    }
    if ($debug) {
        foreach my $k (keys %$debug) {
            if ($k eq "def") {
                debug_def($def);
                exit;
            }
            elsif ($k=~/^code:\s*(\w+)/) {
                debug_code($def->{codes}->{$1});
                exit;
            }
        }
    }
    post_foreachfile($def);
    return $def;
}

sub import_file {
    my ($f, $def, $file_type) = @_;
    if ($debug->{import}) {
        print "import_file: $f\n";
    }
    my $plines=get_lines($f);
    if (!$plines) {
        return;
    }
    push @$plines, "END";
    my $cur_file=$f;
    my $cur_line=0;
    my $line_skipped=0;
    my $curindent=0;
    my ($codetype, $codeindent, $codeitem) = ("top",0,$def);
    my @indent_stack;
    my $pages=$def->{pages};
    my $pagelist=$def->{pagelist};
    my $macros=$def->{macros};
    my $lastindent;
    my $source;
    if ($file_type eq "main") {
        my $page={_pagename=>$def->{_defname}};
        $source=[];
        my $parent=$page;
        my $code_list;
        if (!$parent->{code_list}) {
            $code_list = [];
            $parent->{code_list}=$code_list;
        }
        else {
            $code_list = $parent->{code_list};
        }
        my $_t = new_code("sub","main");
        push @{$code_list}, $_t;
        $_t->{source}=$source;
        push @indent_stack, [$codetype, $codeindent, $codeitem];
        $codetype   = "code";
        $codeindent = 0;
        $codeitem   = $_t;
        $curindent=0;
        $lastindent = $curindent;
        $codetype   = "code";
        $codeindent = 0;
        $curindent = 0;
        $lastindent = 0;
        $in_default_page = $page;
        while ($plines->[$cur_line]=~/^(\w+):\s*(.*)/) {
            my ($k, $v) = ($1, $2);
            $v=~s/\s*#.*//;
            if ($k =~ /^(page|macros|\w+code|template)$/) {
                last;
            }
            elsif ($k eq "output_dir") {
                $MyDef::var->{output_dir}=$v;
            }
            elsif ($k eq "include") {
                if ($v eq "$def->{_defname}.def") {
                    print "include main self [$v]?\n";
                }
                else {
                    if (!$includes{$v}) {
                        $includes{$v}=1;
                        push @includes, $v;
                    }
                }
            }
            else {
                $page->{$k}=$v;
            }
            $cur_line++;
        }
    }
    while($cur_line < @$plines){
        my $line = $plines->[$cur_line];
        $cur_line++;
        if ($line=~/^\s*\/\*/) {
            if ($line !~ /\*\/\s*$/) {
                while($cur_line < @$plines){
                    my $line = $plines->[$cur_line];
                    $cur_line++;
                    if ($line=~/\*\/\s*$/) {
                        last;
                    }
                }
            }
            $line_skipped=1;
            next;
        }
        if ($line=~/^\s*$/) {
            $line="NEWLINE?";
        }
        elsif ($line=~/^(\s*)(.*)/) {
            my $indent=get_indent($1);
            $line=$2;
            if ($line=~/^#(?!(define|undef|include|line|error|pragma|if|ifdef|ifndef|elif|else|endif)\b)/) {
                if ($line=~/^#\\n/) {
                    $line="NEWLINE?";
                }
                elsif ($indent != $curindent) {
                    $line="NOOP";
                }
                else {
                    $line_skipped=1;
                    next;
                }
            }
            else {
                $line=~s/\s+$//;
                $line=~s/\s+#\s.*$//;
            }
            $curindent=$indent;
        }
        while($curindent <$codeindent or ($in_default_page and $line=~/^END/ and $curindent==0 and @indent_stack)){
            if ($codetype eq "code") {
                while($codeindent<$lastindent){
                    $lastindent--;
                    if ($source->[-1] eq "NEWLINE?") {
                        pop @$source;
                        push @$source, "SOURCE_DEDENT";
                        push @$source, "NEWLINE?";
                    }
                    else {
                        push @$source, "SOURCE_DEDENT";
                    }
                }
            }
            my $t = pop @indent_stack;
            ($codetype, $codeindent, $codeitem) = @$t;
            $lastindent = $codeindent;
            if ($codetype eq "code") {
                $source = $codeitem->{source};
                push @$source, "SOURCE: $cur_file - $cur_line";
            }
        }
        if ($codetype eq "code" and ($codeindent>0 or $in_default_page)) {
            while($curindent>$lastindent){
                $lastindent++;
                push @$source, "SOURCE_INDENT";
            }
            if ($line_skipped) {
                push @$source, "SOURCE: $cur_file - ".($cur_line-1);
                $line_skipped=0;
            }
            while($curindent<$lastindent){
                $lastindent--;
                if ($source->[-1] eq "NEWLINE?") {
                    pop @$source;
                    push @$source, "SOURCE_DEDENT";
                    push @$source, "NEWLINE?";
                }
                else {
                    push @$source, "SOURCE_DEDENT";
                }
            }
        }
        if ($line=~/^\w+code:/ && $curindent == $codeindent and $codetype ne "macro") {
            $source=[];
            push @$source, "SOURCE: $cur_file - $cur_line";

            my $t_code;
            expand_macro(\$line, $macros);
            if ($line=~/^(\w+)code:([:@\d]?)\s*([\w:]+)(.*)/) {
                my ($type, $attr, $name, $t) = ($1, $2, $3, $4);
                if ($name=~/^((?:\w+::)*\w*)(:(?:$|\w.*))/) {
                    $name = $1;
                    $t = "$2$t";
                }
                if ($t=~/^(\.\w+)(.*)/) {
                    $name .= $1;
                    $t = $2;
                }
                my $parent;
                if ($curindent==0) {
                    $parent = $def;
                }
                elsif ($curindent==1 and $#indent_stack==1 and !$in_default_page) {
                    $parent = $indent_stack[1]->[2];
                }
                else {
                    $parent = $codeitem;
                }
                my $code_list;
                if (!$parent->{code_list}) {
                    $code_list = [];
                    $parent->{code_list}=$code_list;
                }
                else {
                    $code_list = $parent->{code_list};
                }
                my $_t = new_code($type,$name,$attr,$t);
                push @{$code_list}, $_t;
                $_t->{source}=$source;
                $t_code = $_t;
            }
            else {
                $t_code= {};
            }

            push @indent_stack, [$codetype, $codeindent, $codeitem];
            $codetype   = "code";
            $codeindent = $curindent+1;
            $codeitem   = $t_code;
            $curindent=$curindent+1;
            $lastindent = $curindent;
        }
        elsif ($line=~/^macros:/ && $curindent == $codeindent and $codetype ne "macro") {
            my $parent;
            if ($curindent==0) {
                $parent = $def;
            }
            elsif ($curindent==1 and $#indent_stack==1 and !$in_default_page) {
                $parent = $indent_stack[1]->[2];
            }
            else {
                $parent = $codeitem;
            }
            my $macros;
            if (!$parent->{macros}) {
                $macros = {};
                $parent->{macros}=$macros;
            }
            else {
                $macros = $parent->{macros};
            }
            push @indent_stack, [$codetype, $codeindent, $codeitem];
            $codetype   = "macro";
            $codeindent = $curindent+1;
            $codeitem   = $macros;
            $curindent=$curindent+1;
            $lastindent = $curindent;
        }
        elsif ($line=~/^template:/ && $curindent == $codeindent and $codetype ne "macro") {
            my @grab;
            if ($line =~ /^template:\s*(\w+)/) {
                my $parent;
                if ($curindent==0) {
                    $parent = $def;
                }
                elsif ($curindent==1 and $#indent_stack==1 and !$in_default_page) {
                    $parent = $indent_stack[1]->[2];
                }
                else {
                    $parent = $codeitem;
                }
                my $code_list;
                if (!$parent->{code_list}) {
                    $code_list = [];
                    $parent->{code_list}=$code_list;
                }
                else {
                    $code_list = $parent->{code_list};
                }
                my $_t = new_code("template", $1);
                push @{$code_list}, $_t;
                $_t->{source}=\@grab;
            }
            else {
                warn "parseutil: template missing name\n";
            }

            my $grab_indent=$curindent;
            while($cur_line < @$plines){
                my $line = $plines->[$cur_line];
                $cur_line++;
                if ($line=~/^\s*$/) {
                    $line="NEWLINE?";
                }
                elsif ($line=~/^(\s*)(.*)/) {
                    my $indent=get_indent($1);
                    $line=$2;
                    if ($line=~/^#(?!(define|undef|include|line|error|pragma|if|ifdef|ifndef|elif|else|endif)\b)/) {
                        if ($line=~/^#\\n/) {
                            $line="NEWLINE?";
                        }
                        elsif ($indent != $curindent) {
                            $line="NOOP";
                        }
                        else {
                            $line_skipped=1;
                            next;
                        }
                    }
                    else {
                        $line=~s/\s+$//;
                        $line=~s/\s+#\s.*$//;
                    }
                    $curindent=$indent;
                }
                if ($line eq "") {
                    push @grab, $line;
                }
                elsif ($curindent>$grab_indent) {
                    push @grab, '    'x($curindent-$grab_indent-1) . $line;
                }
                else {
                    last;
                }
            }
            $cur_line--;
        }
        elsif ($line=~/^output_dir:\s*(.+)/) {
            $MyDef::var->{output_dir}=$1;
        }
        elsif ($curindent==0 and $line=~/^include:?\s*(.*)/) {
            if ($1 eq "$def->{_defname}.def") {
                print "include main self [$1]?\n";
            }
            else {
                if (!$includes{$1}) {
                    $includes{$1}=1;
                    push @includes, $1;
                }
            }
        }
        elsif ($curindent==0 and $line=~/^page:\s*(.*)/) {
            my ($t) = ($1);
            undef $in_default_page;
            my ($pagename, $frame);
            if ($t=~/([\w\-\$\.]+),\s*(\w.*|-)/) {
                $pagename=$1;
                $frame=$2;
                if ($frame=~/^from\s+(\S+)/) {
                    $frame= parse_template($def, $1);
                }
            }
            elsif ($t=~/([\w\-\$\.]+)/) {
                $pagename=$1;
            }
            my $page={_pagename=>$pagename};
            if ($frame) {
                $page->{_frame}=$frame;
            }
            @indent_stack=(["top",0,$def]);
            $codetype   = "page";
            $codeindent = 1;
            $codeitem   = $page;
            $curindent=1;
            $lastindent = $curindent;
            if ($file_type eq "main") {
                if ($pages->{$pagename}) {
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
            my $sp;
            while($cur_line < @$plines){
                my $line = $plines->[$cur_line];
                $cur_line++;
                if ($line=~/^(\s+)(?:#|(\w+):\s*(.*))/) {
                    if (!$sp) {
                        $sp=$1;
                    }
                    elsif ($sp ne $1) {
                        last;
                    }

                    my ($k, $v)=($2,$3);
                    if ($k=~/^(macros|\w+code|template)$/) {
                        last;
                    }
                    expand_macro(\$v, $macros);
                    $page->{$k}=$v;
                }
                else {
                    if ($line=~/^$/) {
                        $cur_line++;
                    }
                    last;
                }
            }
            $cur_line--;
            $source=[];
            my $parent=$page;
            my $code_list;
            if (!$parent->{code_list}) {
                $code_list = [];
                $parent->{code_list}=$code_list;
            }
            else {
                $code_list = $parent->{code_list};
            }
            my $_t = new_code("sub","main");
            push @{$code_list}, $_t;
            $_t->{source}=$source;
            push @$source, "SOURCE: $cur_file - $cur_line";
            push @indent_stack, [$codetype, $codeindent, $codeitem];
            $codetype   = "code";
            $codeindent = 1;
            $codeitem   = $_t;
            $curindent=1;
            $lastindent = $curindent;
        }
        elsif ($curindent==0 and $line=~/^DEBUG\s*(.*)/) {
            parse_DEBUG($1);
        }
        elsif ($codetype eq "code" and ($codeindent>0 or $in_default_page)) {
            if ($line=~/^\$template\s+(.+)/) {
                my $name = parse_template($def, $1);
                $line = "\$call $name";
            }
            push @$source, $line;
        }
        elsif ($codetype eq "macro" and $codeindent>0) {
            if ($line=~/^(\w+):([:!=])?\s*(.*)/) {
                my ($k,$dblcolon, $v)=($1, $2, $3);
                expand_macro(\$v, $macros);
                if ($macros->{$k}!~/^$/) {
                    if ($dblcolon eq ':') {
                        if ($v!~/^$/) {
                            $macros->{$k}.=", $v";
                        }
                    }
                    elsif ($dblcolon eq '!') {
                        $macros->{$k}=$v;
                    }
                    elsif ($macros->{$k} ne $v) {
                    }
                }
                elsif ($dblcolon eq '=') {
                    $macros->{$k} = eval($v);
                }
                else {
                    $macros->{$k}=$v;
                }
            }
            elsif ($line=~/^(.*):\s*(.*)/) {
                my ($t1, $t2) = ($1, $2);
                my @klist=split /,\s*/, $t1;
                my @vlist=MyDef::utils::get_tlist($t2);
                for (my $_i = 0; $_i < @klist; $_i++) {
                    my $k = $klist[$_i];
                    my $v = $vlist[$_i];
                    $macros->{$k}=$v;
                }
            }
        }
        else {
        }
    }
    if ($file_type eq "main") {
        if ($in_default_page) {
            my $pagename = $def->{_defname};
            $def->{pages}->{$pagename} = $in_default_page;
            push @{$def->{pagelist}}, $pagename;
            $def->{in_default_page}=1;
        }
    }
}

sub get_lines {
    my ($file) = @_;
    if (ref($file) eq "ARRAY") {
        return $file;
    }
    elsif ($file eq "-pipe") {
        my @lines=<STDIN>;
        return \@lines;
    }
    else {
        my $filename=find_file($file);
        if ($filename) {
            my @lines;
            {
                open In, "$filename" or die "Can't open $filename.\n";
                @lines=<In>;
                close In;
            }
            return \@lines;
        }
        return undef;
    }
}

sub expand_macro {
    my ($lref, $macros) = @_;
    while ($$lref=~/\$\(\w+\)/) {
        my @segs=split /(\$\(\w+\))/, $$lref;
        my $j=0;
        my $flag=0;
        foreach my $s (@segs) {
            if ($s=~/\$\((\w+)\)/) {
                my $t=$macros->{$1};
                if ($t eq $s) {
                    die "Looping macro $1 in \"$$lref\"!\n";
                }
                if (defined $t) {
                    $segs[$j]=$t;
                    $flag++;
                }
            }
            $j++;
        }
        if ($flag) {
            $$lref=join '', @segs;
        }
        else {
            last;
        }
    }
}

sub new_code {
    my ($type, $name, $attr, $t) = @_;
    $code_index++;
    my $t_code={type=>$type, index=>$code_index, name=>$name};
    if (!$attr) {
        if ($name=~/^(.*_autoload|main)$/) {
            $attr=":";
        }
    }
    if ($attr=~/^[0-9]$/) {
        $t_code->{order}=$attr;
    }
    elsif ($attr eq '@') {
        $t_code->{order}=0;
    }
    elsif ($attr eq ':') {
        $t_code->{order}=5;
    }
    else {
        $t_code->{order}=9;
    }
    if ($t) {
        if ($t=~/^\s*\(\s*(.*)\)(.*)/) {
            $t=$2;
            my @params=split /,\s*/, $1;
            $t_code->{params}=\@params;
        }
        if ($t=~/^\s*:\s*(.+)/) {
            $t_code->{tail} = $1;
        }
    }
    return $t_code;
}

sub merge_codes {
    my ($codeitem) = @_;
    my $L=$codeitem->{code_list};
    if (!$L) {
        return;
    }
    if ($codeitem->{codes}) {
        warn "parseutils: codeitem with existing {codes}?\n";
    }
    my %H;
    my @sorted = sort {$a->{order} <=> $b->{order} } @$L;
    foreach my $code (@sorted) {
        my $name = $code->{name};
        if (!$H{$name}) {
            $H{$name} = $code;
        }
        else {
            my $a = $H{$name}->{order};
            my $b = $code->{order};
            if ($a==0) {
                $H{$name}=$code;
            }
            elsif ($b==9) {
                if ($a==9) {
                    my $loc_a = $H{$name}->{source}->[0];
                    my $loc_b = $code->{source}->[0];
                    $loc_a=~s/SOURCE: //;
                    $loc_b=~s/SOURCE: //;
                    print "Not overwriting subcode $name: [$loc_a] -> [$loc_b]\n";
                }
                else {
                    my $loc_a = $H{$name}->{source}->[0];
                    my $loc_b = $code->{source}->[0];
                    $loc_a=~s/SOURCE: //;
                    $loc_b=~s/SOURCE: //;
                    print "Overwriting subcode $name: [$loc_a] -> [$loc_b]\n";
                    $H{$name}=$code;
                }
            }
            else {
                my $src_a = $H{$name}->{source};
                my $src_b = $code->{source};
                push @$src_a, @$src_b;
                my $m_a = $H{$name}->{macros};
                my $m_b = $code->{macros};
                while (my ($k, $v) = each %$m_b) {
                    $m_a->{$k}=$v;
                }
                my $l_a = $H{$name}->{code_list};
                my $l_b = $code->{code_list};
                if ($l_a and $l_b) {
                    push @$l_a, @$l_b;
                }
                elsif ($l_b) {
                    $H{$name}->{code_list}=$l_b;
                }
            }
        }
        clean_up_source($H{$name}->{source});
    }
    $codeitem->{codes}=\%H;
    undef $codeitem->{code_list};
    while (my ($k, $v) = each %H) {
        merge_codes($v);
    }
}

sub clean_up_source {
    my ($src) = @_;
    if ($src and @$src) {
        my $i=$#$src;
        while ($i>=0 and $src->[$i]=~/^(SOURCE: .*|\s*|NEWLINE\?)$/) {
            pop @$src;
            $i--;
        }
    }
}

sub parse_template {
    my ($def, $template_file) = @_;
    my $template_dir;
    if ($def->{macros}->{TemplateDir}) {
        $template_dir=$def->{macros}->{TemplateDir};
    }
    elsif ($MyDef::var->{TemplateDir}) {
        $template_dir=$MyDef::var->{TemplateDir};
    }

    if ($template_dir) {
        if ($template_file!~/^\.*\//) {
            $template_file = $template_dir.'/'.$template_file;
        }
    }

    if ($template_file_hash{$template_file}) {
        return $template_file_hash{$template_file};
    }
    else {
        $template_idx++;
        my $name="_T$template_idx";
        $template_file_hash{$template_file} = $name;

        my $cur_source=[];
        my $parent=$def;
        my $code_list;
        if (!$parent->{code_list}) {
            $code_list = [];
            $parent->{code_list}=$code_list;
        }
        else {
            $code_list = $parent->{code_list};
        }
        my $_t = new_code("template", $name);
        push @{$code_list}, $_t;
        $_t->{source}=$cur_source;
        open In, "$template_file" or die "Can't open $template_file: $!\n";
        while(<In>){
            push @$cur_source, $_;
        }
        close In;
        foreach my $l (@$cur_source) {
            if ($l=~/^(\s*)(\$template)\s+(.+)/) {
                my $sp = $1;
                my $t_name = parse_template($def, $3);
                $l = "$sp\$call $t_name\n";
            }
        }
        return $name;
    }

}

sub post_foreachfile {
    my ($def) = @_;
    my $pages=$def->{pages};
    my $pagelist=$def->{pagelist};
    while(my ($name, $p)=each(%$pages)){
        if ($p->{foreachfile}) {
            my $pat_glob=$p->{foreachfile};
            my $pat_regex=$p->{foreachfile};
            my $n;
            $n=$pat_glob=~s/\(\*\)/\*/g;
            $pat_regex=~s/\(\*\)/\(\.\*\)/g;
            my @files=glob($pat_glob);
            foreach my $f (@files) {
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
        if ($k eq "pagename") {
            $page->{_pagename}=$pagename;
        }
        elsif ($k eq "codes") {
            my $codes={};
            while(my ($tk, $tv)=each(%$v)){
                my $tcode={};
                $tcode->{type}=$tv->{type};
                $tcode->{params}=$tv->{params};
                my @source;
                my $tsource=$tv->{source};
                foreach my $l (@$tsource) {
                    push @source, dupe_line($l, $n, @pat_list);
                }
                $tcode->{source}=\@source;
                $codes->{$tk}=$tcode;
            }
            $page->{codes}=$codes;
        }
        elsif ($k ne "foreachfile") {
            $page->{$k}=dupe_line($v);
        }
    }

    my $pages=$def->{pages};
    my $pagelist=$def->{pagelist};
    if ($pages->{$pagename}) {
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
    for (my $i=1; $i<=$n; $i++) {
        my $rep=$pat_list[$i-1];
        $l=~s/\$$i/$rep/g;
    }
    return $l;
}

sub parse_DEBUG {
    my ($t) = @_;
    if (!$debug) {
        $debug={};
    }
    if ($t=~/^(\d+)/) {
        $debug->{def}=1;
        $debug->{n}=$1;
    }
    elsif ($t) {
        $debug->{$t}=1;
    }
    else {
        $debug->{def}=1;
    }
}

sub debug_def {
    my ($def) = @_;
    my $macros = $def->{macros};
    if ($macros && %$macros) {
        print "    " x 0;
        print "macros:\n";
        debug_macros($macros, 0+1);
        undef $def->{macros};
        print "\n";
    }
    my $pagelist=$def->{pagelist};
    if (@$pagelist) {
        print "pagelist: ", join(', ', @$pagelist), "\n";
    }
    undef $def->{pagelist};
    print "\n";
    while (my ($k, $v) = each %{$def->{pages}}) {
        print "page: $k\n";
        print "    [";
        if ($v->{_pagename}) {
            print "_pagename: $v->{_pagename}; ";
            undef $v->{_pagename};
        }
        if ($v->{_frame}) {
            print "_frame: $v->{_frame}; ";
            undef $v->{_pagename};
        }
        if ($v->{module}) {
            print "module: $v->{module}; ";
            undef $v->{_pagename};
        }
        print "]\n";
        my $codes = $v->{codes};
        if ($codes && %$codes) {
            foreach my $k (sort keys %$codes) {
                my $v = $codes->{$k};
                debug_code($v, 1, 1);
            }
        }
        undef $v->{codes};
        print "\n";
        my $macros = $v->{macros};
        if ($macros && %$macros) {
            print "    " x 1;
            print "macros:\n";
            debug_macros($macros, 1+1);
            undef $def->{macros};
            print "\n";
        }
    }
    undef $def->{pages};
    print "\n";
    my $codes = $def->{codes};
    if ($codes && %$codes) {
        foreach my $k (sort keys %$codes) {
            my $v = $codes->{$k};
            debug_code($v, 0, 1);
        }
    }
    undef $def->{codes};
    print "\n";
    print_def_node($def, 0);
}

sub debug_code {
    my ($code, $indent, $skip_source) = @_;
    print "    " x $indent;
    print "$code->{type}code $code->{name}: ";
    my $params = $code->{params};
    if ($params && @$params) {
        print join(', ', @$params), " - ";
    }
    my $src = $code->{source};
    if ($skip_source) {
        my $n = @$src;
        print "$n lines\n";
    }
    else {
        print "\n";
        foreach my $l (@$src) {
            print "    " x ($indent+1);
            print "$l\n";
        }
    }
    if ($code->{codes}) {
        foreach my $k (sort keys %{$code->{codes}}) {
            my $v = $code->{codes}->{$k};
            debug_code($v, $indent+1, $skip_source);
        }
    }
    if ($code->{macros}) {
        debug_macros($code->{macros}, $indent+1);
    }
}

sub debug_macros {
    my ($macros, $indent) = @_;
    if (%$macros) {
        foreach my $k (sort keys %$macros) {
            my $v = $macros->{$k};
            print "    " x $indent;
            print "$k: $v\n";
        }
    }
}

sub print_def_node {
    my ($node, $indent, $continue) = @_;
    if (ref($node) eq "HASH") {
        if ($continue) {
            print "\n";
        }
        foreach my $k (sort keys %$node) {
            my $v = $node->{$k};
            if ($v) {
                print "    "x$indent;
                print "$k: ";
                print_def_node($v, $indent+1, 1);
            }
        }
    }
    elsif (ref($node) eq "ARRAY") {
        my $n = @$node;
        my $m = $debug->{n};
        if (!$m) {
            $m = 3;
        }
        elsif ($m>$n) {
            $m = $n;
        }
        if ($continue) {
            print "$n elements\n";
        }
        for (my $i = 0; $i<$m; $i++) {
            if ($i<$n) {
                print_def_node($node->[$i], $indent+1);
            }
        }
        if ($n>$m) {
            print_def_node("...", $indent+1);
        }
    }
    else {
        if (!$continue) {
            print "    "x$indent;
        }
        print $node, "\n";
    }
}

sub add_path {
    my ($dir) = @_;
    if (!$dir) {
        return;
    }

    my $deflib=$ENV{MYDEFLIB};
    my $defsrc=$ENV{MYDEFSRC};

    if ($dir=~/\$\(MYDEFSRC\)/) {
        if (!$defsrc) {
            die "MYDEFSRC not defined (in environment)!\n";
        }
        $dir=~s/\$\(MYDEFSRC\)/$defsrc/g;
    }

    my @tlist = split /:/, $dir;
    foreach my $t (@tlist) {
        $t=~s/\/$//;
        if ($t and !$path{$t}) {
            if (-d $t) {
                $path{$t}=1;
                push @path, $t;
            }
            else {
                warn "add_path: [$t] not a directory\n";
            }
        }
    }
}

sub find_file {
    my ($file) = @_;
    my $nowarn;
    if ($file=~/^(\S+)\?/) {
        $file=$1;
        $nowarn = 1;
    }

    if (-f $file) {
        return $file;
    }

    if (@path) {
        foreach my $dir (@path) {
            if (-f "$dir/$file") {
                return "$dir/$file";
            }
        }
    }
    if (!$nowarn) {
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
    foreach my $l (@$llist) {
        if ($l=~/^(\d)+:(.*)/) {
            my ($i, $l)=($1, $2);
            if ($l=~/^NOOP/) {
                next;
            }
            if ($i>$cur_i) {
                push @ogdl_stack, $cur_item;
                $cur_item={"_list"=>[]};
                if ($last_item_type eq "array") {
                    $cur_item->{"_name"}=$last_item->[-1];
                    $last_item->[-1]=$cur_item;
                }
                elsif ($last_item_type eq "hash") {
                    $cur_item->{"_name"}=$last_item->{$last_item_key};
                    $last_item->{$last_item_key}=$cur_item;
                }
                $cur_i=$i;
            }
            elsif ($i<$cur_i) {
                while($i<$cur_i){
                    $cur_item=pop @ogdl_stack;
                    $cur_i--;
                }
            }

            if ($cur_item) {
                if ($l=~/(^\S+?):\s*(.+)/) {
                    my ($k, $v)=($1, $2);
                        $cur_item->{$k}=$v;
                        $last_item=$cur_item;
                        $last_item_type="hash";
                        $last_item_key=$k;
                }
                elsif ($l=~/(^\S+):\s*$/) {
                    my $k=$1;
                    $cur_item->{$k}="";
                    $last_item=$cur_item;
                    $last_item_type="hash";
                    $last_item_key=$k;
                }
                else {
                    my @t;
                    if ($l !~/\(/) {
                        @t=split /,\s*/, $l;
                    }
                    else {
                        push @t, $l;
                    }
                    foreach my $t (@t) {
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
    if (ref($ogdl) eq "HASH") {
        if ($ogdl->{_name} ne "_") {
            print "    "x$indent, $ogdl->{_name}, "\n";
            $indent++;
        }
        while(my ($k, $v) = each %$ogdl){
            if ($k!~/^_(list|name)/) {
                print "    "x$indent, $k, ":\n";
                print_ogdl($v, $indent+1);
            }
        }
        foreach my $v (@{$ogdl->{_list}}) {
            print_ogdl($v, $indent);
        }
    }
    else {
        print "    "x$indent, $ogdl, "\n";
    }
}

sub get_indent {
    my ($s) = @_;
    my $i=get_indent_spaces($s);
    if ($i==$indent_stack[-1]) {
    }
    elsif ($i>$indent_stack[-1]) {
        push @indent_stack, $i;
    }
    else {
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
    for (my $i = 0; $i<$n; $i++) {
        if (substr($t, $i, 1) eq ' ') {
            $count++;
        }
        elsif (substr($t, $i, 1) eq "\t") {
            $count=($count/8+1)*8;
        }
        else {
            return $count;
        }
    }
    return $count;
}

1;
