requires 'perl', '5.020';
requires 'App::Cmd';
requires 'Moo';
requires 'namespace::clean';
requires 'Path::Tiny';

on 'test' => sub {
    requires 'Test2::Suite';
    requires 'Test::MockModule';
};

on 'develop' => sub {
    requires 'Perl::Critic';
    requires 'Perl::Tidy';
};
