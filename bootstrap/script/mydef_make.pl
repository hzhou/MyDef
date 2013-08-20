#!/usr/bin/perl
use strict;
my @master_config;
my $module="www";
my %module_type=(php=>"php", perl=>"pl", www=>"html", xs=>"xs", win32=>"c", c=>"c", apple=>"m", js=>"js", general=>"txt", glsl=>"glsl");
my %macros;
my @include_folders;
my $config_outputdir;
my $config_outputdir_make=0;
my $script=$0;
my $nosub=0;
if($ARGV[0] eq 'nosub'){
    shift @ARGV;
    $nosub=1;
}
my @master_config;
if(-d $ARGV[0]){
    my $d=$ARGV[0];
    open In, "config";
    @master_config=<In>;
    close In;
    chdir $d or die "can't chdir $d\n";
}
if(!-f "config"){
    open Out, ">config" or die "Can't write config\n";
    if(@master_config){
        foreach my $l (@master_config){
            if($l=~/^include_path:\s*(\S+)/){
                my $t=$1;
                my @t=split /:/, $t;
                my @tt;
                push @tt, "..";
                foreach my $s (@t){
                    if($s!~/^\//){
                        push @tt, "../$s";
                    }
                    else{
                        push @tt, $s;
                    }
                }
                print Out "include_path: ", join(":", @tt), "\n";
            }
            else{
                print Out $l;
            }
        }
    }
    else{
        $config_outputdir=prompt("Please enter the path to compile into:");
        print Out "output_dir: $config_outputdir\n";
        $module=prompt("Please enter module type [www]:");
        if(!$module){$module="www";};
        print Out "module: $module\n";
    }
    close Out;
}
open In, "config";
while(<In>){
    if(/module:\s+(\w+)/){
        $module=$1;
    }
    elsif(/output_(dir|path): (\S+)/){
        $config_outputdir=$2;
    }
    elsif(/^include_path:\s*(\S+)/){
        my $t=$1;
        @include_folders=split /:/, $t;
    }
    elsif(/^macro_(\w+):\s*(.*\S)/){
        $macros{$1}=$2;
    }
}
close In;
if($ENV{MYDEFLIB}){
    push @include_folders, $ENV{MYDEFLIB};
}
print STDERR "    output_path: $config_outputdir\n";
my @make_folders;
my %h_copylist;
if(-f "copylist"){
    open In, "copylist";
    my $location;
    while(my $l=<In>){
        if($l=~/^(\S*):\s*(.*)/){
            $location=$1;
            $l=$2;
        }
        if($l){
            my @tlist=split /\s+/, $l;
            foreach my $t (@tlist){
                $t=~s/^\s+//;
                $t=~s/\s+$//;
                if(-f $t){
                    $h_copylist{$t}=$location;
                }
            }
        }
    }
    close In;
}
my @files;
my @allfiles=glob("*");
foreach my $f (@allfiles){
    if($f=~/.def$/){
        push @files, $f;
    }
    elsif(-d $f){
        if(-e "$f/skipmake"){
            print "    Skip folder $f\n";
        }
        elsif($f =~ /^(cmp|bootstrap|old|tests|macros_.*)$/){
            print "    Skip folder $f\n";
        }
        elsif($f eq $config_outputdir and -f "$f/Makefile"){
            $config_outputdir_make = 1;
        }
        else{
            my @t=glob("$f/*.def");
            if(@t){
                print "$script $f ... \n";
                system("$script $f")==0 or die "Failed to spawn sub make: $?\n";
            }
            if(-f "$f/Makefile"){
                push @make_folders, $f;
            }
        }
    }
}
my %h_def;
my %h_page;
my %folder;
my @extrafiles;
while(my $f=pop @files){
    my @page_list;
    my $page;
    my $output_path;
    if(!$h_def{$f} or $h_def{$f} == 1){
        my $deplist=[];
        $h_def{$f}=$deplist;
        my $inpage=0;
        open In, $f or warn "Can't open $f\n";
        while(<In>){
            if($inpage){
                if(/^\s*output_dir: (\S+)/){
                    my $dir=expand_macros($1);
                    if($dir !~/^\// and $output_path){
                        $dir=$output_path."/".$dir;
                    }
                    $page->{output_dir}=$dir;
                    my $tlist=$folder{$dir};
                    if($tlist){
                        push @$tlist, "$f-$page->{page}";
                    }
                    else{
                        $folder{$dir}=["$f-$page->{page}"];
                    }
                    $page->{in_var}=$dir;
                }
                elsif(/^\s*\$include\s+(\S*) and $module ne "c"/){
                    $page->{include}->{$1}=1;
                }
                elsif(/^\s*type: (\w+)/){
                    $page->{type}=$1;
                }
                elsif(/^\s*module:\s*(\w+)/){
                    $page->{module}=$1;
                }
                elsif(/^\s*depend:\s+(.*)/){
                    $page->{depend}=$1;
                }
                elsif(/^\S/){
                    $inpage=0;
                }
            }
            if(!$inpage){
                if(/^include:?\s*(\S+\.def)/){
                    my $f=$1;
                    if(! -f $f){
                        foreach my $d (@include_folders){
                            if(-f "$d/$f"){
                                $f="$d/$f";
                                last;
                            }
                        }
                    }
                    push @$deplist, $f;
                    if(!$h_def{$f}){
                        push @files, $f;
                        $h_def{$f}=1;
                    }
                }
                elsif(/^page: .*\$\d.*/){
                    $inpage=1;
                    $page={};
                    push @page_list, $page;
                }
                elsif(/^page: (\w+)/){
                    $inpage=1;
                    $page={};
                    push @page_list, $page;
                    $page->{page}=$1;
                    $page->{def}=$f;
                    $page->{include}={};
                    my $key="$f-$1";
                    while($h_page{$key}){
                        $key.='1';
                    }
                    $h_page{$key}=$page;
                }
                elsif(/^output_dir: (\S+)/){
                    $output_path=$1;
                }
            }
        }
        close In;
        if($output_path){
            foreach my $page (@page_list){
                if(!$page->{output_dir}){
                    $page->{output_dir}=$output_path;
                }
            }
        }
    }
}
while(my ($p, $h) = each %h_page){
    if(!$h->{type}){
        my $t_module=$module;
        if($h->{module}){
            $t_module=$h->{module};
        }
        $h->{type}=$module_type{$t_module};
    }
    if(!$h->{in_var}){
        $h->{in_var}="toproot";
        if($folder{toproot}){
            my $tlist=$folder{toproot};
            push @$tlist, $p;
        }
        else{
            $folder{toproot}=[$p];
        }
    }
    $h->{path}=$h->{page};
    if($h->{output_dir}){
        $h->{path}=$h->{output_dir}."/".$h->{path};
    }
    if($config_outputdir and $h->{path}!~/^\//){
        $h->{path}=$config_outputdir."/".$h->{path};
    }
    if($h->{type}){
        $h->{path}.=".$h->{type}";
    }
}
while(my ($f, $l) = each %h_def){
    my %track;
    foreach my $t (@$l){
        $track{$t}=1;
    }
    my $j=0;
    while($j<@$l){
        my $t=$l->[$j];
        my $ll=$h_def{$t};
        foreach my $tt (@$ll){
            if(!$track{$tt}){
                $track{$tt}=1;
                push @$l, $tt;
            }
        }
        $j++;
    }
}
open Out, ">Makefile" or die "Can't write Makefile\n";
print Out "MakePage=mydef_page.pl\n";
print Out "\n";
my %var_hash;
my @tlist;
while(my ($f, $l) = each %folder){
    my $name;
    if($f=~/.*\/(.*)/){
        $name=uc($1);
    }
    else{
        $name=uc($f);
    }
    if(!$name){
        $name="ROOT";
    }
    if($var_hash{$name}){
        my $j=2;
        while($var_hash{"$name$j"}){$j++;};
        $name="$name$j";
    }
    $var_hash{$name}=1;
    push @tlist, "\${$name}";
    print Out "$name=";
    foreach my $p (@$l){
        print Out $h_page{$p}->{path}, " ";
    }
    print Out "\n";
}
if(%h_copylist){
    print Out "COPY=";
    while( my ($f, $l) = each %h_copylist){
        my $sep="/";
        if($l){$sep="/$l/"};
        if($f=~/(.+)\/(.+)/){
            print Out $config_outputdir, $sep, $2, " ";
        }
        else{
            print Out $config_outputdir, $sep, $f, " ";
        }
    }
    print Out "\n";
    push @tlist, "\${COPY}";
}
print Out "\n";
if($config_outputdir_make){
    print Out "$config_outputdir: all\n";
    print Out "\tmake -C $config_outputdir\n";
}
print Out "all: ", join(" ", @tlist, @make_folders),;
print Out "\n\n";
if($config_outputdir_make){
    print Out "install: $config_outputdir\n";
    print Out "\tmake -C $config_outputdir install\n";
}
if(%h_copylist){
    while( my ($f, $l) = each %h_copylist){
        my $sep="/";
        if($l){$sep="/$l/"};
        if($f=~/(.+)\/(.+)/){
            print Out $config_outputdir, "$sep$2: $f\n";
            print Out "\t cp $f $config_outputdir$sep$2\n";
        }
        else{
            print Out $config_outputdir, "/$l/$f: templates/$f\n";
            print Out "\t cp templates/$f $config_outputdir/$l/$f\n";
        }
    }
    print Out "\n";
}
while(my ($p, $h)=each %h_page){
    my $def=$h->{def};
    my $inc=$h->{include};
    my $inc_dep=join(" ", keys %$inc);
    my $extra_dep=$h->{depend};
    if($h->{path}){
        my @t;
        my $l=$h_def{$def};
        foreach my $tt (@$l){
            if(-f $tt){
                push @t, $tt;
            }
        }
        print Out $h->{path}, ": ", $def, " ", join(" ", @t), " $inc_dep $extra_dep\n";
        if($h->{module} and ($h->{module}ne $module)){
            print Out "\t\${MakePage} -m$h->{module} \$< \$\@\n";
        }
        else{
            print Out "\t\${MakePage} \$< \$\@\n";
        }
        print Out "\n";
    }
}
if(@make_folders){
    foreach my $f (@make_folders){
        if(!$nosub){
            print Out "$f: force_look\n";
            print Out "\t cd $f; make\n";
            print Out "\n";
        }
    }
    print Out "force_look:\n\ttrue\n";
}
close Out;
if($config_outputdir){
    if($module eq "win32"){
        if(!-d $config_outputdir){
            mkdir $config_outputdir;
        }
        if((-d $config_outputdir) and (!-f "$config_outputdir/make.bat")){
            print "Create win32 $config_outputdir/make.bat\n";
            open Out, ">$config_outputdir/make.bat";
            if($folder{toproot}){
                my $tlist=$folder{toproot};
                my $page=$h_page{$tlist->[0]};
                my $name=$page->{path};
                if($page->{path}=~/.*\/(.*)\.c/){
                    $name=$1;
                }
                print Out "cl $name.c user32.lib\r\n";
            }
            close Out;
        }
    }
    if(($module eq "perl" or $module eq "xs") and !-d $config_outputdir){
        if($config_outputdir=~/^\w[0-9a-zA-Z_\-]*$/){
            my $name=$config_outputdir;
            $name=~s/-/::/g;
            if($module eq "perl"){
                my $pm_count=0;
                while(my ($p, $h) = each %h_page){
                    if($h->{type} eq "pm"){
                        $pm_count++;
                    }
                }
                if($pm_count>0){
                    print "Running h2xs ... ...\n";
                    system "h2xs -X $config_outputdir";
                }
            }
            else{
                print "Running h2xs ... ...\n";
                system "h2xs -n $config_outputdir";
            }
        }
    }
}
if($config_outputdir){
    if(!-d $config_outputdir){
        print "Create output folder $config_outputdir ...\n";
        mkdir $config_outputdir;
    }
}
else{
    $config_outputdir=".";
}
foreach my $f (keys(%folder)){
    if($f=~/toproot|ROOT/){
        next;
    }
    if($f !~/^\//){
        $f=$config_outputdir."/".$f;
    }
    if(!-d $f){
        print "Create output folder $f ...\n";
        system "mkdir -p $f";
    }
}
sub prompt {
    my $msg=shift;
    while(1){
        print "$msg\n";
        my $t=<STDIN>;
        chomp $t;
        return $t if $t;
        if($msg=~/\[.*\]: $/){
            return "";
        }
    }
}
sub expand_macros {
    my $t=shift;
    if($t=~/\$\((\w+)\)/){
        if($macros{$1}){
            $t=$`.$macros{$1}.$';
        }
        else{
            die "Unknown Macro in $t\n";
        }
    }
    return $t;
}
