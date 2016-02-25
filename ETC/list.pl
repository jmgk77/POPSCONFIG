#!/usr/bin/perl

use warnings;
use strict;

use Compress::Zlib;
use JSON;

my %games;

if ( -e 'popsconf.dat' ) {
    local $/ = undef;
    open( my $fh, '<', 'popsconf.dat' );
    binmode($fh);
    my $x = from_json( uncompress(<$fh>) );
    %games = %$x;
    close($fh);

    foreach ( keys %games ) {
        print "$_\t$games{$_}\n";
    }
    print scalar keys %games;
}
else { die "popsconf.dat not found!\n"; }
