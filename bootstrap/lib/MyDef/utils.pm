use strict;
package MyDef::utils;
sub proper_split {
    my ($param) = @_;
    my @tlist;
    if($param eq "0"){
        return (0);
    }
    elsif(!$param){
        return @tlist;
    }
    my @closure_stack;
    my $t;
    while(1){
        if($param=~/\G$/gc){
            last;
        }
        elsif($param=~/\G(\s+)/gc){
            if($t or @closure_stack){
                $t.=$1;
            }
            else{
            }
        }
        elsif($param=~/\G(,)/gc){
            if(@closure_stack){
                $t.=$1;
            }
            else{
                push @tlist, $t;
                undef $t;
            }
        }
        elsif($param=~/\G([^"'\(\[\{\)\]\},]+)/gc){
            $t.=$1;
        }
        elsif($param=~/\G("([^"\\]|\\.)*")/gc){
            $t.=$1;
        }
        elsif($param=~/\G('([^'\\]|\\.)*')/gc){
            $t.=$1;
        }
        elsif($param=~/\G([\(\[\{])/gc){
            $t.=$1;
            push @closure_stack, $1;
        }
        elsif($param=~/\G([\)\]\}])/gc){
            $t.=$1;
            if(@closure_stack){
                my $match;
                if($1 eq ')'){
                    $match='(';
                }
                elsif($1 eq ']'){
                    $match='[';
                }
                elsif($1 eq '}'){
                    $match='{';
                }
                my $pos=-1;
                for(my $i=0; $i <@closure_stack; $i++){
                    if($match==$closure_stack[$i]){
                        $pos=$i;
                    }
                }
                if($pos>=0){
                    splice(@closure_stack, $pos);
                }
                else{
                    warn "proper_split: unbalanced [$param]\n";
                }
            }
        }
        elsif($param=~/\G(.)/gc){
            my $curfile=MyDef::compileutil::curfile_curline();
            print "[$curfile]proper_split: unmatched $1 [$param]\n";
            $t.=$1;
        }
    }
    if($t){
        $t=~s/\s+$//;
    }
    if($t or @tlist){
        push @tlist, $t;
    }
    return @tlist;
}

sub expand_macro {
    my ($line, $sub) = @_;
    my @paren_stack;
    my $segs=[];
    while(1){
        if($line=~/\G$/gc){
            last;
        }
        elsif($line=~/\G\$\(/gc){
            if(@$segs && substr($segs->[-1], -1, 1) eq "\\"){
                if(!@paren_stack){
                    push @$segs, "\$(";
                }
                else{
                    push @$segs, "\$";
                    push @paren_stack, $segs;
                    $segs=[];
                    push @paren_stack, "(";
                }
            }
            else{
                push @paren_stack, $segs;
                $segs=[];
                push @paren_stack, "\$\(";
            }
        }
        elsif(!@paren_stack){
            if($line=~/\G([^\$]|\$(?!\())+/gc){
                push @$segs, $&;
            }
        }
        else{
            if($line=~/\G\(/gc){
                push @paren_stack, $segs;
                $segs=[];
                push @paren_stack, "(";
            }
            elsif($line=~/\G\)/gc){
                my $t=join('', @$segs);
                my $open=pop @paren_stack;
                $segs=pop @paren_stack;
                if($open eq "(" or $t!~/^\w/){
                    push @$segs, "($t)";
                }
                else{
                    push @$segs, $sub->($t);
                }
            }
            elsif($line=~/\G([^\$()]|\$(?!\())+/gc){
                push @$segs, $&;
            }
        }
    }
    return join('', @$segs);
}

sub uniq_name {
    my ($name, $hash) = @_;
    if(!$hash->{$name}){
        return $name;
    }
    else{
        my $i=2;
        if($name=~/[0-9_]/){
            $name.="_";
        }
        while($hash->{"$name$i"}){
            $i++;
        }
        return "$name$i";
    }
}

1;
