use strict;
package MyDef::output_xs;
our @xs_globals;
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
        $page->{type}="xs";
    }
    my ($ext, $c_init_mode) = MyDef::output_c::init_page(@_);
    $MyDef::output_c::type_prefix{"hv"}= "HV*";
    $MyDef::output_c::type_prefix{"av"}= "AV*";
    $MyDef::output_c::type_prefix{"sv"}= "SV*";
    return ($ext, "sub");
}
sub parsecode {
    my ($l)=@_;
    if($l=~/^\$eval\s+(\w+)(.*)/){
        my ($codename, $param)=($1, $2);
        $param=~s/^\s*,\s*//;
        my $t=MyDef::compileutil::eval_sub($codename);
        eval $t;
        if($@ and !$MyDef::compileutil::eval_sub_error{$codename}){
            $MyDef::compileutil::eval_sub_error{$codename}=1;
            print "evalsub - $codename\n";
            print "[$t]\n";
            print "eval error: [$@]\n";
        }
        return;
    }
    my $out=$MyDef::output_c::out;
    if($l=~/^XS_START/){
        MyDef::output_c::parsecode("NOOP POST_MAIN");
        %MyDef::output_c::list_function_hash=();
        $l= "DUMP_STUB xs_start";
    }
    elsif($l=~/^\s*(\$if|while|elif|elsif|elseif)\s*(.*)/){
        $l="$1 ".translate_perl_cond($2, $out);
    }
    elsif($l=~/^\$foreach\s+(\w+)\s+in\s+(av_\w+)/){
        my $v_i=$1;
        my $v_av=$2;
        my $v_idx=$2."_index";
        MyDef::output_c::func_add_var($v_idx, "int");
        MyDef::output_c::func_add_var($v_i);
        my $vartype=MyDef::output_c::get_var_type($v_i);
        MyDef::output_c::func_add_var("t_psv");
        my @pre;
        push @pre, "for($v_idx=0; $v_idx<=av_len($v_av); $v_idx++){";
        push @pre, "INDENT";
        push @pre, "t_psv=av_fetch($v_av, $v_idx, 0);";
        translate_scalar(\@pre, $v_i, $vartype, "*t_psv");
        my @post;
        push @post, "DEDENT";
        push @post, "}";
        return MyDef::output_c::single_block_pre_post(\@pre, \@post);
    }
    elsif($l=~/^\$foreach\s+\((\w+),\s*(\w+)\)\s+in\s+(hv_\w+)/){
        my ($v_name, $v_val, $v_hv)=($1, $2, $3);
        my $tn=MyDef::output_c::temp_add_var("tn", "I32");
        MyDef::output_c::protect_var($tn);
        MyDef::output_c::func_add_var($v_name);
        MyDef::output_c::func_add_var($v_val);
        my $vartype=MyDef::output_c::get_var_type($v_val);
        MyDef::output_c::func_add_var("t_sv");
        my @pre;
        push @pre, "$tn=hv_iterinit($v_hv);";
        push @pre, "while((t_sv=hv_iternextsv($v_hv, &$v_name, &$tn))){";
        push @pre, "INDENT";
        translate_scalar(\@pre,$v_val,$vartype,"t_sv");
        my @post;
        push @post, "DEDENT";
        push @post, "}";
        push @post, "PARSE:\$unprotect_var $tn";
        return MyDef::output_c::single_block_pre_post(\@pre, \@post);
    }
    elsif($l=~/^\$getparam\s+(.*)/){
        my @vlist=split /,\s+/, $1;
        my $j=0;
        foreach my $v (@vlist){
            MyDef::output_c::func_add_var($v);
            my $vartype=MyDef::output_c::get_var_type($v);
            translate_scalar($out, $v, $vartype, "ST($j)");
            $j++;
        }
        return;
    }
    elsif($l=~/(\S+)=(\w+)->\{(.*)\}/){
        my ($var, $hv, $key)=($1, $2, $3);
        if($key=~/^['"](.*)['"]/){
            $key=$1;
        }
        my $keylen=length($key);
        MyDef::output_c::auto_add_var($var);
        my $vartype=MyDef::output_c::get_var_type($var);
        MyDef::output_c::func_add_var("t_psv", "SV**");
        push @$out, "t_psv=hv_fetch($hv, \"$key\", $keylen, 0);";
        translate_tpsv($out, $var, $vartype);
        return;
    }
    elsif($l=~/(\S+)=(\w+)->\[(.*)\]/){
        my ($var, $av, $key)=($1, $2, $3);
        MyDef::output_c::auto_add_var($var);
        my $vartype=MyDef::output_c::get_var_type($var);
        MyDef::output_c::func_add_var("t_psv", "SV**");
        push @$out, "t_psv=av_fetch($av, $key, 0);";
        translate_tpsv($out, $var, $vartype);
        return;
    }
    return MyDef::output_c::parsecode($l);
}
sub dumpout {
    my ($f, $out, $pagetype)=@_;
    my $funclist=\@MyDef::output_c::function_list;
    my $funchash=\%MyDef::output_c::list_function_hash;
    foreach my $func (@$funclist){
        if($funchash->{$func->{name}}){
            MyDef::output_c::process_function_std($func);
            my $open=$func->{openblock};
            my $close=$func->{closeblock};
            my $pre=$func->{preblock};
            my $post=$func->{postblock};
            my $name=$func->{name};
            @$open=();
            my $ret_type=$func->{'ret_type'};
            my $paramlist=$func->{'param_list'};
            my @param_name_list;
            foreach my $p (@$paramlist){
                if($p=~/(\w+)\s*$/){
                    push @param_name_list, $1;
                }
            }
            my $param_name_list_str=join(",", @param_name_list);
            push @$open, "$ret_type";
            push @$open, "$name($param_name_list_str)";
            push @$open, "INDENT";
            if(@$paramlist){
                push @$open, "INDENT";
                foreach my $p (@$paramlist){
                    push @$open, "$p;";
                }
                push @$open, "DEDENT";
            }
            my $var_list=$func->{var_list};
            if(@$var_list){
                push @$open, "PREINIT:";
            }
            push @$pre, "DEDENT";
            push @$pre, "PPCODE:";
            push @$pre, "INDENT";
            @$close=();
            push @$close, "DEDENT";
            push @$close, "NEWLINE";
            $func->{skip_declare}=1;
            $func->{processed}=1;
        }
    }
    my @t;
    my $cnt;
    my $ghash=$MyDef::output_c::global_hash;
    foreach my $name (@$MyDef::output_c::global_list){
        my $type=$ghash->{$name}->{type};
        if($type=~/^[SHA]V/){
            my $decl = MyDef::output_c::var_declare($ghash->{$name});
            push @xs_globals, "$decl;\n";
            $cnt++;
        }
        else{
            push @t, $name;
        }
    }
    if($cnt>0){
        @$MyDef::output_c::global_list=@t;
    }
    my $block=MyDef::compileutil::get_named_block("xs_start");
    push @$block, "#include \"EXTERN.h\"\n";
    push @$block, "#include \"perl.h\"\n";
    push @$block, "#include \"XSUB.h\"\n";
    push @$block, "\n";
    push @$block, "#include \"ppport.h\"\n";
    push @$block, "\n";
    foreach my $l (@xs_globals){
        push @$block, $l;
    }
    push @$block, "\n";
    my $pagename=$MyDef::output_c::page->{pagename};
    push @$block, "MODULE = $pagename\t\tPACKAGE = $pagename\n";
    push @$block, "\n";
    MyDef::output_c::dumpout($f, $out, $pagetype);
}
sub translate_scalar {
    my ($out, $var, $vartype, $sv)=@_;
    if($vartype eq "int"){
        push @$out, "$var = SvIV($sv);";
    }
    elsif($vartype eq "double" or $vartype eq "float"){
        push @$out, "$var = SvNV($sv);";
    }
    elsif($vartype eq "char *"){
        MyDef::output_c::func_add_var("t_strlen");
        push @$out, "$var = SvPV($sv, t_strlen);";
        push @$out, "$var\[t_strlen\] = '\\0';";
    }
    elsif($vartype =~ /^([SAH]V\*)/){
        push @$out, "$var = ($1)SvRV($sv);";
    }
    else{
        print "translate_scalar: unhandled $var - $vartype\n";
    }
}
sub translate_null {
    my ($out, $var, $vartype)=@_;
    if($vartype !~/int|float|double/){
        push @$out, "    $var = NULL;";
    }
    elsif($vartype eq "int"){
        push @$out, "    $var = 0;";
    }
    else{
        push @$out, "    $var = 0.0;";
    }
}
sub translate_tpsv {
    my ($out, $var, $vartype)=@_;
    push @$out, "if(t_psv){";
    push @$out, "INDENT";
    translate_scalar($out, $var, $vartype, "*t_psv");
    push @$out, "DEDENT";
    push @$out, "}";
    push @$out, "else{";
    translate_null($out, $var, $vartype);
    push @$out, "}";
}
sub translate_perl_cond {
    my ($l, $out)=@_;
    if($l=~/^\s*(\w+)->\{(.+)\}\s*$/){
        my ($hv, $key)=($1, $2);
        my $keylen=length($key);
        my $tl="hv_exists($hv, \"$key\", $keylen)";
        return $tl;
    }
    elsif($l=~/^\s*(\w+)->\[(.+)\]\s*$/){
        my ($hv, $key)=($1, $2);
        my $tl="SvTRUE(*(av_fetch($hv, $key, 0)))";
        return $tl;
    }
    else{
        return $l;
    }
}
1;
