
use strict;
use Test::More 'no_plan';

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

        # filename, no formstate, die_on_bad_parms => 0
        eval { $t = $self->load_tmpl('t/tmpl/no_form_state.html', die_on_bad_params => 0); };
        ok(!$@, 'loaded template okay (filename, no formstate, die_on_bad_params = 0)');
        is($t->output, "foo:\n", 'template output okay (filename, no formstate, die_on_bad_params = 0)');
        $t->param('foo', '17');
        is($t->output, "foo:17\n", 'template output okay (filename, no formstate, die_on_bad_params = 0, param set)');

        # filename, no formstate, default die_on_bad_parms => 1
        eval { $t = $self->load_tmpl('t/tmpl/no_form_state.html'); };
        ok(!$@, 'loaded template okay (filename, no formstate, default to die_on_bad_params = 1)') or diag "error: $@\n"; 
        is($t->output, "foo:\n", 'template output okay (filename, no formstate, default to die_on_bad_params = 1)');
        $t->param('foo', '23');
        is($t->output, "foo:23\n", 'template output okay (filename, no formstate, default to die_on_bad_params = 1, param set)');

        # filename, no formstate, explicit die_on_bad_parms => 1
        eval { $t = $self->load_tmpl('t/tmpl/no_form_state.html', die_on_bad_params => 1); };
        ok(!$@, 'loaded template okay (filename, no formstate, die_on_bad_params = 1)');
        is($t->output, "foo:\n", 'template output okay (filename, no formstate, die_on_bad_params = 1)');
        $t->param('foo', '99');
        is($t->output, "foo:99\n", 'template output okay (filename, no formstate, die_on_bad_params = 1, param set)');

        # scallarref, no formstate, explicit die_on_bad_parms => 1
        my $template_string = "wonka:<tmpl_var wonka>";
        eval { $t = $self->load_tmpl(\$template_string, die_on_bad_params => 1); } or diag "error: $@\n";
        ok(!$@, 'loaded template okay (scalarref, no formstate, die_on_bad_params = 1)');
        is($t->output, "wonka:", 'template output okay (scalarref, no formstate, die_on_bad_params = 1)');
        $t->param('wonka', 'wily');
        is($t->output, "wonka:wily", 'template output okay (scalarref, no formstate, die_on_bad_params = 1, param set)');

        # glob, no formstate, explicit die_on_bad_parms => 1
        open my $fh, '<', 't/tmpl/no_form_state.html' or die "could not open template file: $!\n";
        eval { $t = $self->load_tmpl($fh, die_on_bad_params => 1); } or diag "error: $@\n";
        ok(!$@, 'loaded template okay (glob, no formstate, die_on_bad_params = 1)');
        is($t->output, "foo:\n", 'template output okay (glob, no formstate, die_on_bad_params = 1)');
        $t->param('foo', 'froo-froo');
        is($t->output, "foo:froo-froo\n", 'template output okay (glob, no formstate, die_on_bad_params = 1, param set)');

        # filename, with formstate, explicit die_on_bad_parms => 1
        eval { $t = $self->load_tmpl('t/tmpl/basic.html', die_on_bad_params => 1); };
        ok(!$@, 'loaded template okay (filename, with formstate, die_on_bad_params = 1)');
        is($t->output, "$Storage_Name:$Storage_Hash", 'template output okay (filename, with formstate, die_on_bad_params = 1)');

        # scallarref, with formstate, explicit die_on_bad_parms => 1
        my $template_string = "$Storage_Name:<tmpl_var $Storage_Name>";
        eval { $t = $self->load_tmpl(\$template_string, die_on_bad_params => 1); } or diag "error: $@\n";
        ok(!$@, 'loaded template okay (scalarref, with formstate, die_on_bad_params = 1)');
        is($t->output, "$Storage_Name:$Storage_Hash", 'template output okay (scalarref, with formstate, die_on_bad_params = 1)');

        # glob, with formstate, explicit die_on_bad_parms => 1
        open my $fh, '<', 't/tmpl/basic.html' or die "could not open template file: $!\n";
        eval { $t = $self->load_tmpl($fh, die_on_bad_params => 1); } or diag "error: $@\n";
        ok(!$@, 'loaded template okay (glob, with formstate, die_on_bad_params = 1)');
        is($t->output, "$Storage_Name:$Storage_Hash", 'template output okay (glob, with formstate, die_on_bad_params = 1)');



    }
}


WebApp1->new->run;

my $query = CGI->new;
$query->param($Storage_Name, $Storage_Hash);

unlink File::Spec->catfile('t', $CGI::Session::Driver::file::FileName);



