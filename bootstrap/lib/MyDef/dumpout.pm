use strict;
package MyDef::dumpout;
our $time_start = time();

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
        elsif($l =~ /^DUMP_STUB\s+(\w+)/){
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
        elsif($l =~/^(.*)=\s*\[(strings?)_from_file:\s*(\S+)\]\s*;/){
            my ($head, $file, $type)=($1, $3, $2);
            if($dump->{module} eq "output_perl"){
                push @$f, "$head = <<HERE;\n";
                open In, "$file" or die "Can't open $file.\n";
                while(<In>){
                    push @$f, $_;
                }
                close In;
                push @$f, "HERE\n";
            }
            elsif($head=~/^\$/ and $dump->{module} eq "output_www"){
                push @$f, "$head = <<<HERE\n";
                open In, "$file" or die "Can't open $file.\n";
                while(<In>){
                    push @$f, $_;
                }
                close In;
                push @$f, "HERE;\n";
            }
            else{
                my @t;
                open In, "$file" or die "Can't open $file.\n";
                while(<In>){
                    chomp;
                    s/\\/\\\\/g;
                    s/"/\\"/g;
                    push @t, $_;
                }
                close In;
                push @$f, "    "x$indentation;
                push @$f, "$head = ";
                if($type eq "string"){
                    push @$f, '"';
                    foreach my $t (@t){
                        push @$f, "$t\\\n";
                    }
                    push @$f, "\";\n";
                }
                elsif($type eq "strings"){
                    my $indent="    " x ($indentation+1);
                    push @$f, "[\n";
                    foreach my $t (@t){
                        push @$f, "$indent\"$t\",\n";
                    }
                    push @$f, "$indent];\n";
                }
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
