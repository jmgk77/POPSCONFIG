#!/usr/bin/perl

use warnings;
use strict;

use Compress::Zlib;
use JSON;

use Text::Autoformat;

die "usage: $0 <input file> <input file> <input file> ...\n"
  unless @ARGV;

my %games;

if ( -e 'popsconf.dat' ) {
    local $/ = undef;
    open( my $fh, '<', 'popsconf.dat' );
    binmode($fh);
    my $x = from_json( uncompress(<$fh>) );
    %games = %$x;
    close($fh);
}

foreach (@ARGV) {
    open( my $fh, '<', $_ );
    my @content = <$fh>;
    close($fh);

    my $id;
    my $name;

    foreach (@content) {
        s/\s+/ /g;
        s/^\s+//;
        s/\s+$//;
        next unless $_;

        s/(\w{4})\-(\d{3})(\d{2})/$1\_$2\.$3/;

        /(\w{4}_\d{3}\.\d{2})\s*(.*)/;
        $id = $1;
        $name = $2 if $2;

        $name = autoformat( $name, { case => 'highlight' } );
        chomp($name);
        chomp($name);

        if ($id) {
            print "$id\t$name\n";
            $games{$id} = $name;
        }
    }
    print scalar keys %games;

}

open( my $fh, '>', 'popsconf.dat' );
binmode($fh);
print $fh compress( to_json( \%games ) );
close($fh);
