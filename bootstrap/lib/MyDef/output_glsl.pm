use strict;
use MyDef::output_c;

package MyDef::output_glsl;
our $out;
our $shader_type;
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
        $page->{type}="glsl";
    }
    MyDef::output_c::init_page(@_);
    $MyDef::output_c::type_prefix{v}="vec4";
    $MyDef::output_c::type_prefix{v2}="vec2";
    $MyDef::output_c::type_prefix{v3}="vec3";
    $MyDef::output_c::type_prefix{v4}="vec4";
    $MyDef::output_c::type_prefix{iv2}="ivec2";
    $MyDef::output_c::type_prefix{iv3}="ivec3";
    $MyDef::output_c::type_prefix{iv4}="ivec4";
    $MyDef::output_c::type_prefix{bv2}="bvec2";
    $MyDef::output_c::type_prefix{bv3}="bvec3";
    $MyDef::output_c::type_prefix{bv4}="bvec4";
    $MyDef::output_c::type_prefix{m}="mat4";
    $MyDef::output_c::type_prefix{m2}="mat2";
    $MyDef::output_c::type_prefix{m3}="mat3";
    $MyDef::output_c::type_prefix{m4}="mat4";
    $MyDef::output_c::type_prefix{s1}="sampler1D";
    $MyDef::output_c::type_prefix{s2}="sampler2D";
    $MyDef::output_c::type_prefix{s3}="sampler3D";
    $MyDef::output_c::type_prefix{sc}="samplerCube";
    $MyDef::output_c::type_prefix{s1w}="sampler1Dshadow";
    $MyDef::output_c::type_prefix{s2w}="sampler2Dshadow";
    $MyDef::output_c::type_name{gl_FrontColor}="vec4";
    $MyDef::output_c::type_name{gl_BackColor}="vec4";
    $MyDef::output_c::type_name{gl_TexCoord}="vec4 *";
    $MyDef::output_c::type_name{gl_Position}="vec4";
    $MyDef::output_c::type_name{gl_FragColor}="vec4";
    $MyDef::output_c::type_name{gl_FragDepth}="float";
    $MyDef::output_c::type_name{pos}="vec3";
    $MyDef::output_c::type_name{norm}="vec3";
    $MyDef::output_c::type_name{uv}="vec3";
    $MyDef::output_c::type_name{color}="vec3";
    $MyDef::output_c::type_name{iResolution}="vec2";
    $shader_type = $MyDef::page->{type};
    my $attrib_list = MyDef::compileutil::get_macro_word("attrib_list", 1);
    my $uniform_list = MyDef::compileutil::get_macro_word("uniform_list", 1);
    my $varying_list = MyDef::compileutil::get_macro_word("varying_list", 1);
    if($shader_type eq "vsl"){
        if(!$attrib_list){
            my $name = MyDef::output_c::global_add_var("pos");
            my $var = MyDef::output_c::find_var($name);
            $var->{attr} = "in";
        }
        else{
            foreach my $v (split /,\s*/, $attrib_list){
                my $name = MyDef::output_c::global_add_var($v);
                my $var = MyDef::output_c::find_var($name);
                $var->{attr} = "in";
            }
        }
    }
    elsif($shader_type eq "fsl"){
        my $name = MyDef::output_c::global_add_var("color");
        my $var = MyDef::output_c::find_var($name);
        $var->{attr} = "out";
    }
    if($uniform_list){
        foreach my $v (split /,\s*/, $uniform_list){
            my $name = MyDef::output_c::global_add_var($v);
            my $var = MyDef::output_c::find_var($name);
            $var->{attr} = "uniform";
        }
    }
    if($varying_list){
        foreach my $v (split /,\s*/, $varying_list){
            if($shader_type eq "vsl"){
                my $name = MyDef::output_c::global_add_var($v);
                my $var = MyDef::output_c::find_var($name);
                $var->{attr} = "out";
            }
            else{
                my $name = MyDef::output_c::global_add_var($v);
                my $var = MyDef::output_c::find_var($name);
                $var->{attr} = "in";
            }
        }
    }
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
    if($l=~/^\x24(attribute|uniform|varying|in|out)\s*(.*)/){
        my $attr=$1;
        my @vlist=split /,\s+/, $2;
        foreach my $v (@vlist){
            my $name = MyDef::output_c::global_add_var($v);
            if($attr){
                my $var = MyDef::output_c::find_var($name);
                $var->{attr} = "$attr ".$var->{attr};
            }
        }
        return;
    }
    return MyDef::output_c::parsecode($l);
}
sub dumpout {
    my ($f, $out)=@_;
    my $func=$MyDef::output_c::functions{"main"};
    if($func){
        $func->{skip_declare}=1;
        $func->{ret_type}="void";
        $func->{param_list}=["void"];
        $func->{init}=["DUMP_STUB main_init"];
        $func->{finish}=["DUMP_STUB main_exit"];
        MyDef::output_c::process_function_std($func);
        $func->{processed}=1;
    }
    push @$f, "#version 330 core\n\n";
    $MyDef::output_c::has_main=1;
    @MyDef::output_c::include_list=();
    @MyDef::output_c::object_list=();
    %MyDef::output_c::objects=();
    MyDef::output_c::dumpout($f, $out);
}
1;
