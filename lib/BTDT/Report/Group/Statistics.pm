use warnings;
use strict;

=head1 NAME

BTDT::Report::Group::Statistics

=head1 DESCRIPTION

Generates a bunch of interesting statistics for a group

=cut

package BTDT::Report::Group::Statistics;
use base qw/BTDT::Report::Group/;

=head1 METHODS

=head2 _get_metrics

=cut

sub _get_metrics {
    my $self    = shift;
    my $group   = $self->group;
    my $GID     = $group->id;

    my $base = "group_id = $GID";

    my $completed   = $self->pg_timestamp_in_timezone('completed_at');
    my $created     = $self->pg_timestamp_in_timezone('created');

    my %counts = (
        ontime  => "$base and date_trunc('day', $completed) <= due and completed_at is not null and due is not null and date_part('year', completed_at) != 1970",
        late    => "$base and date_trunc('day', $completed) > due and completed_at is not null and due is not null and date_part('year', completed_at) != 1970",
        all         => $base,
        due         => "$base and due is not null",
        unowned     => "$base and owner_id=" . BTDT::CurrentUser->nobody->id,
        never       => "$base and will_complete='f'",
    );

    my %sql = (
        completion_time     => "select avg(date_part('epoch', age($completed, $created))) from tasks where $base and completed_at is not null and created is not null and date_part('year', completed_at) != 1970",
        time_left_ontime    => "select avg(date_part('epoch', age(due, date_trunc('day', $completed)))) from tasks where $base and completed_at is not null and due is not null and date_part('year', completed_at) != 1970 and date_trunc('day', $completed) <= due;",
        time_left_all       => "select avg(date_part('epoch', age(due, date_trunc('day', $completed)))) from tasks where $base and completed_at is not null and due is not null and date_part('year', completed_at) != 1970",
    );

    my $results = { count => {}, average => {} };

    for my $query ( keys %counts ) {
        $results->{count}{$query} = $self->count(
            table => 'tasks',
            query => $counts{$query}
        );
    }

    for my $query ( keys %sql ) {
        my $rv = $self->_handle->simple_query( $sql{$query} );
        $results->{average}{$query} = shift @{shift @{ $rv->fetchall_arrayref }};
    }

    $self->results( $results );
}

1;
