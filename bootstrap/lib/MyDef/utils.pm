use strict;
package MyDef::utils;
sub proper_split {
    my ($param)=@_;
    my @closure_stack;
    my @tlist;
    my $t;
    if(!$param){
        return @tlist;
    }
    while(1){
        if($param=~/\G(\s+)/gc){
            if(@closure_stack){
                $t.=$1;
            }
        }
        elsif($param=~/\G(,)/gc){
            if(@closure_stack){
                $t.=$1;
            }
            else{
                push @tlist, $t;
                $t="";
            }
        }
        elsif($param=~/\G([^"'\(\[\{\)\]\},]+)/gc){
            $t.=$1;
        }
        elsif($param=~/\G(['"])/gc){
            $t.=$1;
            if(!@closure_stack){
                push @closure_stack, $1;
            }
            elsif($closure_stack[-1] eq $1){
                pop @closure_stack;
            }
            elsif($closure_stack[-1] eq "'" or $closure_stack[-1] eq '"'){
            }
            else{
                push @closure_stack, $1;
            }
        }
        elsif($param=~/\G([\(\[\{])/gc){
            $t.=$1;
            if(!@closure_stack or $closure_stack[-1] ne "'" and $closure_stack[-1] ne '"'){
                push @closure_stack, $1;
            }
        }
        elsif($param=~/\G([\)\]\}])/gc){
            $t.=$1;
            if(@closure_stack and $closure_stack[-1] ne "'" and $closure_stack[-1] ne '"'){
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
                for(my $i=0;$i<@closure_stack;$i++){
                    if($match==$closure_stack[$i]){
                        $pos=$i;
                    }
                }
                if($pos>=0){
                    splice(@closure_stack, $pos);
                }
                else{
                }
            }
        }
        else{
            push @tlist, $t;
            return @tlist;
        }
    }
}
1;
