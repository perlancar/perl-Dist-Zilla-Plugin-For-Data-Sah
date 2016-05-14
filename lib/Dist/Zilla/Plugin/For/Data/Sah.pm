package Dist::Zilla::Plugin::For::Data::Sah;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Package::MoreUtil qw(list_package_contents);

use Moose;
use namespace::autoclean;

with (
    'Dist::Zilla::Role::FileMunger',
    'Dist::Zilla::Role::FileFinderUser' => {
        default_finders => [':InstallModules'],
    },
);

sub munge_files {
    no strict 'refs';

    my $self = shift;

    for my $file (@{ $self->found_files }) {
        unless ($file->isa("Dist::Zilla::File::OnDisk")) {
            $self->log_debug(["skipping %s: not an ondisk file, currently generated file is assumed to be OK", $file->name]);
            return;
        }
        my $file_name = $file->name;
        my $file_content = $file->content;
        if ($file_name =~ m!^lib/((.+)\.pm)$!) {
            my $package_pm = $1;
            my $package = $2; $package =~ s!/!::!g;

            if ($package =~ /^Data::Sah::Type::(.+)/) {
                my $type = $1;
                {
                    local @INC = ("lib", @INC);
                    require $package_pm;
                }

                my $pkg_contents = { list_package_contents($package) };
                my @clauses;
                for (sort keys %$pkg_contents) {
                    next unless /^clause_(.+)/;
                    push @clauses, $1;
                }

                for my $clause (@clauses) {
                    my $meth = "clausemeta_$clause";
                    my $clausemeta = $package->$meth;
                    my $sch = $clausemeta->{arg} or next;

                    # check that schema is already normalized
                    {
                        $self->log_debug(["checking schema for arg of clause '%s' (type %s) ...", $clause, $type]);
                        require Data::Dump;
                        require Data::Sah::Normalize;
                        require Text::Diff;
                        my $nsch = Data::Sah::Normalize::normalize_schema($sch);
                        my $sch_dmp  = Data::Dump::dump($sch);
                        my $nsch_dmp = Data::Dump::dump($nsch);
                        last if $sch_dmp eq $nsch_dmp;
                        my $diff = Text::Diff::diff(\$sch_dmp, \$nsch_dmp);
                        $self->log_fatal("Schema for arg of clause '$clause' is not normalized, below is the dump diff (- is current, + is normalized): " . $diff);
                    }
                } # for clause
            } # Data::Sah::Type::*
        } # lib/
    } # for $file
}

__PACKAGE__->meta->make_immutable;
1;
# ABSTRACT: Plugin for building Data-Sah distribution

=for Pod::Coverage .+

=head1 SYNOPSIS

In F<dist.ini>:

 [For::Data::Sah]


=head1 DESCRIPTION

This plugin is to be used when building C<Data-Sah> distribution (see
L<Data::Sah>). Currently it does the following:

=over

=item * For C<lib/Data/Sah/Type/*.pm>, check that schema specified in each clause's C<arg> is normalized

=back


=head1 SEE ALSO

L<Data::Sah>