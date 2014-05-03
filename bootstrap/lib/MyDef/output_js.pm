use strict;
package output_js;
use MyDef::dumpout;
our $debug;
our $mode;
our $page;
our $out;
sub get_interface {
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout);
}
sub init_page {
    ($page)=@_;
    my $ext="js";
    if($page->{type}){
        $ext=$page->{type};
    }
    $page->{pageext}=$ext;
    return ($ext, "sub");
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
    elsif($l=~/^NOOP/){
        return;
    }
    push @$out, $l;
}
sub dumpout {
    my $f;
    ($f, $out)=@_;
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
        foreach my $l (@$pre){
            push @$out, $l;
        }
    }
    push @$out, "BLOCK";
    if($post){
        foreach my $l (@$post){
            push @$out, $l;
        }
    }
    return "NEWBLOCK";
}
1;
