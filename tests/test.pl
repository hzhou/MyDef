$ENV{MYDEFLIB}="../MyDef/deflib";
$ENV{PERL5LIB}="../MyDef/blib/lib";

my $yellow="\033[33;1m";
my $normal="\033[0m";
my $f=$ARGV[0];
if($f=~/([a-z0-9]+)_.*\.def$/){
    system "perl ../MyDef/script/mydef_page.pl $f -m$1 -oout";
    chdir "out";
    if($1 eq "c"){
	print "$yellow*** Compiling test.c ***$normal\n";
	system "gcc -o a.out test.c";
	if(-f "a.out"){
	    print "$yellow*** Testing a.out ***$normal\n";
	    system "./a.out";
	}
    }
    elsif($1 eq "xs"){
	if(!-d "test_xs"){
	    print "$yellow*** Setting up h2xs ***$normal\n";
	    system "h2xs -n test_xs"; 
	}
	system "cp test_xs.xs test_xs/";
	chdir "test_xs";
	print "$yellow*** Compiling out.xs ***$normal\n";
	system "perl Makefile.PL";
	system "make";

	print "$yellow*** Testing out.pm ***$normal\n";
	use lib "./blib/arch/auto/test_xs";
	require "blib/lib/test_xs.pm";
	test_xs::test();
    }
    elsif($1 eq "win32"){
	if(!-d "test_win32"){
	    print "$yellow*** Setting up for microsoft visual studio ***$normal\n";
	    mkdir "test_win32";
	    open Out, ">test_win32/make.bat";
	    print Out "cl test.c user32.lib gdi32.lib comdlg32.lib\n";
	    close Out;
	}
	system "cp test.c test_win32/";
    }
    elsif($1 eq "general"){
    }
    elsif($1 eq "php"){
	print "$yellow*** Dumpt test.php ***$normal\n";
	system "cat test.php"
    }
    else{
	print "unknown module [$1]\n";
    }
}
