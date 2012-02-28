use MyDef::dumpout;
package MyDef::output_perl;
my $debug;
sub get_interface {
    return (\&init_page, \&parsecode, \&modeswitch, \&dumpout);
}
sub init_page {
    my ($page)=@_;
    my $ext="pl";
    if($page->{type}){
        $ext=$page->{type};
    }
    return ($ext, "sub");
}
sub modeswitch {
    my ($pmode, $mode, $out)=@_;
    if($mode=~/(\w+)-(.*)/){
        my $fname=$1;
        my $t=$2;
        my $openblock=[];
        my $closeblock=[];
        my $preblock=[];
        my $postblock=[];
        my $func={openblock=>$openblock, closeblock=>$closeblock, preblock=>$preblock, postblock=>$postblock};
        push @$openblock, "sub $fname {";
        if($t){
            push @$preblock, "my ($t)=\@_;";
        }
        push @$closeblock, "}";
        my $fidx=MyDef::dumpout::add_function($func);
        push @$out, "OPEN_FUNC_$fidx";
    }
}
sub parsecode {
    my ($l, $mode, $out)=@_;
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
    }
    if($l=~/^\s*\$(\w+)\s*(.*)$/){
        my $func=$1;
        my $param=$2;
        if($func =~ /^(if|while)$/){
            return single_block("$1($param)", $out);
        }
        elsif($func =~ /^(el|els|else)if$/){
            return single_block("elsif($param)", $out);
        }
        elsif($func eq "else"){
            return single_block("else", $out);
        }
        elsif($func eq "sub"){
            return single_block("sub $param ", $out);
        }
        elsif($func eq "for" or $func eq "foreach"){
            if($param=~/(\$\w+)=(.*?):(.*?)(:.*)?$/){
                my ($var, $i0, $i1, $step)=($1, $2, $3, $4);
                my $stepclause;
                if($step){
                    my $t=substr($step, 1);
                    if($t eq "-1"){
                        $stepclause="my $var=$i0;$var>$i1;$var--";
                    }
                    elsif($t=~/^-/){
                        $stepclause="my $var=$i0;$var>$i1;$var=$var$t";
                    }
                    else{
                        $stepclause="my $var=$i0;$var<$i1;$var+=$t";
                    }
                }
                else{
                    $stepclause="my $var=$i0;$var<$i1;$var++";
                }
                return single_block("for($stepclause)", $out);
            }
            elsif($param=~/(\$\w+) in (.*)/){
                my ($var, $list)=($1, $2);
                return single_block("foreach my $var ($list)", $out);
            }
        }
        else{
            check_termination(\$l);
            push @$out, $l;
        }
    }
    else{
        check_termination(\$l);
        push @$out, $l;
    }
    return 0;
}
sub dumpout {
    my ($f, $out)=@_;
    my $dump={out=>$out,f=>$f};
    my $pagetype=$MyDef::page->{type};
    if(!defined $pagetype or $pagetype eq "pl"){
        push @$f, "#!/usr/bin/perl\n";
    }
    MyDef::dumpout::dumpout($dump);
}
sub single_block {
    my ($t, $out)=@_;
    push @$out, "$t\{";
    push @$out, "INDENT";
    push @$out, "BLOCK";
    push @$out, "DEDENT";
    push @$out, "}";
    return "NEWBLOCK";
}
sub check_termination {
    my $l=shift;
    if($$l=~/^\s*$/){
    }
    elsif($$l=~/(for|while|if|else if)\s*\(.*\)\s*$/){
    }
    elsif($$l=~/^\s*}/){
    }
    elsif($$l!~/[,:\(\[\{;]\s*$/){
        $$l.=";";
    }
    else{
    }
}
1;
