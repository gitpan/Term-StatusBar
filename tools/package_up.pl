#!/usr/bin/perl

  my $ver = "1.00";
  `./build_manifest.pl`;

  open FILE, "../MANIFEST";
  my $str;

  for (<FILE>){
      chomp;
      $str .= "./Term-StatusBar-$ver/$_ ";
  }

  `tar -C ../.. -zcf Term-StatusBar-$ver.tar.gz $str`;
  `mv Term-StatusBar-$ver.tar.gz ../`;
  close FILE;
