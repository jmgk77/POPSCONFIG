#!/usr/bin/perl

#Configure POPS game files
#v1: get ID, rename VCD, make xx.??.elf, create game config directory, move old game config directory content,
#    handle multidisk virtual VMC path, create OPL config, download cover and background. (05/10/2015)
#v2: idlist has more games, updated id-extract tool, download more art. (09/10/2015)

use warnings;
use strict;

use Getopt::Std;
use Config::General;

use File::Copy;

use JSON;
use Compress::Zlib;

use WWW::Mechanize;
use LWP::ConnCache;

use Encode::Byte;

my %multidisk;
my %idlist;

#commandline options
my %opt;

my $letra = 'A';

MAIN: {
    #como usar...
    warn "Configure POPS game files\n";
    warn "v2 - JMGK 2015\n\n";

    #processa opcoes de linha de comando
    usage() unless getopts( 'vlwzg:mdop:i:ca:', \%opt );

    #carrega opções do disco
    my $script = $0;
    $script =~ s/\.pl$/.cfg/;
    $script =~ s/\.exe$/.cfg/;
    if ( ( $opt{z} ) && ( -e $script ) ) {

        #load config
        my $conf = Config::General->new($script);
        %opt = $conf->getall;
    }

    #estão presentes os parametros essenciais
    usage() if ( !( $opt{i} ) );

    #what flavor of config developers are using today?
    my $conf_file = (
          $opt{g} == 1 ? 'conf_apps.cfg'
        : $opt{g} == 2 ? 'conf_pops.cfg'
        :                'conf_elm.cfg'
    ) if $opt{g};

    #define o nome do POPSTARTER
    if ( $opt{p} ) {
        die "POPSTARTER.ELF file not found: $opt{p}\n"
          unless -e $opt{p};
    }

    #programa para extrair ID (win/linux)
    my $getid = 'PSXGetId.EXE';
    die "Essential file not found: $getid\n" unless -e $getid;

    #carrega JSON comprimido com lista de ids e games
    die "Essential file not found: POPSCONF.DAT\n" unless -e "POPSCONF.DAT";
    if ( open( my $fh, '<', 'popsconf.dat' ) ) {
        local $/ = undef;
        binmode($fh);
        my $x = from_json( uncompress(<$fh>) );
        %idlist = %$x;
        close($fh);
    }
    else {
        die "Cant open POPSCONF.DAT\n";
    }

    #limpa conf velho
    unlink $conf_file if $opt{g};

    #estas opções ligam / desligam o switch d (criar pasta) sempre
    $opt{d} = 1 if $opt{m};
    $opt{d} = 1 if $opt{o};

    #enable art download if art path
    $opt{c} = 1 if $opt{a};

    #processa arquivos VCD
    my @files = glob("$opt{i}\\*");

    #@files = glob("$opt{i}//*") if $^O eq 'linux';
    foreach (@files) {
        next unless /VCD$/i;
        my $oldname = $_;

        #extrai ID e nome
        my $xz   = "$getid \"$oldname\"";
        my $id   = `$xz`;
        my $game = $idlist{$id};

        #achou id e game?
        if ( $id && $game ) {
            log_it("Processing game $game ($id)\n");

        }
        elsif ($id) {

            #achou so a ID?
            $game = $oldname;
            $game =~ s{.*\\}{};                    # removes path
            $game =~ s{\.[^.]+$}{};                # removes extension
            $game =~ s/^\w{4}_\d{3}\.\d{2}\.//;    #and remove fake ID
            log_it("Cant find $id game name - using $game\n");
        }
        else {
            #não achou nada?
            $game = $oldname;
            $game =~ s{.*\\}{};                    # removes path
            $game =~ s{\.[^.]+$}{};                # removes extension
            $game =~ s/^\w{4}_\d{3}\.\d{2}\.//;    #and remove fake ID

#cria rndnames em ordem alfabetica, para manter o VMCDIR de multidiscos sem ID (!?)
            $id = $letra++;
            for ( 0 .. 2 ) { $id .= chr( int( rand(25) + 65 ) ); }
            $id .= '_' . int( rand(899) + 100 ) . '.' . int( rand(89) + 10 );
            log_it(
"Can find game ID ($oldname) - Using random ID ($id) and $game\n"
            );
        }

        #gera nome correto
        my $name = "$id.$game";
        $name =~ s/\://g;

        #move VCD
        move( "$oldname", "$opt{i}\\$name.VCD" ) unless -e "$opt{i}\\$name.VCD";
        log_it("\tVCD renamed to $name.VCD\n");

        #copia POPSTARTER
        if ( $opt{p} ) {
            copy( $opt{p}, "$opt{i}\\xx.$name.ELF" );

            log_it("\tPOPSTARTER.ELF copied to xx.$name.ELF\n");
        }

        my $newdir = "$opt{i}\\$name";

        #move diretorio
        if ( $opt{o} ) {
            my $olddir = $oldname;
            $olddir =~ /(.+).VCD$/;
            $olddir = $1;
            move( $olddir, $newdir );
            log_it("\tOld game folder content moved\n");
        }

        #cria diretorio
        if ( $opt{d} ) {
            mkdir($newdir);
            log_it("\tGame folder created\n") unless $opt{o};

        }

        #se multidisco, cria VMCDIR.TXT com o primeiro disco
        if ( $opt{m} ) {
            if ( $name =~ /\[(\d)\]$/ ) {
                my $disk    = $1;
                my $newname = $game;
                $newname =~ s/\s*\[\d\]$//;
                if ( $disk == 1 ) {
                    $multidisk{$newname} = $name;
                    log_it("\tMultidisk found: disk 1 saved ($name)\n");
                }
                else {
                    open( my $file, '>', "$opt{i}\\$name\\VMCDIR.TXT" );
                    print $file "$multidisk{$newname}";
                    close($file);
                    log_it(
"\tMultidisk found: disk $disk used ($multidisk{$newname})\n"
                    );
                }
            }
        }

        #cria OPL POPS config
        if ( $opt{g} ) {
            open( my $file, '>>', $conf_file );
            print $file "$game=mass:/POPS/xx.$name.ELF\n";
            close($file);
            log_it(
                "\tSaved entry to $conf_file ($game=mass:/POPS/xx.$name.ELF)\n"
            );

        }

        #download arte do jogo
        if ( $opt{c} ) {
            $opt{a} = '.' unless $opt{a};
            my $ngame = $game;
            $ngame =~ s/\s*\[(\d)\]$//;

            #multidisk pega $id do primeiro!!!!
            #$ngame = $multidisk{$newname} if ( ( $1 > 1 ) && ($1) );

            #download
            log_it("\tDownloading ART for $ngame\n");
            psxdatacenter( $id, $name );

        }

    }
}

#baixa dados de http://www.psxdatacenter.com/
sub psxdatacenter {
    my $searchid = shift;
    my $savename = shift;

    #busca google images
    my $www = WWW::Mechanize->new( timeout => 30 );
    $www->conn_cache( LWP::ConnCache->new );

    #vai para area US/EU/JP
    $searchid =~ /^(\w{4}).+/;
    my $s =
        ( ( $1 eq "SLUS" ) || ( $1 eq "SCUS" ) ) ? 'ulist.html'
      : ( ( $1 eq "SLES" ) || ( $1 eq "SCES" ) ) ? 'plist.html'
      :                                            'jlist.html';
    $www->get("http://ns348841.ip-91-121-109.eu/psxdata/$s");

    #vai para a pagina do jogo
    $searchid =~ s/_/-/;
    $searchid =~ s/\.//;
    if ( $www->find_link( url_regex => qr/$searchid/i ) ) {
        $www->follow_link( url_regex => qr/$searchid/i );

        #id-F-ALL.jpg
        download_image(
            $www,
            $searchid . ".jpg",
            "$opt{a}\\xx.$savename.ELF_COV.JPG"
        );
        download_image( $www, "ss1.jpg", "$opt{a}\\xx.$savename.ELF_BG.JPG" );
        download_image( $www, "ss2.jpg", "$opt{a}\\xx.$savename.ELF_SCR.JPG" );
        download_image( $www, "ss3.jpg", "$opt{a}\\xx.$savename.ELF_SCR2.JPG" );
    }
    return;
}

sub download_image {
    my $www      = shift;
    my $searchid = shift;
    my $savename = shift;

    my $img = $www->find_image( url_regex => qr/$searchid/ );
    if ($img) {
        $www->get( $img->url );
        open( my $file, '>', $savename );
        binmode($file);
        print $file $www->content();
        close($file);
    }
    $www->back();
}

sub usage {
    print "USO: $0 <opcoes>";
    print '
        v=verbose
        l=log to file
        g=generate (1) conf_apps.cfg, (2) conf_pops.cfg, or (3) conf_elm.cfg
        m=multidisk handler (activate -d)
        d=create game directory
        o=move old game directory to new (activate -d)
        p=path to POPSTARTER.ELF
        i=path to game VCD images
        c=download disk cover
        a=path to ART folder in OPL
        z=load config file
        w=save config file        
';

    exit();
}

sub log_it {
    my $x = shift;
    print $x if $opt{v};

    if ( $opt{l} ) {
        my $y = localtime(time);
        open( my $z, '>>', "$0.log" );
        print $z "[$y] $x";
        close($z);
    }
    return;
}

sub END {

    #salva opções no disco
    if ( $opt{w} ) {
        my $script = $0;
        $script =~ s/\.pl$/.cfg/;
        $script =~ s/\.exe$/.cfg/;
        my $conf = Config::General->new();
        $conf->save_file( $script, \%opt );
        log_it("Config File saved\n");
    }
}

