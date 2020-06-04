use strict;
package MyDef::dumpout;

sub dumpout {
    my $dump=shift;
    my $f=$dump->{f};
    my $out=$dump->{out};
    my $custom=$dump->{custom};
    if (!$out) {
        die "missing \$out\n";
    }
    my @source_stack;

    my $indentation=0;
    my @indentation_stack;

    while(1){
        if (!@$out) {
            $out=pop @source_stack;
            if (!$out) {
                last;
            }
            else {
                next;
            }
        }

        my $l=shift @$out;
        if ($l=~/^\s*\\x[0-9a-f]+\b/) {
            $l=~s/\\x([0-9a-f]+)\b/chr(hex($1))/ie;
        }
        if ($l =~/^INCLUDE_FILE (\S+)/) {
            open In, "$1" or die "Can't open $1: $!\n";
            while(<In>){
                push @$f, $_;
            }
            close In;
            next;
        }
        elsif ($l =~/^INCLUDE_BLOCK (\S+)/) {
            push @source_stack, $out;
            $out=$dump->{$1};
        }
        elsif ($l =~ /^DUMP_STUB\s+([\w\-]+)/) {
            my $source=$MyDef::compileutil::named_blocks{$1};
            if ($source) {
                push @source_stack, $out;
                $out=$source;
            }
        }
        elsif ($l =~ /^INSERT_STUB\[(.*)\]\s+([\w\-]+)/) {
            my ($sep, $name) = ($1, $2);
            my $source=$MyDef::compileutil::named_blocks{$name};
            if ($source) {
                my $i=$#$f;
                while ($i>=0 && $f->[$i]!~/\{STUB\}/) {
                    $i--;
                }
                if ($i>=0) {
                    my $t = join ($sep, @$source);
                    $f->[$i]=~s/\{STUB\}/$t/g;
                }
            }
        }
        elsif ($l=~/^(INDENT|DEDENT|PUSHDENT|POPDENT)\b(.*)/) {
            if ($1 eq "INDENT") {
                $indentation++;
            }
            elsif ($1 eq "DEDENT") {
                $indentation-- if $indentation;
            }
            elsif ($1 eq "PUSHDENT") {
                push @indentation_stack, $indentation;
                $indentation=0;
            }
            elsif ($1 eq "POPDENT") {
                $indentation=pop @indentation_stack;
            }

            $l=$2;
            if ($l=~/^\s*;?$/) {
                next;
            }
            else {
                unshift @$out, $l;
                next;
            }
        }
        elsif ($l=~/^SOURCE_INDENT/) {
            $indentation++;
        }
        elsif ($l=~/^SOURCE_DEDENT/) {
            $indentation-- if $indentation;
        }
        elsif ($l=~/^BLOCK_(\d+)/) {
            push @source_stack, $out;
            $out=MyDef::compileutil::fetch_output($1);
        }
        elsif ($l=~/^SUBBLOCK (BEGIN|END)/) {
        }
        elsif ($l=~/^NOOP/) {
        }
        else {
            if ($l=~/^\s*(NEWLINE\b.*)?$/) {
                if ($1 eq "NEWLINE?") {
                    if ($f->[-1] ne "\n") {
                        push @$f, "\n";
                    }
                }
                elsif ($1) {
                    push @$f, "\n";
                }
                else {
                    push @$f, $l;
                }
            }
            elsif ($l=~/^<-\|(.*)/) {
                push @$f, "$1\n";
            }
            else {
                chomp $l;
                push @$f, "    "x$indentation."$l\n";
            }
        }
    }
}

1;

1;
