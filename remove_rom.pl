#!/usr/bin/perl -w

$file = 'invaders-master.dsk';
open FILE, "<$file" and binmode FILE or die "$file: $!\n";
read FILE, $data='', -s $file;
close FILE;

$file = 'disk.base';
open FILE, ">$file" and binmode FILE or die "$file: $!\n";
print FILE substr $data, 0, 819200-8192;
close FILE;
