use strict;
package MyDef::dumpout;
use MyDef::compileutil;
my @func_list;
my $func_index=-1;
sub init_funclist {
    @func_list=();
    $func_index=-1;
}
sub add_function {
    my ($func)=@_;
    $func_index++;
    $func_list[$func_index]=$func;
    return $func_index;
}
sub get_function {
    my ($fidx)=@_;
    return $func_list[$fidx];
}
sub get_func_list {
    return \@func_list;
}
sub get_func_index {
    return $func_index;
}
sub get_cur_func {
    return $func_list[$func_index];
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
    my @openblock;
    my @closeblock;
    my @preblock;
    my @postblock;
    my $blockstack=0;
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
        elsif($l =~ /^DUMP_STUB\s+(\S+)/){
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
        elsif($l=~/^\s*NEW_BLOCK/){
            push @openblock, [];
            push @preblock, [];
            push @postblock, [];
            push @closeblock, [];
            $blockstack=1;
        }
        elsif($l=~/^\s*(PRE|POST|OPEN|CLOSE)_BLOCK\s+(.*)/){
            my $t;
            if($1 eq "OPEN"){
                $t=$openblock[-1];
            }
            elsif($1 eq "CLOSE"){
                $t=$closeblock[-1];
            }
            elsif($1 eq "PRE"){
                $t=$preblock[-1];
            }
            elsif($1 eq "POST"){
                $t=$postblock[-1];
            }
            if($t){
                push @$t, $2;
            }
            $blockstack=1;
        }
        elsif($l=~/^\s*SOURCE_INDENT/){
            if($blockstack==0){
                push @openblock, [];
                push @closeblock, [];
                push @preblock, [];
                push @postblock, [];
            }
            push @source_stack, $out;
            push @source_stack, pop(@preblock);
            $out=pop(@openblock);
            push @$out, "INDENT";
        }
        elsif($l=~/^\s*SOURCE_DEDENT/){
            push @source_stack, $out;
            push @source_stack, pop(@closeblock);
            $out=pop(@postblock);
            push @$out, "DEDENT";
        }
        elsif($l=~/^\s*BLOCK_(\d+)/){
            push @source_stack, $out;
            $out=MyDef::compileutil::fetch_output($1);
        }
        elsif($l=~/^\s*OPEN_FUNC_(\d+)/){
            my $func=$func_list[$1];
            push @openblock, $func->{openblock};
            push @closeblock, $func->{closeblock};
            push @preblock, $func->{preblock};
            push @postblock, $func->{postblock};
            $blockstack=1;
        }
        elsif($l=~/^SUBBLOCK (BEGIN|END)/){
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
        if($blockstack==1){
            $blockstack=2;
        }
        else{
            $blockstack=0;
        }
    }
}
1;
