use strict;
package MyDef::output_make;
use MyDef::dumpout;
use MyDef::utils;
our $debug;
our $mode;
our $page;
our $out;
sub get_interface {
    my $interface_type="general";
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout, $interface_type);
}
sub init_page {
    ($page)=@_;
    my $ext="$(ext)";
    if($MyDef::var->{filetype}){
        $ext=$MyDef::var->{filetype};
    }
    if($page->{type}){
        $ext=$page->{type};
    }
    $page->{pageext}=$ext;
    my $init_mode=$page->{init_mode};
    return ($ext, $init_mode);
}
sub set_output {
    $out = shift;
}
sub modeswitch {
    my ($mode, $in)=@_;
}
sub parsecode {
    my $l=shift;
    if($debug eq "parse"){
        my $yellow="\033[33;1m";
        my $normal="\033[0m";
        print "$yellow parsecode: [$l]$normal\n";
    }
    if($l=~/^DEBUG (\w+)/){
        if($1 eq "OFF"){
            $debug=0;
        }
        else{
            $debug=$1;
        }
        return;
    }
    elsif($l=~/^\$eval\s+(\w+)(.*)/){
        my ($codename, $param)=($1, $2);
        $param=~s/^\s*,\s*//;
        my $t=MyDef::compileutil::eval_sub($codename);
        eval $t;
        if($@){
            print "Error [$l]: $@\n";
            print "  $t\n";
        }
        return;
    }
    if($l=~/^\s*PRINT (.*)/){
        push @$out, $1;
        return 0;
    }
    elsif($l=~/^\s*\$(\w+)\s*(.*)$/){
        my ($func, $param)=($1, $2);
        if($func=~/^(ifeq|ifneq|ifdef|ifndef)(_?)$/){
            push @$out, "$1 $param";
            push @$out, "BLOCK";
            if($2 eq "_"){
                push @$out, "endif";
            }
            push @$out, "endif";
            return "NEWBLOCK";
        }
        elsif($func=~/^el(ifeq|ifneq|ifdef|ifndef)(_?)$/){
            push @$out, "else $1 $param";
            push @$out, "BLOCK";
            if($2 eq "_"){
                push @$out, "endif";
            }
            return "NEWBLOCK";
        }
        elsif($func=~/^else$/){
            push @$out, "else";
            push @$out, "BLOCK";
            push @$out, "endif";
            return "NEWBLOCK";
        }
    }
    push @$out, $l;
    return 0;
}
sub dumpout {
    my ($f, $out, $pagetype)=@_;
    my $dump={out=>$out,f=>$f};
    MyDef::dumpout::dumpout($dump);
}
sub single_block {
    my ($t1, $t2)=@_;
    push @$out, "$t1";
    push @$out, "INDENT";
    push @$out, "BLOCK";
    push @$out, "DEDENT";
    push @$out, "$t2";
    return "NEWBLOCK";
}
sub single_block_pre_post {
    my ($pre, $post)=@_;
    if($pre){
        push @$out, @$pre;
    }
    push @$out, "BLOCK";
    if($post){
        push @$out, @$post;
    }
    return "NEWBLOCK";
}
1;
