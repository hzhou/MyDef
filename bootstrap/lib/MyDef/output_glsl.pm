use strict;
package MyDef::output_glsl;
use MyDef::output_c;
sub get_interface {
    return (\&init_page, \&parsecode, \&MyDef::output_c::set_output, \&MyDef::output_c::modeswitch, \&dumpout);
}
sub init_page {
    my @ret = MyDef::output_c::init_page(@_);
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
    $MyDef::output_c::global_type->{gl_FrontColor}="vec4";
    $MyDef::output_c::global_type->{gl_BackColor}="vec4";
    $MyDef::output_c::global_type->{gl_TexCoord}="vec4 *";
    $MyDef::output_c::global_type->{gl_Position}="vec4";
    $MyDef::output_c::global_type->{gl_FragColor}="vec4";
    $MyDef::output_c::global_type->{gl_FragDepth}="float";
    return @ret;
}
sub parsecode {
    my ($l)=@_;
    if($l=~/^\$(attribute|uniform|varying)\s*(.*)/){
        my $a=$1;
        my @vlist=split /,\s+/, $2;
        my $ghash=$MyDef::output_c::global_hash;
        foreach my $v (@vlist){
            MyDef::output_c::global_add_var($v);
            $ghash->[$v]="$a $v";
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
    }
    MyDef::output_c::dumpout($f, $out);
}
1;
