use strict;
package output_win32rc;
our $debug;
our $out;
our $mode;
our $page;
my %id_base;
my %id_step;
my %res_id_hash;
my @res_id_list;
sub get_interface {
    my $interface_type="general";
    return (\&init_page, \&parsecode, \&set_output, \&modeswitch, \&dumpout, $interface_type);
}
sub init_page {
    my ($t_page)=@_;
    $page=$t_page;
    MyDef::set_page_extension("rc");
    return $page->{init_mode};
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
    if($l=~/^DEBUG (\w+)/){
        if($1 eq "OFF"){
            $debug=0;
        }
        else{
            $debug=$1;
        }
        return;
    }
    elsif($l=~/^\$warn (.*)/){
        my $curfile=MyDef::compileutil::curfile_curline();
        print "[$curfile]\x1b[33m $1\n\x1b[0m";
        return;
    }
    elsif($l=~/^\$template\s*(.*)/){
        open In, $1 or die "Can't open template $1\n";
        my @all=<In>;
        close In;
        foreach my $a (@all){
            push @$out, $a;
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
            print "eval error: [$@]\n";
        }
        return;
    }
    elsif($l=~/^\$write\s+(.*)/i){
        my @plist=split /,\s*/, $1;
        foreach my $name (@plist){
            if($name=~/^IDI_/){
                resource_define($name, "other");
                push @$out, "";
                push @$out, "$name ICON \"$file\"";
            }
            elsif($name=~/^menu_/){
                my $ogdl=MyDef::compileutil::get_ogdl($name);
                my $name=$ogdl->{_name};
                resource_define($name, "other");
                push @$out, "";
                push @$out, "$name MENU";
                push @$out, "{";
                ogdl_menu_rc($ogdl, $level);
                push @$out, "}";
            }
            elsif($name=~/^dialog_/){
                my $ogdl=MyDef::compileutil::get_ogdl($name);
                my $name=$ogdl->{_name};
                resource_define($name, "other");
                my $sizestr;
                if($ogdl->{size}=~/(\d+),\s*(\d+),\s*(\d+),\s*(\d+)/){
                    my ($x, $y, $w, $h)=($1, $2, $3, $4);
                    $sizestr="$x, $y, $w, $h";
                }
                my $attr;
                if($ogdl->{discardable}){
                    $attr="DISCARDABLE ";
                }
                push @$out, "";
                push @$out, "$name DIALOG $attr$sizestr";
                if($ogdl->{style}){
                    push @$out, "STYLE $ogdl->{style}";
                }
                else{
                    push @$out, "STYLE WS_POPUP | WS_BORDER";
                }
                if($ogdl->{caption}){
                    push @$out, "CAPTION \"$ogdl->{caption}\"";
                }
                if($ogdl->{font}){
                    my $tstr=$ogdl->{font};
                    my $font_name="Times New Roman";
                    my $font_size=10;
                    foreach my $t (split(/,\s*/, $tstr)){
                        if($t=~/^\s*(\d+)/){
                            $font_size=$1;
                        }
                        else{
                            $t=~s/^\s+//;
                            $t=~s/\s+$//;
                            $font_name=$t;
                        }
                    }
                    my $fontstr="$font_size, \"$font_name\"";
                    push @$out, "FONT $fontstr";
                }
                if($ogdl->{class}){
                    push @$out, "CLASS \"$ogdl->{class}\"";
                }
                push @$out, "BEGIN";
                my $ogdl_list=$ogdl->{_list};
                my $level=1;
                my $indent="    " x $level;
                foreach my $c_ogdl (@$ogdl_list){
                    if(ref($c_ogdl) eq "HASH"){
                        if((defined($c_ogdl->{disable}) && !$c_ogdl->{disable}) or (!defined($c_ogdl->{disable}) && !$ogdl->{disable})){
                            my $name=$c_ogdl->{_name};
                            if($name=~/^button_/){
                                resource_define($name, "ctrl");
                                my $title=$name;
                                if($c_ogdl->{title}){
                                    $title=$c_ogdl->{title};
                                }
                                elsif($c_ogdl->{text}){
                                    $title=$c_ogdl->{text};
                                }
                                my $sizestr;
                                if($c_ogdl->{size}=~/(\d+),\s*(\d+),\s*(\d+),\s*(\d+)/){
                                    my ($x, $y, $w, $h)=($1, $2, $3, $4);
                                    $sizestr="$x, $y, $w, $h";
                                }
                                my $cname="PUSHBUTTON";
                                if($c_ogdl->{default}){
                                    $cname="DEFPUSHBUTTON";
                                }
                                push @$out, "$indent$cname \"$title\", $name, $sizestr";
                            }
                            elsif($name=~/^text_/){
                                resource_define($name, "ctrl");
                                my $title=$name;
                                if($c_ogdl->{title}){
                                    $title=$c_ogdl->{title};
                                }
                                elsif($c_ogdl->{text}){
                                    $title=$c_ogdl->{text};
                                }
                                my $sizestr;
                                if($c_ogdl->{size}=~/(\d+),\s*(\d+),\s*(\d+),\s*(\d+)/){
                                    my ($x, $y, $w, $h)=($1, $2, $3, $4);
                                    $sizestr="$x, $y, $w, $h";
                                }
                                if(!$c_ogdl->{align}){
                                    $c_ogdl->{align}=$ogdl->{text_align};
                                }
                                my $cname;
                                if($c_ogdl->{align}=~/center/){
                                    $cname="CTEXT";
                                }
                                else{
                                    $cname="LTEXT";
                                }
                                push @$out, "$indent$cname \"$title\", $name, $sizestr";
                            }
                            elsif($name=~/^list_/){
                                resource_define($name, "ctrl");
                                my $sizestr;
                                if($c_ogdl->{size}=~/(\d+),\s*(\d+),\s*(\d+),\s*(\d+)/){
                                    my ($x, $y, $w, $h)=($1, $2, $3, $4);
                                    $sizestr="$x, $y, $w, $h";
                                }
                                my $style=$c_ogdl->{style};
                                if($style){
                                    $style=", $style";
                                }
                                my $cname="LISTBOX";
                                if(!$c_ogdl->{style}){
                                    $c_ogdl->{style}=$ogdl->{list_style};
                                }
                                push @$out, "$indent$cname $name, $sizestr$style";
                            }
                            elsif($name=~/^control_/){
                                resource_define($name, "ctrl");
                                my $cname="CONTROL";
                                my $sizestr;
                                if($c_ogdl->{size}=~/(\d+),\s*(\d+),\s*(\d+),\s*(\d+)/){
                                    my ($x, $y, $w, $h)=($1, $2, $3, $4);
                                    $sizestr="$x, $y, $w, $h";
                                }
                                my $style=$c_ogdl->{style};
                                if($style){
                                    $style=", $style";
                                }
                                my $text=$c_ogdl->{text};
                                my $class=$c_ogdl->{class};
                                push @$out, "$indent$cname \"$text\", $name, \"$class\", $sizestr$style";
                            }
                        }
                    }
                }
                push @$out, "END";
            }
        }
        return 1;
    }
    elsif($l=~/^\$define\s+(.*)/i){
        resource_define($1);
        return 1;
    }
    elsif($l=~/^\$icon\s+(\w+),?\s+(.+)/i){
        my ($name, $file)=($1, $2);
        resource_define($name, "other");
        push @$out, "";
        push @$out, "$name ICON \"$file\"";
        return 1;
    }
    elsif($l=~/^\$menu\s+(\w+)/i){
        my $name=$1;
        my $ogdl=MyDef::compileutil::get_ogdl($name);
        my $name=$ogdl->{_name};
        resource_define($name, "other");
        push @$out, "";
        push @$out, "$name MENU";
        push @$out, "{";
        ogdl_menu_rc($ogdl, $level);
        push @$out, "}";
        return 1;
    }
    elsif($l=~/^\$dialog\s+(\w+)/i){
        my $name=$1;
        my $ogdl=MyDef::compileutil::get_ogdl($name);
        my $name=$ogdl->{_name};
        resource_define($name, "other");
        my $sizestr;
        if($ogdl->{size}=~/(\d+),\s*(\d+),\s*(\d+),\s*(\d+)/){
            my ($x, $y, $w, $h)=($1, $2, $3, $4);
            $sizestr="$x, $y, $w, $h";
        }
        my $attr;
        if($ogdl->{discardable}){
            $attr="DISCARDABLE ";
        }
        push @$out, "";
        push @$out, "$name DIALOG $attr$sizestr";
        if($ogdl->{style}){
            push @$out, "STYLE $ogdl->{style}";
        }
        else{
            push @$out, "STYLE WS_POPUP | WS_BORDER";
        }
        if($ogdl->{caption}){
            push @$out, "CAPTION \"$ogdl->{caption}\"";
        }
        if($ogdl->{font}){
            my $tstr=$ogdl->{font};
            my $font_name="Times New Roman";
            my $font_size=10;
            foreach my $t (split(/,\s*/, $tstr)){
                if($t=~/^\s*(\d+)/){
                    $font_size=$1;
                }
                else{
                    $t=~s/^\s+//;
                    $t=~s/\s+$//;
                    $font_name=$t;
                }
            }
            my $fontstr="$font_size, \"$font_name\"";
            push @$out, "FONT $fontstr";
        }
        if($ogdl->{class}){
            push @$out, "CLASS \"$ogdl->{class}\"";
        }
        push @$out, "BEGIN";
        my $ogdl_list=$ogdl->{_list};
        my $level=1;
        my $indent="    " x $level;
        foreach my $c_ogdl (@$ogdl_list){
            if(ref($c_ogdl) eq "HASH"){
                if((defined($c_ogdl->{disable}) && !$c_ogdl->{disable}) or (!defined($c_ogdl->{disable}) && !$ogdl->{disable})){
                    my $name=$c_ogdl->{_name};
                    if($name=~/^button_/){
                        resource_define($name, "ctrl");
                        my $title=$name;
                        if($c_ogdl->{title}){
                            $title=$c_ogdl->{title};
                        }
                        elsif($c_ogdl->{text}){
                            $title=$c_ogdl->{text};
                        }
                        my $sizestr;
                        if($c_ogdl->{size}=~/(\d+),\s*(\d+),\s*(\d+),\s*(\d+)/){
                            my ($x, $y, $w, $h)=($1, $2, $3, $4);
                            $sizestr="$x, $y, $w, $h";
                        }
                        my $cname="PUSHBUTTON";
                        if($c_ogdl->{default}){
                            $cname="DEFPUSHBUTTON";
                        }
                        push @$out, "$indent$cname \"$title\", $name, $sizestr";
                    }
                    elsif($name=~/^text_/){
                        resource_define($name, "ctrl");
                        my $title=$name;
                        if($c_ogdl->{title}){
                            $title=$c_ogdl->{title};
                        }
                        elsif($c_ogdl->{text}){
                            $title=$c_ogdl->{text};
                        }
                        my $sizestr;
                        if($c_ogdl->{size}=~/(\d+),\s*(\d+),\s*(\d+),\s*(\d+)/){
                            my ($x, $y, $w, $h)=($1, $2, $3, $4);
                            $sizestr="$x, $y, $w, $h";
                        }
                        if(!$c_ogdl->{align}){
                            $c_ogdl->{align}=$ogdl->{text_align};
                        }
                        my $cname;
                        if($c_ogdl->{align}=~/center/){
                            $cname="CTEXT";
                        }
                        else{
                            $cname="LTEXT";
                        }
                        push @$out, "$indent$cname \"$title\", $name, $sizestr";
                    }
                    elsif($name=~/^list_/){
                        resource_define($name, "ctrl");
                        my $sizestr;
                        if($c_ogdl->{size}=~/(\d+),\s*(\d+),\s*(\d+),\s*(\d+)/){
                            my ($x, $y, $w, $h)=($1, $2, $3, $4);
                            $sizestr="$x, $y, $w, $h";
                        }
                        my $style=$c_ogdl->{style};
                        if($style){
                            $style=", $style";
                        }
                        my $cname="LISTBOX";
                        if(!$c_ogdl->{style}){
                            $c_ogdl->{style}=$ogdl->{list_style};
                        }
                        push @$out, "$indent$cname $name, $sizestr$style";
                    }
                    elsif($name=~/^control_/){
                        resource_define($name, "ctrl");
                        my $cname="CONTROL";
                        my $sizestr;
                        if($c_ogdl->{size}=~/(\d+),\s*(\d+),\s*(\d+),\s*(\d+)/){
                            my ($x, $y, $w, $h)=($1, $2, $3, $4);
                            $sizestr="$x, $y, $w, $h";
                        }
                        my $style=$c_ogdl->{style};
                        if($style){
                            $style=", $style";
                        }
                        my $text=$c_ogdl->{text};
                        my $class=$c_ogdl->{class};
                        push @$out, "$indent$cname \"$text\", $name, \"$class\", $sizestr$style";
                    }
                }
            }
        }
        push @$out, "END";
        return 1;
    }
}
sub dumpout {
    my ($f, $out, $pagetype)=@_;
    my $dump={out=>$out,f=>$f};
    my $pagename=$page->{pagename};
    my $outdir=$page->{outdir};
    my $res_h="$pagename-res.h";
    print "  --> [$outdir/$res_h]\n";
    open Out, ">$outdir/$res_h";
    foreach my $id (@res_id_list){
        print Out "#define $id $res_id_hash{$id}\n";
    }
    close Out;
    unshift @$out, "#include \"$res_h\"\n";
    unshift @$out, "\n";
    MyDef::dumpout::dumpout($dump);
}
sub single_block {
    my ($t1, $t2, $scope)=@_;
    push @$out, "$t1";
    push @$out, "INDENT";
    push @$out, "BLOCK";
    push @$out, "DEDENT";
    push @$out, "$t2";
    if($scope){
        return "NEWBLOCK-$scope";
    }
    else{
        return "NEWBLOCK";
    }
}
sub single_block_pre_post {
    my ($pre, $post, $scope)=@_;
    if($pre){
        push @$out, @$pre;
    }
    push @$out, "BLOCK";
    if($post){
        push @$out, @$post;
    }
    if($scope){
        return "NEWBLOCK-$scope";
    }
    else{
        return "NEWBLOCK";
    }
}
my %type_hash=(IDM=>"menu", IDC=>"ctrl", IDA=>"accl");
sub resource_define {
    my ($param, $type)=@_;
    my ($name, $val, $step)=split /,\s*/, $param;
    if($val=~/(0x.+)/){
        $val=hex($1);
    }
    if($step=~/(0x.+)/){
        $step=hex($1);
    }
    if(!$type){
        if($name=~/^(IDM|IDA|IDC)_/){
            $type=$type_hash{$1};
        }
        else{
            $type="other";
        }
    }
    if(!$id_base{$type}){
        $id_base{$type}=0x100;
        $id_step{$type}=1;
    }
    if($val){
        $id_base{$type}=$val;
    }
    if($step){
        $id_step{$type}=$step;
    }
    $val=sprintf("0x%x", $id_base{$type});
    if($name=~/_DUMMY$/i){
        MyDef::compileutil::set_current_macro($name, $val);
    }
    elsif(!$res_id_hash{$name}){
        $res_id_hash{$name}=$val;
        push @res_id_list, $name;
    }
    $id_base{$type}+=$id_step{$type};
}
sub resource_define_range {
    my ($param, $type)=@_;
    if(!$type){
        $type="other";
    }
    if($param=~/(\w+)\s+-+\s*(\d+)/){
        my ($name, $cnt)=($1, $2);
        if(!$res_id_hash{$name}){
            $res_id_hash{$name}=1;
            $res_id_hash{$name}=sprintf("0x%x", $id_base{$type});
            $res_id_hash{"$name\_COUNT"}=$cnt;
            $res_id_hash{"$name\_STEP"}=sprintf("0x%x", $id_step{$type});
            push @res_id_list, $name, "$name\_COUNT", "$name\_STEP";
            $id_base{$type}+=$id_step{$type}*$cnt;
        }
    }
}
sub ogdl_menu_rc {
    my ($ogdl, $level)=@_;
    $level++;
    my $ogdl_list=$ogdl->{_list};
    foreach my $item (@$ogdl_list){
        if(ref($item) eq "HASH"){
            my $name=$item->{_name};
            my $sub_list=$item->{_list};
            if(@$sub_list){
                push @$out, "    " x $level . "POPUP \"$name\"";
                push @$out, "    " x $level . "{";
                ogdl_menu_rc($item, $level);
                push @$out, "    " x $level . "}";
            }
            elsif($name =~/^menu/i){
                my $reserve=$item->{reserve};
                if($reserve){
                    resource_define_range($reserve, "menu");
                }
            }
            else{
                resource_define($name, "menu");
                if(!$item->{disable}){
                    my $text=$item->{text};
                    push @$out, "    " x $level . "MENUITEM \"$text\" $name";
                }
            }
        }
    }
}
1;
