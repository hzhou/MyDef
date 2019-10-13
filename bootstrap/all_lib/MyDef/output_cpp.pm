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
    my ($t_page)=@_;
    my $page=$t_page;
    MyDef::set_page_extension("cpp");


    my $init_mode = MyDef::output_c::init_page(@_);
    $MyDef::output_c::page->{has_bool} = "bool";
    return $init_mode;
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
    if($l=~/^(\/\/.*)/){
        push @$out, $1;
        return;
    }
    elsif($l=~/^\$foreach\s+(.+?)\s+in\s+(.+)/){
        my ($v, $list) = ($1, $2);
        if($v=~/^&?\w+$/){
            $v = "auto $v";
        }
        return MyDef::output_c::single_block("for($v : $list){", "}", "foreach");
    }
    elsif($l=~/^(?:std::)?c(out|in|err|log)\b/){
        MyDef::output_c::add_include_direct("<iostream>");
    }

    elsif($l=~/^\$my\s+(.*)/){
        my ($t) = ($1);
        if($t=~/\w+\s*=\s*(\w+)\(.*\)/){
            if($MyDef::output_c::function_autolist{$1}){
                if(!$MyDef::output_c::list_function_hash{$1}){
                    $MyDef::output_c::list_function_hash{$1}=1;
                    push @MyDef::output_c::list_function_list, $1;
                }
            }
        }
        $t=~s/\s+$//;
        if($t=~/^(\w+)\s*=\s*new\s+(\w+)(.*)/){
            my ($v, $T, $t) = ($1, $2, $3);
            MyDef::output_c::func_add_symbol($v, "$T*");
            push @$out, "auto $v = new $T$t;";
            return;
        }
        elsif($t=~/^(\w+)\s*=\s*make_(unique|shared)(.*)/){
            my ($v, $attr, $t) = ($1, $2, $3);
            MyDef::output_c::add_include_direct("<memory>");
            my ($type, $T, $new);
            if($t=~/^<(.*)>(.*)/){
                ($type, $T, $new)=("$1*", $1, $2);
                if($T=~/(.*?)\[.*\]/){
                    $type = "$1*";
                }
                if($new=~/^\((.*)\)/){
                    $new = $1;
                }
            }
            else{
                $t=~s/^\s+//;
                if($t=~/(.*?)\[(.*)\]/){
                    ($type, $T, $new) = ("$1*", $1."[]", $2);
                }
                else{
                    ($type, $T, $new) = ("$t*", $t, undef);
                }
            }
            MyDef::output_c::func_add_symbol($v, $type);
            if($T=~/^(.*)\[\]$/){
                push @$out, "std::${attr}_ptr<$T> $v {new $1\[$new]};";
            }
            else{
                push @$out, "std::${attr}_ptr<$T> $v {new $T($new)};";
            }
            return;
        }
        else{
            my @vlist;
            if($t=~/[({<'"]/){
                if($t=~/^(.*\w+)\s*([({].*[)}])$/){
                    push @vlist, "$1 = $2";
                }
                else{
                    push @vlist, $t;
                }
            }
            else{
                @vlist = MyDef::output_c::split_var_line($t);
            }
            foreach my $v (@vlist){
                MyDef::output_c::my_add_var($v);
            }
            return;
        }
    }
    elsif($l=~/^\$dump\s+(.*)/){
        my ($t) = ($1);
        MyDef::output_c::add_include_direct("<iostream>");
        my @tlist;
        foreach my $v (split /,\s*/, $t){
            push @tlist, "<<\"$v=\"<<$v";
        }
        push @$out, "std::cout".join('<<", "', @tlist)."<<'\\n';";
        return;
    }
    return MyDef::output_c::parsecode($l);
}

sub dumpout {
    my ($f, $out)=@_;
    foreach my $type (keys %MyDef::output_c::all_types){
        if($type=~/(?:std::)?(string|bitset|deque|list|(unordered_)?(map|set)|queue|set|stack|vector)\b/){
            MyDef::output_c::add_include_direct("<$1>");
        }
    }
    my @tlist;
    foreach my $k (sort {$b cmp $a} (@MyDef::output_c::include_list)){
        if($k=~/<(std(io|lib|def|int|arg)|string|math|time|type|limits|signal|errno|assert)\.h>/){
            push @tlist, "<c$1>";
        }
        else{
            push @tlist, $k;
        }
    }
    if($MyDef::page->{namespace}){
        push @tlist, "using namespace $MyDef::page->{namespace};";
    }

    @MyDef::output_c::include_list=@tlist;
    my @class_dump;
    $MyDef::output_c::dump_classes=\@class_dump;
    foreach my $name (@MyDef::output_c::struct_list){
        push @class_dump, "struct $name {\n";
        my $s_list=$MyDef::output_c::structs{$name}->{list};
        my $s_hash=$MyDef::output_c::structs{$name}->{hash};
        my $i=0;
        foreach my $p (@$s_list){
            $i++;
            my $type = $s_hash->{$p};
            if($type eq "function"){
                push @class_dump, "    ".$MyDef::output_c::fntype{$p}.";\n";
            }
            elsif($type=~/(.+)(\[.*\])/){
                push @class_dump, "    $1 $p$2;\n";
            }
            else{
                push @class_dump, "    $type $p;\n";
            }
        }
        push @class_dump, "};\n\n";
    }

    @MyDef::output_c::struct_list=();

    while (my ($k, $v) = each %MyDef::output_c::functions){
        if($k=~/^operator_(\w+)/){
            my %ops=(Lt=>'<');
            if($ops{$1}){
                $v->{name}="operator".$ops{$1};
            }
        }
    }
    MyDef::output_c::dumpout($f, $out);
}


1;

1;
