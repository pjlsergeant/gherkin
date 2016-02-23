#!/usr/bin/env perl
use strict;
use warnings;
use CPAN::Changes;
use Config::INI::Reader;

my $this_version
    = Config::INI::Reader->read_file('dist.ini')->{'_'}->{'version'};

# Combine Gherkin project changes with CPAN releases
my @changes;

open( my $parent_changelog_fh, '<', '../CHANGELOG.md' )
    || die "Can't open [../CHANGELOG.md]";
my $parent = join '', (<$parent_changelog_fh>);
close $parent_changelog_fh;

# Kill the releases and contributor metadata
$parent =~ s/<!-- Releases .+//s;

my @parent_releases = split( /^## /m, $parent );

my $newest_parent;

for my $release (@parent_releases) {
    next
        unless $release
        =~ s/^\[?(\d+\.\d)+\.(\d+)\]? - (\d{4}-\d{2}-\d{2})\s*\n//;
    my ( $major_versions, $minor_version, $date ) = ( $1, $2, $3 );

    my $local_version
        = sprintf( "%s.%02d00", $major_versions, $minor_version );
    $newest_parent ||= $local_version;

    my $rel = CPAN::Changes::Release->new(
        version => $local_version,
        date    => $date,
    );
    $rel->add_changes(
        "This entry is a placeholder for an upstream release of Gherkin. No " .
        "CPAN module with this version number was released. The first " .
        "corresponding CPAN version is: " .
        substr( $local_version, 0, 6 ) . "01"
    );

    my @groups = split(/^### /m, $release);
    shift( @groups ); # Empty leading group;
    for my $group ( @groups ) {
        $group =~ s/(.+)\n//;
        my $name = $1;
        my @change_items = split(/^\* /m, $group);
        shift( @change_items ); # Empty leading change
        next unless @change_items;
        # Trim trailing spaces
        $_ =~ s/[\s\n]+$// for @change_items;
        $rel->add_changes( { group => $name }, @change_items );
    }

    push( @changes, $rel );
}

die "Couldn't properly parse parent ../CHANGELOG.md"
    unless @changes > 3;

# Check that our version number is sane
die "Current version number [$this_version] should be a small increment " .
    "larger than the most recent parent version [$newest_parent]"
    unless (
        ( substr( $this_version, 0, 6 ) eq substr( $newest_parent, 0, 6 )) &&
        ( substr( $this_version, 6, 2 ) >  substr( $newest_parent, 6, 2 ) )
    );

# Read our CPAN-only changes
my $cpan_change_file = CPAN::Changes->load( 'CPAN-ONLY-CHANGES' );
$cpan_change_file->add_release( @changes );
$cpan_change_file->preamble(
    'Revision history for perl module Gherkin.pm, and the upstream Gherkin project'
);

print $cpan_change_file->serialize;
