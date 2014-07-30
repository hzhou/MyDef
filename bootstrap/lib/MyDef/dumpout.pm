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
    while(1){
        my $l;
        if(@$out){
            $l=shift @$out;
        }
        else{
            $out=pop @source_stack;
            if(!$out){
                last;
            }
            else{
                next;
            }
        }
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
        else{
            if($l=~/^\s*$/){
                push @$f, "\n";
            }
            elsif($l=~/^\s*NEWLINE\b/){
                push @$f, "\n";
            }
            elsif($l =~/^PRINT (.*)/){
                push @$f, "    "x$indentation;
                push @$f, "$1\n";
            }
            else{
                push @$f, "    "x$indentation;
                push @$f, $l;
                if($l!~ /\n$/){
                    push @$f, "\n";
                }
            }
        }
    }
}
1;
