use AnyEvent;
my $handler = sub {
    return sub {
        my $start_response = shift;
        warn "will wait 3 seconds before returning...";
        my $w; $w = AE::timer 3, 0, sub {
            warn "DFASDFASDF";
            undef $w;
        };
    }
};
