my $install_dir=$ENV{MYDEFLIB};
if (!$install_dir){
    die "Missing environment variable MYDEFLIB\n"
}

if (!-d $install_dir){
    mkdir $install_dir or die "Can't mkdir $install_dir\n";
}

chdir "deflib" or die "Can't chdir deflib\n";

my @files=glob("*");

my @defs;
my @dirs;
foreach my $f(@files){
    if($f=~/\.def$/){
	push @defs, $f;
    }
    elsif(-d $f){
	push @dirs, $f;
    }
}
foreach my $d(@dirs){
    my @files=glob("$d/*.def");
    if(@files){
	if(!-d "$install_dir/$d"){
	    mkdir "$install_dir/$d" or die "Can't mkdir $install_dir/$d";
	}
	foreach my $f(@files){
	    push @defs, $f;
	}
    }
}

foreach my $def (@defs){
    my $dst="$install_dir/$def";
    if(!-e $dst or -M $def < -M $dst){
        print "$def -> $dst\n";
        system "cp $def $dst\n";
    }
}

