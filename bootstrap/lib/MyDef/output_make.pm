use strict;
package MyDef::output_make;
our $debug=0;
our $out;
our $mode;
our $page;

sub get_interface {
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout);
}
sub init_page {
    my ($t_page)=@_;
    $page=$t_page;
    MyDef::set_page_extension("");
    my $init_mode="sub";
    return $init_mode;
}
sub set_output {
    my ($newout)=@_;
    $out = $newout;
}
sub modeswitch {
    my ($mode, $in)=@_;
}
sub parsecode {
    my ($l)=@_;
    if($debug eq "parse"){
        my $yellow="\033[33;1m";
        my $normal="\033[0m";
        print "$yellow parsecode: [$l]$normal\n";
    }
    if($l=~/^\$warn (.*)/){
        my $curfile=MyDef::compileutil::curfile_curline();
        print "[$curfile]\x1b[33m $1\n\x1b[0m";
        return;
    }
    elsif($l=~/^\$template\s+(.*)/){
        my $file = $1;
        if($file !~ /^\.*\//){
            my $dir = MyDef::compileutil::get_macro_word("TemplateDir", 1);
            if($dir){
                $file = "$dir/$file";
            }
        }
        open In, $file or die "Can't open template $file\n";
        my @all=<In>;
        close In;
        foreach my $a (@all){
            push @$out, $a;
        }
        return;
    }
    elsif($l=~/^DEBUG (\w+)/){
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
        if($@ and !$MyDef::compileutil::eval_sub_error{$codename}){
            $MyDef::compileutil::eval_sub_error{$codename}=1;
            print "evalsub - $codename\n";
            print "[$t]\n";
            print "eval error: [$@] package [", __PACKAGE__, "]\n";
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
            my @src;
            push @src, "$1 $param";
            push @src, "BLOCK";
            if($2){
                push @src, "endif";
            }
            MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
            return "NEWBLOCK-if";
        }
        elsif($func=~/^el(ifeq|ifneq|ifdef|ifndef)(_?)$/){
            my @src;
            push @src, "else $1 $param";
            push @src, "BLOCK";
            if($2){
                push @src, "endif";
            }
            MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
            return "NEWBLOCK-if";
        }
        elsif($func=~/^else$/){
            my @src;
            push @src, "else";
            push @src, "BLOCK";
            push @src, "endif";
            MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
            return "NEWBLOCK-else";
        }
    }
    push @$out, $l;
    return 0;
}
sub dumpout {
    my ($f, $out, $pagetype)=@_;
    my $dump={out=>$out,f=>$f, module=>"output_make"};
    MyDef::dumpout::dumpout($dump);
}
sub single_block {
    my ($t1, $t2, $scope)=@_;
    my @src;
    push @src, "$t1";
    push @src, "INDENT";
    push @src, "BLOCK";
    push @src, "DEDENT";
    push @src, "$t2";
    MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
    if($scope){
        return "NEWBLOCK-$scope";
    }
    else{
        return "NEWBLOCK";
    }
}
1;
