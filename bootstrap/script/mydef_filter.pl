#!/usr/bin/perl
use strict;
my $pre_indent;
my $indent=0;
while(<STDIN>){
    if(!defined $pre_indent){
        if(/^(\s*)/){
            my $space=$1;
            $pre_indent=$space;
        }
    }
    my $space=$pre_indent . "    " x $indent;
    if(/^\s*(foreach)\s*(.*)\((.*)\)\s*\{\s*$/){
        my ($tag, $var, $cond)=($1, $2, $3);
        $var=~s/^my\s*//;
        $var=~s/\s*$//;
        print "$space\$foreach $var in $cond\n";
        $indent++;
    }
    elsif(/^\s*(\w+)\s*\((.*)\)\s*\{\s*$/){
        my ($tag, $cond)=($1, $2);
        print "$space\$$tag $cond\n";
        $indent++;
    }
    elsif(/^\s*else\s*\{\s*$/){
        print "$space\$else\n";
        $indent++;
    }
    elsif(/^\s*(sub)\s*(\w+)\s*\{\s*$/){
        my ($tag, $subname)=($1, $2);
        print "$space\$sub $subname\n";
        $indent++;
    }
    elsif(/^\s*(\w+)\s*\((.*)\)\s*\{\s*(.*)\s*\}\s*$/){
        my ($tag, $cond, $code)=($1, $2, $3);
        print "$space\$$tag $cond\n";
        print "$space    $code\n";
    }
    elsif(/^\s*else\s*\{\s*(.*)\s*\}\s*$/){
        my $code=$1;
        print "$space\$else\n";
        print "$space    $code\n";
    }
    elsif(/^\s*\}/){
        $indent--;
    }
    elsif(/^\s*(.*)/){
        print "$space$1\n";
    }
}
