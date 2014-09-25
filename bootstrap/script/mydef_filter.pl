#!/usr/bin/perl
use strict;
sub getindentspaces {
    my ($t)=@_;
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
my $pre_indent;
my $indent=0;
my $incode;
my $base_count;
while(<STDIN>){
    if(/^\s*$/){
        print $_;
        next;
    }
    if($incode){
        if(getindentspaces($_)<$base_count){
            $incode=0;
        }
    }
    if(!$incode){
        if(/^(\s*)subcode:/){
            $incode=1;
            $base_count=getindentspaces($1);
            $pre_indent=' ' x $base_count;
            $indent=1;
        }
        print $_;
    }
    else{
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
            my $t="$space$1";
            $t=~s/;\s*$//;
            print "$t\n";
        }
    }
}
