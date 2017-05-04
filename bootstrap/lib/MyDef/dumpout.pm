use strict;
package MyDef::dumpout;
sub dumpout {
    my $dump=shift;
    my $f=$dump->{f};
    my $out=$dump->{out};
    my $custom=$dump->{custom};
    if(!$out){
        die "missing \$out\n";
    }
    my @source_stack;
    my $indentation=0;
    my @indentation_stack;
    my @make_string_stack;
    my $string_list=undef;
    while(1){
        if(!@$out){
            $out=pop @source_stack;
            if(!$out){
                last;
            }
            else{
                next;
            }
        }
        my $l=shift @$out;
        if($custom and $custom->($f, \$l)){
        }
        elsif($l =~/^INCLUDE_BLOCK (\S+)/){
            push @source_stack, $out;
            $out=$dump->{$1};
        }
        elsif($l =~ /^DUMP_STUB\s+([\w-]+)/){
            my $source=$MyDef::compileutil::named_blocks{$1};
            if($source){
                push @source_stack, $out;
                $out=$source;
            }
        }
        elsif($l =~ /^DUMP_PERL\s+(\w+)/){
            my $t = MyDef::compileutil::eval_sub($1);
            my $source = eval($t);
            if($@){
                print "eval error: [$@]\n";
            }
            if($source){
                push @source_stack, $out;
                $out=$source;
            }
        }
        elsif($l=~/^\s*(INDENT|DEDENT|PUSHDENT|POPDENT)\b(.*)/){
            if($1 eq "INDENT"){
                $indentation++;
            }
            elsif($1 eq "DEDENT"){
                $indentation-- if $indentation;
            }
            elsif($1 eq "PUSHDENT"){
                push @indentation_stack, $indentation;
                $indentation=0;
            }
            elsif($1 eq "POPDENT"){
                $indentation=pop @indentation_stack;
            }
            $l=$2;
            if($l=~/^\s*;?$/){
                next;
            }
            else{
                unshift @$out, $l;
                next;
            }
        }
        elsif($l=~/^\s*SOURCE_INDENT/){
            $indentation++;
        }
        elsif($l=~/^\s*SOURCE_DEDENT/){
            $indentation-- if $indentation;
        }
        elsif($l=~/^\s*BLOCK_(\d+)/){
            push @source_stack, $out;
            $out=MyDef::compileutil::fetch_output($1);
        }
        elsif($l=~/^SUBBLOCK (BEGIN|END)/){
        }
        elsif($l=~/^NOOP/){
        }
        elsif($l=~/^MAKE_STRING:(.*)/){
            $string_list=[];
            push @make_string_stack, {quote=>'"', join=>'\n', line=>$1, list=>$string_list, indent=>$indentation};
        }
        elsif($l =~/^POP_STRING/){
            my $h=pop @make_string_stack;
            if(!$h){
                die "Error POP_STRING\n";
            }
            if(@make_string_stack){
                $string_list=$make_string_stack[-1]->{list};
            }
            else{
                $string_list=undef;
            }
            my $l=$h->{line};
            my $join='';
            if($l=~/\bSTRING\[([^\]]*)\]/){
                $join=$1;
                $l=~s/\bSTRING\[[^\]]*\]/STRING/g;
            }
            my $t=join($join, @{$h->{list}});
            if($l=~/"STRING"/){
                $t=~s/"/\\"/g;
            }
            $l=~s/\bSTRING\b/$t/;
            if($l=~/^\s*$/){
                push @$f, "\n";
            }
            elsif($l=~/^\s*NEWLINE\b/){
                push @$f, "\n";
            }
            else{
                chomp $l;
                push @$f, "    "x$indentation."$l\n";
            }
        }
        elsif(@make_string_stack){
            if($l=~/^\s*$/){
            }
            elsif($l=~/^\s*NEWLINE\b/){
                push @$string_list, "";
            }
            else{
                push @$string_list, "    "x($indentation-$make_string_stack[-1]->{indent}-1) . $l;
            }
        }
        else{
            if($l=~/^\s*$/){
                push @$f, "\n";
            }
            elsif($l=~/^\s*NEWLINE\b/){
                push @$f, "\n";
            }
            else{
                chomp $l;
                push @$f, "    "x$indentation."$l\n";
            }
        }
    }
}
1;
