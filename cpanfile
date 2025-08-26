requires 'perl', '5.020';
requires 'App::Cmd';
requires 'Moo';
requires 'namespace::clean';
requires 'Path::Tiny';
requires 'Net::SSH2';
requires 'Carp';

on 'test' => sub {
    requires 'Test2::Suite';
    requires 'Test::MockModule';
    requires 'Test::Exception';
};

on 'develop' => sub {
    requires 'Perl::Critic';
    requires 'Perl::Tidy';
};
