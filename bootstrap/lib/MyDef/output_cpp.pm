use strict;
use MyDef::output_c;

package MyDef::output_cpp;
our $out;
our $debug;

sub get_interface {
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout);
}
sub set_output {
    my ($newout)=@_;
    $out = $newout;
    MyDef::output_c::set_output($newout);
}
sub modeswitch {
    my ($mode, $in)=@_;
}
sub init_page {
    my ($page)=@_;
    if(!$page->{type}){
        $page->{type}="cpp";
    }
    MyDef::output_c::init_page(@_);
    return $page->{init_mode};
}
sub parsecode {
    my ($l)=@_;
    if($l=~/^DEBUG (\w+)/){
        if($1 eq "OFF"){
            $debug=0;
        }
        else{
            $debug=$1;
        }
        return MyDef::output_c::parsecode($l);
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
    return MyDef::output_c::parsecode($l);
}
sub dumpout {
    my ($f, $out)=@_;
    my $cnt=0;
    my $cnt_std=0;
    foreach my $k (sort {$b cmp $a} keys(%MyDef::output_c::includes)){
        if($k=~/<(iostream|string|bitset|deque|list|map|queue|set|stack|vector)>/){
            push @$f, "#include <$1>\n";
            $cnt_std++;
        }
        elsif($k=~/<(stdio|stdlib|string|math|time|errno)\.h>/){
            push @$f, "#include <c$1>\n";
        }
        else{
            push @$f, "#include $k\n";
        }
        $cnt++;
    }
    if($cnt>0){
        if($cnt_std>0){
            push @$f, "using namespace std;\n";
        }
        push @$f, "\n";
    }
    %MyDef::output_c::includes=();
    my @class_dump;
    $MyDef::output_c::dump_classes=\@class_dump;
    foreach my $name (@MyDef::output_c::struct_list){
        push @class_dump, "struct $name {\n";
        my $s_list=$MyDef::output_c::structs{$name}->{list};
        my $s_hash=$MyDef::output_c::structs{$name}->{hash};
        my $i=0;
        foreach my $p (@$s_list){
            $i++;
            if($s_hash->{$p} eq "function"){
                push @class_dump, "\t".$MyDef::output_c::fntype{$p}.";\n";
            }
            else{
                push @class_dump, "\t$s_hash->{$p} $p;\n";
            }
        }
        my ($param, $init)=MyDef::output_c::get_struct_constructor($name);
        if(defined $init){
            my $param_line=join(", ", @$param);
            my @init_list;
            foreach my $a (@$init){
                if($a=~/(\w+)=(.*)/){
                    push @init_list, "$1($2)";
                }
            }
            my $init_line=join(", ", @init_list);
            push @class_dump, "\t$name($param_line) : $init_line {}\n";
        }
        my $s_exit=$s_hash->{"-exit"};
        if($s_exit and @$s_exit){
            push @class_dump, "\t~$name(){\n";
            foreach my $l (@$s_exit){
                push @class_dump, "\t    $l\n";
            }
            push @class_dump, "\t}\n";
        }
        push @class_dump, "};\n\n";
    }
    @MyDef::output_c::struct_list=();
    MyDef::output_c::dumpout($f, $out);
}
1;
