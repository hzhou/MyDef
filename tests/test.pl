#!/usr/bin/perl
use strict;
$ENV{MYDEFLIB}="../deflib";
$ENV{PERL5LIB}="../MyDef/blib/lib";
if(!-d "out"){
    mkdir "out" or die "Can't mkdir out\n";
}
my $yellow="\033[33;1m";
my $normal="\033[0m";
my $f=$ARGV[0];
my @test_list;
open In, "$f" or die "Can't open $f.\n";
while(<In>){
    if(/^#\s*TEST:\s*(.*)/){
        push @test_list, $1;
    }
}
close In;
if($f=~/([a-z0-9]+)_.*\.def$/){
    my $module=$1;
    unlink "out/Makefile";
    my $cmd= "perl ../MyDef/script/mydef_page.pl $f -m$module -oout";
    print "$cmd \n";
    system $cmd;
    chdir "out";
    if($module eq "c"){
        print "$yellow*** Compiling test.c ***$normal\n";
        chdir "out";
        unlink "test";
        my $lib;
        open In, "test.c" or die "Can't open test.c.\n";
        while(<In>){
            if(/^\/\*\s*link: (.*)\*\//){
                $lib=$1;
            }
        }
        close In;
        my $cmd="gcc -g test.c $lib -o test";
        print "    $cmd\n";
        system $cmd;
        if(-f "test"){
            print "$yellow*** Testing output ***$normal\n";
            system "./test";
        }
    }
    elsif($module eq "xs"){
        if(!-d "test_xs"){
            print "$yellow*** Setting up h2xs ***$normal\n";
            system "h2xs -n test_xs";
        }
        system "cp test_xs.xs test_xs/";
        chdir "test_xs";
        print "$yellow*** Compiling out.xs ***$normal\n";
        system "rm -rf blib";
        system "perl Makefile.PL";
        system "make";
        if(@test_list){
            print "$yellow*** Testing out.pm ***$normal\n";
            use lib "./blib/arch/auto/test_xs";
            require "blib/lib/test_xs.pm";
            foreach my $t (@test_list){
                print "  $yellow* $t$normal\n";
                eval($t);
                warn $@ if $@;
            }
        }
    }
    elsif($module eq "win32"){
        if(!-d "test_win32"){
            print "$yellow*** Setting up for microsoft visual studio ***$normal\n";
            mkdir "test_win32";
            open Out, ">test_win32/make.bat";
            print Out "cl test.c user32.lib gdi32.lib comdlg32.lib\n";
            close Out;
        }
        system "cp test.c test_win32/";
        print "To continue, compile under windows in test_win32/ \n";
    }
    elsif($module eq "php"){
        print "$yellow*** Dump test.php ***$normal\n";
        system "cat test.php";
    }
    elsif($module eq "perl"){
        print "$yellow*** perl test.pl ***$normal\n";
        system "perl test.pl";
    }
    elsif($module eq "www"){
        print "$yellow*** Dumping test.html ***$normal\n";
        system "cat test.html";
    }
    else{
        print "Unhandled module type: [$module]\n";
    }
}
