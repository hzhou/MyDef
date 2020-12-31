use strict;
use MyDef::output_perl;

package MyDef::output_plot;
our %colornames;
our $out;
our $debug;

sub set_attrs {
    my ($t, $context) = @_;
    my @t = split /,\s+/, $t;
    foreach my $t (@t){
        if($colornames{$t}){
            if($context=~/fill|text/){
                $t = "fill $colornames{$t}";
            }
            else{
                $t = "stroke $colornames{$t}";
            }
        }
        elsif($t=~/^#.+/){
            if($context=~/fill|text/){
                $t = "fill $t";
            }
            else{
                $t = "stroke $t";
            }
        }
        if($t=~/font\s+(.*)/){
            my $t = $1;
            if($t=~/\b([0-9.]+)(pt|px)?/){
                my $size=$1;
                $t = "$` $'";
                push @$out, "MyPlot::set_attr(\"font $t\");";
                $t = "fontsize $size";
            }
        }
        if($t=~/([0-9.]+)(pt|px)/){
            my $size=$1;
            if($context=~/text/){
                $t = "fontsize $size";
            }
            else{
                $t = "linewidth $size";
            }
        }
        elsif($t=~/^(shade|gradient|linear|radial|ball)\s*(.*)/){
            $t = filter_attr_shading($1, $2);
        }
        push @$out, "MyPlot::set_attr(\"$t\");";
    }
}

sub filter_attr_shading {
    my ($type, $s) = @_;
    my @alist = split /\s+/, $s;
    my %a;
    foreach my $a (@alist){
        if($a=~/^(\w+)=(.*)/){
            my $k = lc($1);
            $a{$k}=$2;
        }
        else{
            my $t=parse_color($a);
            if($t){
                my $k;
                foreach my $c ("c0", "c1"){
                    if(!$a{$c}){
                        $k= $c;
                        last;
                    }
                }
                if($k){
                    $a{$k}=$t;
                }
                next;
            }
        }
    }
    if(!$a{c0}){
        $a{c0}='#000000';
    }
    if(!$a{c1}){
        $a{c1}='#ffffff';
    }
    if($type=~/(shade|gradient|linear)/){
        if(!defined $a{theta}){
            $a{theta}=-90;
        }
        if($a{theta}<0){
            $a{theta}=-$a{theta};
            ($a{c0}, $a{c1}) = ($a{c1}, $a{c0});
        }
        my $s = "linear";
        foreach my $k (sort keys %a){
            $s.= " $k=".$a{$k};
        }
        return $s;
    }
    elsif($type=~/(radial|ball)/){
        if($type eq "ball"){
            $a{x0}=-0.45;
            $a{y0}=0.45;
            $a{r0}=0;
            $a{x1}=0;
            $a{y1}=0;
            $a{r1}=1;
            if($a{c1} eq "#ffffff"){
                ($a{c0}, $a{c1}) = ($a{c1}, $a{c0});
            }
        }
        else{
            if(!defined $a{x0}){
                $a{x0} = 0;
            }
            if(!defined $a{y0}){
                $a{y0} = 0;
            }
            if(!defined $a{r0}){
                $a{r0} = 0;
            }
            if(!defined $a{x1}){
                $a{x1} = 0;
            }
            if(!defined $a{y1}){
                $a{y1} = 0;
            }
            if(!defined $a{r1}){
                $a{r1} = 1;
            }
        }
        my $s = "radial";
        foreach my $k (sort keys %a){
            $s.= " $k=".$a{$k};
        }
        return $s;
    }
}

sub parse_color {
    my ($t) = @_;
    if($t=~/^#(\S+)/){
        return get_color_rrggbb($1);
    }
}

sub get_color_rrggbb {
    my ($c) = @_;
    $c = uc($c);
    if(length($c)==1){
        $c = $c x 6;
    }
    elsif(length($c)==2){
        $c = $c x 3;
    }
    elsif(length($c)==3){
        my ($r, $g, $b)=split //, $c;
        $c = "$r$r$g$g$b$b";
    }
    else{
        die "get_color_rrggbb error: [$c]\n";
    }
    return "#".$c;
}

%colornames=(
    black=>"#000000",
    white=>"#ffffff",
    red=>"#ff0000",
    lime=>"#00ff00",
    blue=>"#0000ff",
    cyan=>"#00ffff",
    aqua=>"#00ffff",
    magenta=>"#ff00ff",
    fuchsia=>"#ff00ff",
    yellow=>"#ffff00",
    maroon=>"#800000",
    green=>"#008000",
    navy=>"#000080",
    teal=>"#008080",
    purple=>"#800080",
    olive=>"#808000",
    gray=>"#808080",
    silver=>"#c0c0c0",
    orange=>"#ffa500",
    brown=>"#a52a2a",
    gold=>"#ffd700",
    pink=>"#ffc0cb",
    beige=>"#f5f5dc",
    bisque=>"#ffe4c4",
    ivory=>"#fffff0",
    indigo=>"#4b0082",
    turquoise=>"#40e0d0",
    aliceblue=>"#f0f8ff",
    antiquewhite=>"#faebd7",
    aquamarine=>"#7fffd4",
    azure=>"#f0ffff",
    blanchedalmond=>"#ffebcd",
    blueviolet=>"#8a2be2",
    burlywood=>"#deb887",
    cadetblue=>"#5f9ea0",
    chartreuse=>"#7fff00",
    chocolate=>"#d2691e",
    coral=>"#ff7f50",
    cornflowerblue=>"#6495ed",
    cornsilk=>"#fff8dc",
    crimson=>"#dc143c",
    darkblue=>"#00008b",
    darkcyan=>"#008b8b",
    darkgoldenrod=>"#b8860b",
    darkgray=>"#a9a9a9",
    darkgreen=>"#006400",
    darkkhaki=>"#bdb76b",
    darkmagenta=>"#8b008b",
    darkolivegreen=>"#556b2f",
    darkorange=>"#ff8c00",
    darkorchid=>"#9932cc",
    darkred=>"#8b0000",
    darksalmon=>"#e9967a",
    darkseagreen=>"#8fbc8f",
    darkslateblue=>"#483d8b",
    darkslategray=>"#2f4f4f",
    darkturquoise=>"#00ced1",
    darkviolet=>"#9400d3",
    deeppink=>"#ff1493",
    deepskyblue=>"#00bfff",
    dimgray=>"#696969",
    dodgerblue=>"#1e90ff",
    firebrick=>"#b22222",
    floralwhite=>"#fffaf0",
    forestgreen=>"#228b22",
    gainsboro=>"#dcdcdc",
    ghostwhite=>"#f8f8ff",
    goldenrod=>"#daa520",
    greenyellow=>"#adff2f",
    honeydew=>"#f0fff0",
    hotpink=>"#ff69b4",
    indianred=>"#cd5c5c",
    khaki=>"#f0e68c",
    lavender=>"#e6e6fa",
    lavenderblush=>"#fff0f5",
    lawngreen=>"#7cfc00",
    lemonchiffon=>"#fffacd",
    lightblue=>"#add8e6",
    lightcoral=>"#f08080",
    lightcyan=>"#e0ffff",
    lightgoldenrodyellow=>"#fafad2",
    lightgray=>"#d3d3d3",
    lightgreen=>"#90ee90",
    lightpink=>"#ffb6c1",
    lightsalmon=>"#ffa07a",
    lightseagreen=>"#20b2aa",
    lightskyblue=>"#87cefa",
    lightslategray=>"#778899",
    lightsteelblue=>"#b0c4de",
    lightyellow=>"#ffffe0",
    limegreen=>"#32cd32",
    linen=>"#faf0e6",
    mediumaquamarine=>"#66cdaa",
    mediumblue=>"#0000cd",
    mediumorchid=>"#ba55d3",
    mediumpurple=>"#9370db",
    mediumseagreen=>"#3cb371",
    mediumslateblue=>"#7b68ee",
    mediumspringgreen=>"#00fa9a",
    mediumturquoise=>"#48d1cc",
    mediumvioletred=>"#c71585",
    midnightblue=>"#191970",
    mintcream=>"#f5fffa",
    mistyrose=>"#ffe4e1",
    moccasin=>"#ffe4b5",
    navajowhite=>"#ffdead",
    oldlace=>"#fdf5e6",
    olivedrab=>"#6b8e23",
    orangered=>"#ff4500",
    orchid=>"#da70d6",
    palegoldenrod=>"#eee8aa",
    palegreen=>"#98fb98",
    paleturquoise=>"#afeeee",
    palevioletred=>"#db7093",
    papayawhip=>"#ffefd5",
    peachpuff=>"#ffdab9",
    peru=>"#cd853f",
    plum=>"#dda0dd",
    powderblue=>"#b0e0e6",
    rebeccapurple=>"#663399",
    rosybrown=>"#bc8f8f",
    royalblue=>"#4169e1",
    saddlebrown=>"#8b4513",
    salmon=>"#fa8072",
    sandybrown=>"#f4a460",
    seagreen=>"#2e8b57",
    seashell=>"#fff5ee",
    sienna=>"#a0522d",
    skyblue=>"#87ceeb",
    slateblue=>"#6a5acd",
    slategray=>"#708090",
    snow=>"#fffafa",
    springgreen=>"#00ff7f",
    steelblue=>"#4682b4",
    tan=>"#d2b48c",
    thistle=>"#d8bfd8",
    tomato=>"#ff6347",
    violet=>"#ee82ee",
    wheat=>"#f5deb3",
    whitesmoke=>"#f5f5f5",
    yellowgreen=>"#9acd32",
);
sub get_interface {
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout);
}
sub set_output {
    my ($newout)=@_;
    $out = $newout;
    MyDef::output_perl::set_output($newout);
}
sub modeswitch {
    my ($mode, $in)=@_;
}
sub init_page {
    my ($page)=@_;
    if(!$page->{type}){
        $page->{type}="pl";
    }
    MyDef::output_perl::init_page(@_);
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
        return MyDef::output_perl::parsecode($l);
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
    if($l=~/CALLBACK\s*(\w+)\s*(.*)/){
        my ($func, $param)=($1, $2);
        my $codelist=$MyDef::compileutil::named_blocks{"last_grab"};
        if($func =~/^(path|draw|fill|clip)/){
            if(@$codelist){
                $param .= join(' ', @$codelist);
            }
            my $option;
            if($param=~/^\[(.*?)\]\s*/){
                $option = $1;
                $param  = $';
            }
            if($option){
                push @$out, "MyPlot::new_group();";
                set_attrs($option, $func);
            }
            if($param=~/\bz\d+\b/){
                my $z_base;
                my $z = MyDef::compileutil::get_macro_word('z', 1);
                my @t = split /(\bz\d+)/, $param;
                foreach my $t (@t){
                    if($t=~/^z(\d+)/){
                        if(!$z){
                            $t = "(\$x$1, \$y$1)";
                        }
                        else{
                            my @i = split //, $1;
                            $t = $z;
                            $t=~s/\$1/$i[0]/g;
                            $t=~s/\$2/$i[1]/g;
                        }
                    }
                }
                $param = join('', @t);
            }
            push @$out, "my \$path = MyPlot::path_load(\"$param\");";
            if($func ne "path"){
                push @$out, "MyPlot::draw(\$path,\"$func\");";
            }
            if($option){
                push @$out, "MyPlot::close_group();";
            }
            return 0;
        }
        elsif($func =~/^set_point/){
            my %points;
            my ($origin, $rotate);
            my $macros1={};
            my @tlist=MyDef::utils::proper_split /,\s*/, $param;
            my $loop_list;
            foreach my $t (@tlist){
                if($t=~/^([ijk])=(.+)/){
                    my @t_loops;
                    my $v=$1;
                    my @ilist=split /:/, $2;
                    if(@ilist==2){
                        for(my $i=$ilist[0];$i<$ilist[1];$i++){
                            push @t_loops, "$v=$i";
                        }
                    }
                    elsif(@ilist==3){
                        for(my $i=$ilist[0];$i<$ilist[1];$i+=$ilist[2]){
                            push @t_loops, "$v=$i";
                        }
                    }
                    if(@t_loops){
                        if(!$loop_list){
                            $loop_list=\@t_loops;
                        }
                        else{
                            my @t;
                            foreach my $t1 (@t_loops){
                                foreach my $t2 (@$loop_list){
                                    push @t, "$t2, $t1";
                                }
                            }
                            $loop_list=\@t;
                        }
                    }
                }
                elsif($t=~/^origin\s*\((\S+),\s*(\S+)\)/){
                    $origin=[$1, $2];
                }
                elsif($t=~/^rotate\s*(\S+)/){
                    $rotate=$1;
                }
                elsif($t=~/^(\w+)=(.+)/){
                    $macros1->{$1}=$2;
                }
            }
            if(!$loop_list){
                $loop_list=[""];
            }
            foreach my $t (@$loop_list){
                my $macros2={};
                while($t=~/(\w+)=(\d+)/g){
                    $macros2->{$1}=$2;
                }
                reset_eqns();
                foreach my $l (@$codelist){
                    if($l!~/^SOURCE/){
                        if($l=~/(.+)=(.+)/){
                            my ($t1, $t2)=($1, $2);
                            my $left=parse_expr($t1, $macros1, $macros2);
                            my $right=parse_expr($t2, $macros1, $macros2);
                            if($left->[1] eq "list" and $right->[1] eq "list"){
                                my $n1=@{$left->[0]};
                                if($n1==@{$right->[0]}){
                                    for(my $i=0; $i<$n1; $i++){
                                        parse_eqn($left->[0]->[$i], $right->[0]->[$i], $macros2, \%points);
                                    }
                                }
                                else{
                                    die "list assignment mismatch ($n1)\n";
                                }
                            }
                            else{
                                parse_eqn($left, $right, $macros2, \%points);
                            }
                        }
                        else{
                        }
                    }
                }
            }
            if(%points){
                my @zlist;
                foreach my $p (sort keys %points){
                    if(defined $points{$p}){
                        my ($pre, $xyz, $tail)=parse_point_name($p);
                        my $x=$pre.'x'.$tail;
                        my $y=$pre.'y'.$tail;
                        push @zlist, [$x, $y, $points{$x}, $points{$y}];
                        $points{$x}=undef;
                        $points{$y}=undef;
                    }
                }
                if($rotate){
                    my $s=sin($rotate*3.14159265/180.0);
                    my $c=cos($rotate*3.14159265/180.0);
                    foreach my $z (@zlist){
                        my $x = $c * $z->[2] - $s * $z->[3];
                        my $y = $s * $z->[2] + $c * $z->[3];
                        $z->[2] = $x;
                        $z->[3] = $y;
                    }
                }
                if($origin){
                    foreach my $z (@zlist){
                        $z->[2]+=$origin->[0];
                        $z->[3]+=$origin->[1];
                    }
                }
                push @$out, "\n";
                foreach my $z (@zlist){
                    push @$out, "my (\$$z->[0], \$$z->[1]) = ($z->[2], $z->[3]);\n";
                }
                push @$out, "\n";
            }
            return 0;
        }
        elsif($func =~/^tex/){
            my @tlist=MyDef::utils::proper_split($param);
            my $pt_size=12;
            my $mode="text";
            my ($x, $y);
            my ($w, $h);
            foreach my $t (@tlist){
                if($t=~/^(\d+)(pt)?$/){
                    $pt_size=$1;
                }
                elsif($t=~/^(math)$/){
                    $mode=$1;
                }
                elsif($t=~/^at\s*\((\S+),\s*(\S+)\)$/){
                    ($x, $y)=($1, $2);
                }
                elsif($t=~/^width\s*(\S+)/){
                    $w = $1;
                }
            }
            push @$out, "MyPlot::init_tex_font($pt_size);";
            while($codelist->[-1]=~/^\s*$/){
                pop @$codelist;
            }
            while($codelist->[0]=~/^SOURCE/){
                shift @$codelist;
            }
            my $src;
            if(@$codelist==1){
                my $t=$codelist->[0];
                $t=~s/\\/\\\\/g;
                $t=~s/'/\\'/g;
                $src="'$t'";
            }
            else{
                push @$out, "my \$tex_src= <<'HERE';";
                push @$out, "PUSHDENT";
                foreach my $t (@$codelist){
                    if($t!~/^SOURCE/){
                        push @$out, $t;
                    }
                }
                push @$out, "HERE";
                push @$out, "POPDENT";
                $src = '$tex_src';
            }
            push @$out, "my \$tex = MyPlot::format_tex(MyPlot::parse_tex($src, \"$mode\"));";
            if($w){
                push @$out, "MyPlot::tex_set_width(\$tex, $w);";
            }
            push @$out, "MyPlot::tex_display(\$tex, $x, $y);";
            return 0;
        }
        return 0;
    }
    elsif($l=~/^\$(\w+)\s*(.*)/){
        my ($func, $param)=($1, $2);
        if($func =~/^label/){
            if($param=~/^\[(.*?)\](.*)/){
                my ($param, $tail)=($1, $2);
                $tail=~s/^\s*[:,]?\s*//;
                my ($x1, $y1, $x2, $y2)=parse_edge($param);
                my @t;
                push @t, "x1=>$x1";
                push @t, "y1=>$y1";
                push @t, "x2=>$x2";
                push @t, "y2=>$y2";
                my @tlist=MyDef::utils::proper_split($tail);
                foreach my $t (@tlist){
                    if($t=~/"(.*)"/){
                        push @t, "label=>$t";
                    }
                }
                my $t=join(", ", @t);
                push @$out, "MyPlot::label_edge({$t});";
            }
            elsif($param=~/^</){
            }
            else{
                my $tail;
                if($param=~/(.*?):\s*(.*)/){
                    ($param, $tail)=($1, $2);
                }
                my ($x, $y)=parse_point($param);
                my @t;
                push @t, "x=>$x";
                push @t, "y=>$y";
                if($param=~/^z(\w+)/){
                    push @t, "label=>\"$1\"";
                }
                elsif($param=~/^(\w+_)z(\w+)/){
                    push @t, "label=>\"$1_$2\"";
                }
                else{
                    push @t, "label=>\"$param\"";
                }
                my $t=join(", ", @t);
                push @$out, "MyPlot::label_point({$t});";
            }
            return 0;
        }
        elsif($func eq "path"){
            return "CALLBACK path $param";
        }
        elsif($func eq "draw"){
            return "CALLBACK draw $param";
        }
        elsif($func eq "fill"){
            return "CALLBACK fill $param";
        }
        elsif($func eq "clip"){
            return "CALLBACK clip $param";
        }
        elsif($func eq "drawclip"){
            return "CALLBACK drawclip $param";
        }
        elsif($func eq "drawfill"){
            return "CALLBACK drawfill $param";
        }
        elsif($func eq "set_point"){
            return "CALLBACK set_point $param";
        }
        elsif($func eq "tex"){
            return "CALLBACK tex $param";
        }
        elsif($func eq "group"){
            push @$out, "MyPlot::new_group();";
            set_attrs($param);
            my @src;
            push @src, "BLOCK";
            push @src, "\$ungroup";
            MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
            return "NEWBLOCK-group";
        }
        elsif($func eq "ungroup"){
            push @$out, "MyPlot::close_group();";
            return 0;
        }
        if($func eq "pattern"){
            if($param=~/(\w+)\s+(\d+)\s+(\d+)/){
                push @$out, "MyPlot::newpattern(\"$1\", $2, $3);";
            }
            elsif($param=~/(\w+)\s+(\d+)/){
                push @$out, "MyPlot::newpattern(\"$1\", $2, $2);";
            }
            else{
                die "unrecognized \$pattern $param\n";
            }
            my @src;
            push @src, "BLOCK";
            push @src, "\$unpattern";
            MyDef::compileutil::set_named_block("NEWBLOCK", \@src);
            return "NEWBLOCK-pattern";
        }
        elsif($func eq "unpattern"){
            push @$out, "MyPlot::pop_pattern();";
            return 0;
        }
        if($func eq "attr"){
            push @$out, "MyPlot::set_attr(\"$param\");";
            return 0;
        }
        elsif($func eq "text"){
            if($param=~/\bz\d+\b/){
                my $z_base;
                my $z = MyDef::compileutil::get_macro_word('z', 1);
                my @t = split /(\bz\d+)/, $param;
                foreach my $t (@t){
                    if($t=~/^z(\d+)/){
                        if(!$z){
                            $t = "(\$x$1, \$y$1)";
                        }
                        else{
                            my @i = split //, $1;
                            $t = $z;
                            $t=~s/\$1/$i[0]/g;
                            $t=~s/\$2/$i[1]/g;
                        }
                    }
                }
                $param = join('', @t);
            }
            my $option;
            if($param=~/^\[(.*?)\]\s*/){
                $option = $1;
                $param  = $';
            }
            if($option){
                push @$out, "MyPlot::new_group();";
                set_attrs($option, "text");
            }
            push @$out, "MyPlot::text(\"$param\");";
            if($option){
                push @$out, "MyPlot::close_group();";
            }
            return 0;
        }
        elsif($func eq "plot"){
            my $option;
            if($param=~/^\[(.*?)\]\s*/){
                $option = $1;
                $param  = $';
            }
            if($option){
                push @$out, "MyPlot::new_group();";
                set_attrs($option, "draw");
            }
            push @$out, "MyPlot::plot($param);";
            if($option){
                push @$out, "MyPlot::close_group();";
            }
            return 0;
        }
    }
    return MyDef::output_perl::parsecode($l);
}
sub dumpout {
    my ($f, $out)=@_;
    MyDef::output_perl::dumpout($f, $out);
}
1;
