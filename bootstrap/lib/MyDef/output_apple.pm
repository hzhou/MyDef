use strict;
package MyDef::output_apple;
our %imports;
our $class_default;
our %classes;
our @class_list;
our $cur_class;
use MyDef::output_c;
sub get_interface {
    return (\&init_page, \&parsecode, \&MyDef::output_c::set_output, \&modeswitch, \&dumpout);
}
sub modeswitch {
    my ($mode, $in)=@_;
}
sub init_page {
    my ($page)=@_;
    if(!$page->{type}){
        $page->{type}="m";
    }
    my ($ext, $c_init_mode) = MyDef::output_c::init_page(@_);
    $MyDef::output_c::type_prefix{"obj"}="id";
    $MyDef::output_c::global_type->{self}=1;
    $imports{"UIKit/UIKit.h"}=1;
    $class_default=$MyDef::def->{resource}->{"class_default"};
    if(!$class_default){
        warn "resource: class_default not found!\n";
    }
    return ($ext, "sub");
}
sub parsecode {
    my ($l)=@_;
    if($l=~/(RGB|RCT|IMG|FILE|ARRAY|HASH|CSTRING)\((.*?)\)/){
        my $pre=$`;
        my $post=$';
        my $fn=$1;
        my $param=$2;
        if($fn eq "RGB"){
            if(length($param)==6){
                my ($r, $g, $b)=(hex(substr($param, 0, 2)), hex(substr($param, 2, 2)), hex(substr($param, 4, 2)));
                $l=$pre."[UIColor colorWithRed:$r/255.0 green:$g/255.0 blue:$b/255.0 alpha:1]".$post;
            }
            elsif(length($param)==8){
                my ($r, $g, $b, $a)=(hex(substr($param, 0, 2)), hex(substr($param, 2, 2)), hex(substr($param, 4, 2)), hex(substr($param, 6, 2)));
                $l=$pre."[UIColor colorWithRed:$r/255.0 green:$g/255.0 blue:$b/255.0 alpha:$a/255.0]".$post;
            }
        }
        elsif($fn eq "RCT"){
            $l=$pre."CGRectMake($param)".$post;
        }
        elsif($fn eq "IMG"){
            my $t=nsstring($param);
            $l=$pre."[UIImage imageNamed:$t]".$post;
        }
        elsif($fn eq "FILE"){
            if($param=~/(Documents|Library)\/(.*)/i){
                my $dir;
                if(lc($1) eq "documents"){
                    $dir="NSDocumentDirectory";
                }
                elsif(lc($1) eq "library"){
                    $dir="NSLibraryDirectory";
                }
                my $s=nsstring($2);
                $l=$pre."[[NSSearchPathForDirectoriesInDomains($dir, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:$s]".$post;
            }
            else{
                my $s=nsstring($param);
                $l=$pre."[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:$s]".$post;
            }
        }
        elsif($fn eq "ARRAY"){
            my @plist=split /, \s*/, $param;
            my @objs;
            foreach my $p(@plist){
                push @objs, nsnumber($p);
            }
            my $objlist=join(", ", @objs);
            $l=$pre."[NSArray arrayWithObjects: $objlist, nil]". $post;
        }
        elsif($fn eq "HASH"){
            my @plist=split /,\s*/, $param;
            my @objs;
            my @keys;
            foreach my $p (@plist){
                my ($key, $val)=split /=>/, $p;
                push @objs, $val;
                push @keys, "@\"$key\"";
            }
            my $objlist=join(", ", @objs);
            my $keylist=join(", ", @keys);
            $l=$pre."[NSDictionary dictionaryWithObjects:[arrayWithObjects $objlist, nil] forKeys:[arrayWithObjects $keylist, nil]]". $post;
        }
        elsif($fn eq "CSTRING"){
            $l=$pre."(char *)[$param cStringUsingEncoding:NSASCIIStringEncoding]". $post;
        }
    }
    if($l=~/^\$class\s+(\w+)(.*)/){
        my $name=new_class($1, $2);
        push @$MyDef::output_c::out, "DUMP_STUB CLASS-$name";
        push @$MyDef::output_c::out, "BLOCK";
        return "NEWBLOCK-\$class_end";
    }
    elsif($l=~/^\$class_end/){
        undef $cur_class;
        return;
    }
    elsif($l=~/^\$implement\s+(\w+)/){
        my $protocol=$1;
        if($protocol){
            my $plist=$cur_class->{protocols};
            my $exist=0;
            foreach my $p (@$plist){
                if($p eq $protocol){
                    $exist=1;
                }
            }
            if(!$exist){
                push @$plist, $protocol;
                res_collect($cur_class->{field}, $class_default->{$protocol});
            }
        }
        return;
    }
    elsif($l=~/^\$method\s+(\w+)\s*(.*)/){
        my ($name, $tail)=($1, $2);
        if($tail=~/^\((.*)\)/){
            $tail=$1;
        }
        return new_method($name, $tail);
    }
    elsif($l=~/^\$MakeController\s+(\w+)/){
        create_controller($1);
        return;
    }
    if($l=~/^\s*\$prop\s+(.*)/){
        my ($t, $attr)=($1, undef);
        my @plist=split /,\s*/, $t;
        foreach my $p (@plist){
            my $name=$p;
            my $type;
            if($p=~/(.*)\s+(\w+)$/){
                $type=$1;
                $name=$2;
            }
            else{
                $type=MyDef::output_c::get_c_type($name);
            }
            if($cur_class){
                if($attr){
                    $cur_class->{properties}->{$name}="($attr) $type";
                }
                else{
                    $cur_class->{properties}->{$name}=$type;
                }
                if($MyDef::output_c::cur_function){
                    my $var_type=$MyDef::output_c::cur_function->{var_type};
                    $var_type->{$name}=$type;
                }
            }
        }
        return;
    }
    elsif($l=~/^\s*\$prop\((.*)\)\s+(.*)/){
        my ($t, $attr)=($2, $1);
        my @plist=split /,\s*/, $t;
        foreach my $p (@plist){
            my $name=$p;
            my $type;
            if($p=~/(.*)\s+(\w+)$/){
                $type=$1;
                $name=$2;
            }
            else{
                $type=MyDef::output_c::get_c_type($name);
            }
            if($cur_class){
                if($attr){
                    $cur_class->{properties}->{$name}="($attr) $type";
                }
                else{
                    $cur_class->{properties}->{$name}=$type;
                }
                if($MyDef::output_c::cur_function){
                    my $var_type=$MyDef::output_c::cur_function->{var_type};
                    $var_type->{$name}=$type;
                }
            }
        }
        return;
    }
    if($l=~/^\s*@(\w+)\s*=\s*(.*)/){
        my $type=get_c_type($1);
        if($cur_class){
            $cur_class->{properties}->{$1}=$type;
            declare_var($1, $type);
        }
        $l="$1 = $2";
    }
    if($l=~/^\s*@(.*)\s+(\w+)\s*=\s*(.*)/){
        my $type=$1;
        if($cur_class){
            $cur_class->{properties}->{$2}=$type;
            declare_var($2, $type);
        }
        $l="$2 = $3";
    }
    if($l=~/^(\S+)\s*=\s*new (\w+)(.*)/){
        my ($v, $name, $spec)=($1, $2, $3);
        $spec=~s/^,?\s*//;
        my $class_field;
        if($classes{$name}){
            $class_field=$classes{$name}->{field};
        }
        else{
            my $field={};
            my $super_field=$class_default->{$name};
            while($super_field){
                res_collect($field, $super_field);
                if($super_field->{super}){
                    $super_field=$class_default->{$super_field->{super}};
                }
                else{
                    undef $super_field;
                }
            }
            res_collect($field, $class_default->{Default});
            $class_field=$field;
        }
        my $class_name=$name;
        if($class_field->{class}){
            $class_name=$class_field->{class};
        }
        if($v!~/[.]/){
            MyDef::output_c::func_add_var($v, "$class_name *");
        }
        if($class_field->{create_spec}){
            my $init=$class_field->{create_spec};
            $init=~s/\$0/$class_name/;
            if($init=~/\$\@/){
                $init=~s/\$\@/$spec/;
            }
            elsif($init=~/\$2/){
                my @spec_list=split /,\s*/, $spec;
                for(my $i=1;$i<@spec_list;$i++){
                    $init=~s/\$$i/$spec_list[$i-1]/;
                }
            }
            else{
                $init=~s/\$1/$spec/;
            }
            push @$MyDef::output_c::out, "$v = $init;";
        }
        else{
            warn "class $class_name create_spec not found!\n";
        }
        if($class_field->{imports}){
            my @inc_list=split /,\s*/, $class_field->{imports};
            foreach my $inc (@inc_list){
                $imports{$inc}=1;
            }
        }
        return;
    }
    if($l=~/^\s*\$foreach\s+(\w+)\s+in\s+(\w+)/){
        func_add_var($1);
        return single_block("for($1 in $2){", "}")
    }
    if($l=~/^\s*([a-zA-Z0-9._]+)->(\w+)(\s*)(.*)/){
        my ($obj, $mtd, $s, $t)=($1, $2, $3, $4);
        if(!$4){
            push @$MyDef::output_c::out, "[$1 $2];";
            return;
        }
        else{
            if($s=~/\s/){
                push @$MyDef::output_c::out, "[$obj $mtd:$t];";
                return;
            }
        }
    }
    return MyDef::output_c::parsecode($l);
}
sub dumpout {
    my ($f, $out)=@_;
    my $funclist=MyDef::dumpout::get_func_list();
    foreach my $func (@$funclist){
        if($func->{is_method}){
            MyDef::output_c::process_function_std($func);
            my $declare=$func->{declare};
            if(!$declare){
                my $name=$func->{"name"};
                my $ret_type=$func->{'ret_type'};
                if(!$ret_type){
                    $ret_type="void";
                }
                $declare="- ($ret_type)";
                my $param_list=$func->{'param_list'};
                if(@$param_list){
                    my @tlist;
                    my @name_list=split /:/, $name;
                    if($#$param_list==$#name_list){
                        for(my $i=0;$i<@name_list;$i++){
                            if($param_list->[$i]=~/(.*)\s(\W+)$/){
                                push @tlist, "$name_list[$i]:($1)$2";
                            }
                        }
                    }
                    else{
                        for(my $i=0;$i<@name_list;$i++){
                            if($param_list->[$i]=~/(.*)\s(\W+)$/){
                                push @tlist, "$name_list[$i]:($1)$2";
                            }
                        }
                        for(my $i=@name_list;$i<@$param_list;$i++){
                            if($param_list->[$i]=~/(.*)\s(\W+)$/){
                                push @tlist, "p$i:($1)$2";
                            }
                        }
                    }
                    $declare.=join(' ', @tlist);
                }
                else{
                    $declare.=$name;
                }
                $func->{declare}=$declare;
            }
            $func->{openblock}=[$declare."{"];
            $func->{processed}=1;
            $func->{processed}=1;
        }
    }
    my $block=MyDef::compileutil::get_named_block("global_init");
    foreach my $class (@class_list){
        push @$block, "\@class $class->{name};";
    }
    push @$block, "NEWLINE";
    foreach my $class (@class_list){
        my $name=$class->{name};
        my $block=MyDef::compileutil::get_named_block("CLASS-$name");
        print "block CLASS-$name $block\n";
        my $class=$classes{$name};
        my $interface=$class->{interface};
        if($class->{protocols} and @{$class->{protocols}}){
            my $plist=$class->{protocols};
            $interface.=" <".join(", ", @$plist).">";
        }
        push @$block, "// ---------- BEGIN CLASS $name -------------";
        push @$block, "\@interface $name : $interface";
        while(my ($pname, $ptype)=each %{$class->{properties}}){
            push @$block, "    \@property $ptype $pname;";
        }
        foreach my $fidx (@{$class->{methods}}){
            my $func=MyDef::dumpout::get_function($fidx);
            push @$block, "    $func->{declare};";
        }
        push @$block, "\@end";
        push @$block, "NEWLINE";
        push @$block, "\@implementation $name";
        push @$block, "NEWLINE";
        while(my ($pname, $ptype)=each %{$class->{properties}}){
            push @$block, "\@synthesize $pname;";
        }
        foreach my $fidx (@{$class->{methods}}){
            my $func=MyDef::dumpout::get_function($fidx);
            push @$block, "NEWLINE";
            push @$block, "DUMP_STUB METHOD-$fidx";
            push @$block, "NEWLINE";
        }
        push @$block, "\@end";
        push @$block, "// ----------- END CLASS $name --------------";
        push @$block, "NEWLINE";
    }
    my @includes=keys %imports;
    foreach my $i (keys %imports){
        push @$f, "#import <$i>\n";
    }
    push @$f, "\n";
    MyDef::output_c::dumpout($f, $out);
}
sub new_class {
    my ($name, $tail)=@_;
    my $new_class_name;
    if($tail=~/,\s*(\w+)/){
        $new_class_name=$1;
    }
    elsif($tail=~/,\s*_(\w+)/){
        $new_class_name="$name\_$1";
    }
    else{
        $new_class_name=$name;
    }
    if($classes{$new_class_name}){
        $cur_class=$classes{$new_class_name};
        warn "Duplicate class [$new_class_name]\n";
    }
    else{
        $cur_class={name=>$new_class_name, super=>$name, protocols=>[], properties=>{}, methods=>[], declares=>[]};
        $classes{$new_class_name} = $cur_class;
        push @class_list, $cur_class;
    }
    my $field={};
    my $super_field=$class_default->{$name};
    while($super_field){
        res_collect($field, $super_field);
        if($super_field->{super}){
            $super_field=$class_default->{$super_field->{super}};
        }
        else{
            undef $super_field;
        }
    }
    res_collect($field, $class_default->{Default});
    $cur_class->{field}=$field;
    my $class=$field->{class};
    if(!$class){
        $class=$name;
    }
    $cur_class->{interface}="$class";
    my $protocol=$field->{protocol};
    if($protocol){
        my $plist=$cur_class->{protocols};
        my $exist=0;
        foreach my $p (@$plist){
            if($p eq $protocol){
                $exist=1;
            }
        }
        if(!$exist){
            push @$plist, $protocol;
            res_collect($cur_class->{field}, $class_default->{$protocol});
        }
    }
    return $new_class_name;
}
sub new_method {
    my ($name, $param)=@_;
    my $fidx=MyDef::output_c::open_function($name, $param);
    my $func=MyDef::dumpout::get_function($fidx);
    $func->{"skip_declare"}=1;
    my $declare;
    my $method=$cur_class->{field}->{$name};
    if(!ref($method)){
        $declare=$method;
    }
    else{
        if($method->{declare}){
            $declare=$method->{declare};
        }
        else{
            $declare=$method->{_name};
        }
    }
    if($declare){
        $func->{declare}=$declare;
    }
    my $var_type=$func->{var_type};
    my $prop=$cur_class->{properties};
    foreach my $v (keys %$prop){
        $var_type->{$v}=$prop->{$v};
    }
    push @{$cur_class->{methods}}, $fidx;
    my $block=MyDef::compileutil::get_named_block("METHOD-$fidx");
    my $tempout=$MyDef::compileutil::out;
    $MyDef::compileutil::out=$block;
    $MyDef::output_c::out=$block;
        push @$block, "OPEN_FUNC_$fidx";
        push @$block, "SOURCE_INDENT";
        if(ref($method) eq "HASH" and $method->{pre}){
            if(!ref($method->{pre})){
                MyDef::compileutil::parseblock([$method->{pre}]);
            }
            else{
                MyDef::compileutil::parseblock($method->{pre}->{_list});
            }
        }
        push @$block, "BLOCK";
        if(ref($method) eq "HASH" and $method->{post}){
            if(!ref($method->{post})){
                MyDef::compileutil::parseblock([$method->{post}]);
            }
            else{
                MyDef::compileutil::parseblock($method->{post}->{_list});
            }
        }
        push @$block, "SOURCE_DEDENT";
    $MyDef::compileutil::out=$tempout;
    $MyDef::output_c::out=$tempout;
    return $block;
}
sub res_collect {
    my ($field, $from)=@_;
    if($from){
        while(my ($k, $v)=each %$from){
            if(!$field->{$k}){
                $field->{$k}=$v;
            }
            else{
                if($k eq "imports"){
                    $field->{$k}="$v, $field->{$k}";
                }
            }
        }
    }
}
my $animate_block_depth=0;
my $animate_need_completion=0;
my %viewitems;
sub parse_animation_param {
    my $param=shift;
    my @plist=split /,\s*/, $param;
    if(@plist>1){
        $animate_need_completion++;
        my @options;
        for(my $i=1; $i<@plist; $i++){
            push @options, "UIViewAnimationOption$plist[$i]";
        }
        $param="$plist[0] delay:0 options:".join('|', @options);
    }
    return $param;
}
sub nsstring {
    my $s=shift;
    if($s=~/^"(.*)"/){
        return "@\"$1\"";
    }
    elsif($s =~/^nss_/){
        return $s;
    }
    else{
        return "@\"$s\"";
    }
}
sub nsnumber {
    my $s=shift;
    if($s=~/^\d/){
        if($s=~/\./){
            return "[NSNumber numberWithFloat:$s]";
        }
        else{
            return "[NSNumber numberWithInt:$s]";
        }
    }
    else{
        my $type=get_c_type($s);
        if($type =~/^int$/){
            return "[NSNumber numberWithInt:$s]";
        }
        elsif($type =~/^(float|double)$/){
            return "[NSNumber numberWithFloat:$s]";
        }
        else{
            return $s;
        }
    }
}
sub load_view_config {
    my ($f, $itemhash)=@_;
    my $item;
    open In, $f or return;
    while(<In>){
        if(/^#/){
        }
        elsif(/^(\w+)/){
            $item={};
            $itemhash->{$1}=$item;
        }
        elsif(/^\s+(\w+):\s*(.*)/){
            $item->{$1}=$2;
        }
    }
    close In;
}
1;
