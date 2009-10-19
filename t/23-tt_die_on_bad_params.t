
use strict;

my $CAP_TT_Available;
BEGIN {
    eval {
       require CGI::Application::Plugin::TT;
    };
    if (!$@) {
        $CAP_TT_Available = 1;
    }
    use Test::More;
    if ($CAP_TT_Available) {
        Test::More->import('no_plan');
    }
    else {
        Test::More->import('skip_all' => 'CGI::Application::Plugin::TT not installed');
    }
}



$ENV{'CGI_APP_RETURN_ONLY'} = 1;

use CGI::Session;
use CGI::Session::Driver::file;

use File::Spec;

$CGI::Session::Driver::file::FileName = 'session.dat';

my $Session_ID;
my $Storage_Name = 'cap_form_state';
my $Storage_Hash;

{
    package WebApp1;
    use CGI::Application;

    use vars qw(@ISA);
    BEGIN { @ISA = qw(CGI::Application); }

    use CGI::Application::Plugin::Session;
    use CGI::Application::Plugin::FormState;
    require CGI::Application::Plugin::TT;
    CGI::Application::Plugin::TT->import;

    use Test::More;

    sub setup {
        my $self = shift;

        $self->run_modes(['start']);

        $self->session_config(
            CGI_SESSION_OPTIONS => [ "driver:File", undef, { Directory => 't' } ],
        );
        $Session_ID = $self->session->id;
        $self->session->param('foo', 42);
        is($self->session->param('foo'), 42, '[webapp1] new session initialized');
    }
    sub start {
        my $self = shift;

        my @keys = sort $self->form_state->param;
        ok(eq_array(\@keys, []), '[webapp2] form_state keys (1)');

        # Store some parameters
        $self->form_state->param('name' =>   'Road Runner');
        is($self->form_state->param('name'), 'Road Runner',  '[webapp1] form_state: name');

        @keys = sort $self->form_state->param;
        ok(eq_array(\@keys, ['name']), '[webapp2] form_state keys (2)');

        $self->form_state->clear_params;
        is($self->form_state->param('name'), undef,          '[webapp1] form_state: name (cleared)');

        @keys = sort $self->form_state->param;
        ok(eq_array(\@keys, []), '[webapp2] form_state keys (3)');

        $self->form_state->param('name' =>   'Bugs Bunny');
        $self->form_state->param('occupation' => 'Having Fun');

        # Store some other parameters via hashref
        $self->form_state->param({
            'name2'      => 'Wile E. Coyote',
            'occupation' => 'Cartoon Character',
        });

        @keys = sort $self->form_state->param;
        ok(eq_array(\@keys, ['name', 'name2', 'occupation']), '[webapp2] form_state keys (4)');

        is($self->form_state->param('name'),        'Bugs Bunny',        '[webapp1] form_state: name');
        is($self->form_state->param('name2'),       'Wile E. Coyote',    '[webapp1] form_state: name2');
        is($self->form_state->param('occupation'),  'Cartoon Character', '[webapp1] form_state: occupation');
        
        my $session_key = 'form_state_cap_form_state_' . $self->form_state->id;
        is($session_key, $self->form_state->session_key, 'session key');
        is($self->form_state->name, 'cap_form_state',    'name');
        $Storage_Hash = $self->form_state->id;

        my $t;

        my $expected_text = 
             qq{This is a Template Toolkit Template.  Some value: 999\n}
             .
             qq{$Storage_Name:$Storage_Hash\n}
             .
             qq{Just for fun, we'll include some HTML::Template syntax in here as well: <tmpl_var pogo>\n};

        my $output = $self->tt_process('t/tmpl/template.tmpl', { foo => 999 } );

        is $$output, $expected_text, "TT passes the die_on_bad_params test #1\n";
        
        $expected_text = 
             qq{This is a Template Toolkit Template.  Some value: 997\n}
             .
             qq{$Storage_Name:$Storage_Hash\n}
             .
             qq{Just for fun, we'll include some HTML::Template syntax in here as well: <tmpl_var pogo>\n};


        $output = $self->tt_process('t/tmpl/template.tmpl', { foo => 997 } );

        is $$output, $expected_text, "TT passes the die_on_bad_params test #2\n";
    }
}


WebApp1->new->run;

my $query = CGI->new;
$query->param($Storage_Name, $Storage_Hash);

unlink File::Spec->catfile('t', $CGI::Session::Driver::file::FileName);



