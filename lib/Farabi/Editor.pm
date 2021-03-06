package Farabi::Editor;

# ABSTRACT: Controller
# VERSION

use Mojo::Base 'Mojolicious::Controller';
use Capture::Tiny qw(capture);
use IPC::Run qw( start pump finish timeout );
use Path::Tiny;
use Pod::Functions qw(%Type);
use Method::Signatures;

# The actions

my $file_menu  = '01.File';
my $edit_menu  = '02.Edit';
my $build_menu = '03.Build';
my $vcs_menu   = '04.VCS';
my $tools_menu = '05.Tools';
my $help_menu  = '06.Help';

my %actions = (
	'action-new-file' => {
		name  => 'New File - Alt+N',
		help  => "Opens a new file in an editor tab",
		menu  => $file_menu,
		order => 1,
	},

	#	'action-new-project' => {
	#		name  => 'New Project',
	#		help  => "Creates a new project using Module::Starter",
	#		menu  => $file_menu,
	#		order => 2,
	#	},
	'action-open-file' => {
		name  => 'Open File(s) - Alt+O',
		help  => "Opens one or more files in an editor tab",
		menu  => $file_menu,
		order => 3,
	},
	'action-save-file' => {
		name  => 'Save File - Alt+S',
		help  => "Saves the current file ",
		menu  => $file_menu,
		order => 4,
	},
	'action-close-file' => {
		name  => 'Close File - Alt+W',
		help  => "Closes the current open file",
		menu  => $file_menu,
		order => 5,
	},
	'action-close-all-files' => {
		name  => 'Close All Files',
		help  => "Closes all of the open files",
		menu  => $file_menu,
		order => 6,
	},
	'action-goto-line' => {
		name  => 'Goto Line - Alt+L',
		help  => 'A dialog to jump to the needed line',
		menu  => $edit_menu,
		order => 1,
	},
	'action-options' => {
		name  => 'Options',
		help  => 'Open the options dialog',
		menu  => $tools_menu,
		order => 1,
	},
	'action-run' => {
		name  => 'Run - Alt+Enter',
		help  => 'Run the current editor source file using the run dialog',
		menu  => $build_menu,
		order => 5,
	},
	'action-help' => {
		name  => 'Getting Started',
		help  => 'A quick getting started help dialog',
		menu  => $help_menu,
		order => 1,
	},

	#	'action-perl-doc' => {
	#		name  => 'Perl Documentation',
	#		help  => 'Opens the Perl help documentation dialog',
	#		menu  => $help_menu,
	#		order => 2,
	#	},
	'action-about' => {
		name  => 'About Farabi',
		help  => 'Opens an dialog about the current application',
		menu  => $help_menu,
		order => 3,
	},
);

method menus {
	my $menus = ();

	if ( $self->app->support_can_be_enabled('Perl::Critic') ) {
		$actions{'action-perl-critic'} = {
			name  => 'Perl Critic',
			help  => 'Run the Perl::Critic tool on the current editor tab',
			menu  => $tools_menu,
			order => 4,
		};
		$actions{'action-dump-ppi-tree'} = {
			name  => 'Dump the PPI tree',
			help  => "Dumps the PPI tree into the output pane",
			menu  => $tools_menu,
			order => 11,
		};
	}

	if ( $self->app->support_can_be_enabled('Perl::Tidy::Sweetened') ) {
		$actions{'action-perl-tidy'} = {
			name => 'Perl Tidy Sweetened',
			help =>
'Run the Perl::Tidy::Sweetened (perltidier) tool on the current editor tab',
			menu  => $tools_menu,
			order => 3,
		};
	}

	if ( $self->app->support_can_be_enabled('Perl::Strip') ) {
		$actions{'action-perl-strip'} = {
			name  => 'Perl Strip',
			help  => 'Run Perl::Strip on the current editor tab',
			menu  => $tools_menu,
			order => 5,
		};
	}

	if ( $self->app->support_can_be_enabled('Spellunker') ) {
		$actions{'action-spellunker'} = {
			name  => 'Spellunker',
			help  => "Checks current tab spelling using Spellunker",
			menu  => $tools_menu,
			order => 10,
		};
	}

	if ( $self->app->support_can_be_enabled('Code::CutNPaste') ) {
		$actions{'action-code-cutnpaste'} = {
			name  => 'Find Cut and Paste code...',
			help  => 'Finds any duplicate Perl code in the current lib folder',
			menu  => $tools_menu,
			order => 7,
		};
	}

	if ( $self->app->support_can_be_enabled('App::Midgen') ) {
		$actions{'action-midgen'} = {
			name => 'Find package dependencies (midgen)',
			help =>
'Find package dependencies in the current lib folder and outputs a sample Makefile DSL',
			menu  => $tools_menu,
			order => 7,
		};
	}

	if ( $self->app->support_can_be_enabled('Dist::Zilla')
		or defined File::Which::which('make') )
	{
		$actions{'action-project-build'} = {
			name => 'Build',
			help =>
"Runs 'dzil build' 'perl Makefile.PL && make' on the current project",
			menu  => $build_menu,
			order => 2,
		};
		$actions{'action-project-clean'} = {
			name  => 'Clean',
			help  => "Runs 'dzil clean' or 'make clean' on the current project",
			menu  => $build_menu,
			order => 2,
		};
		$actions{'action-project-test'} = {
			name  => 'Test',
			help  => "Runs 'dzil test' or 'make test' on the current project",
			menu  => $build_menu,
			order => 2,
		};
	}

	require File::Which;
	if ( defined File::Which::which('jshint') ) {
		$actions{'action-jshint'} = {
			name  => 'JSHint',
			help  => 'Run JSHint on the current editor tab',
			menu  => $tools_menu,
			order => 6,
		};
	}

	if ( defined File::Which::which('git') ) {
		$actions{'action-git-diff'} = {
			name  => 'git diff',
			help  => 'Show Git changes between commits',
			menu  => $vcs_menu,
			order => 8,
		};
		$actions{'action-git-log'} = {
			name  => 'git log',
			help  => 'Show Git commits',
			menu  => $vcs_menu,
			order => 8,
		};
		$actions{'action-git-status'} = {
			name  => 'git status',
			help  => 'Show Git status',
			menu  => $vcs_menu,
			order => 8,
		};
	}

	if ( defined File::Which::which('ack') ) {
		$actions{'action-ack'} = {
			name => 'Find in files (ack)',
			help =>
'Find the current selected text using Ack and displays results in the search tab',
			menu  => $tools_menu,
			order => 2,
		};
	}

	if ( defined File::Which::which('cpanm') ) {
		$actions{'action-cpanm'} = {
			name => 'Install CPAN module (cpanminus)',
			help =>
			  'Install the selected module via App::cpanminus (aka cpanm)',
			menu  => $tools_menu,
			order => 3,
		};
	}

	for my $name ( keys %actions ) {
		my $action = $actions{$name};
		my $menu   = $action->{menu};
		$menu = ucfirst($menu);

		$menus->{$menu} = [] unless defined $menus->{$menu};

		push @{ $menus->{$menu} },
		  {
			action => $name,
			name   => $action->{name},
			order  => $action->{order},
		  };

	}

	for my $name ( keys %$menus ) {
		my $menu = $menus->{$name};

		my @sorted = sort { $a->{order} <=> $b->{order} } @$menu;
		$menus->{$name} = \@sorted;
	}

	$menus;
}

# Taken from Padre::Plugin::PerlCritic
method perl_critic {
	my $source   = $self->param('source');
	my $severity = $self->param('severity');

	# Check source parameter
	if ( !defined $source ) {
		$self->app->log->warn('Undefined "source" parameter');
		return;
	}

	# Check severity parameter
	if ( !defined $severity ) {
		$self->app->log->warn('Undefined "severity" parameter');
		return;
	}

	# Hand off to Perl::Critic
	require Perl::Critic;
	my @violations =
	  Perl::Critic->new( -severity => $severity )->critique( \$source );

	my @results;
	for my $violation (@violations) {
		push @results,
		  {
			policy      => $violation->policy,
			line_number => $violation->line_number,
			description => $violation->description,
			explanation => $violation->explanation,
			diagnostics => $violation->diagnostics,
		  };
	}

	$self->render( json => \@results );
}

method _capture_cmd_output (Str $cmd, $opts, Str :$source, Str :$input) {
	require File::Temp;

	# Source is stored in a temporary file
	my $source_fh;
	if ( defined $source ) {
		$source_fh = File::Temp->new;
		print $source_fh $source;
		close $source_fh;
	}

	# Input is stored in a temporary file
	my $input_fh;
	if ( defined $input ) {
		$input_fh = File::Temp->new;
		print $input_fh $input;
		close $input_fh;
	}

	my ( $stdout, $stderr, $exit ) = capture {
		if ( defined $input_fh ) {

			if ( defined $source_fh ) {
				system( $cmd, @$opts, $source_fh->filename,
					"<" . $input_fh->filename );
			}
			else {
				system( $cmd, @$opts, "<" . $input_fh->filename );
			}
		}
		else {
			if ( defined $source_fh ) {
				system( $cmd, @$opts, $source_fh->filename );
			}
			else {
				system( $cmd, @$opts );
			}
		}
	};
	my $result = {
		stdout => $stdout,
		stderr => $stderr,
		'exit' => $exit >> 8,
	};

	return $result;
}

method run_perl {
	my $source = $self->param('source');
	my $input  = $self->param('input');

	my $o =
	  $self->_capture_cmd_output( $^X, [], source => $source, input => $input );

	$self->render( json => $o );
}

method run_perlbrew_exec {
	my $source = $self->param('source');
	my $input  = $self->param('input');

	my $o = $self->_capture_cmd_output(
		'perlbrew', [ 'exec', 'perl' ],
		source => $source,
		input  => $input
	);

	$self->render( json => $o );
}

# Taken from Padre::Plugin::PerlTidy
# TODO document it in 'SEE ALSO' POD section
method perl_tidy {
	my $source = $self->param('source');

	# Check 'source' parameter
	unless ( defined $source ) {
		$self->app->log->warn('Undefined "source" parameter');
		return;
	}

	my $o = $self->_capture_cmd_output(
		'perltidier',
		[ '-se', '-st' ],
		source => $source
	);

	$self->render( json => $o );
}

method _module_pod {
	my $filename = shift;

	$self->app->log->info("Opening '$filename'");
	my $pod = '';
	if ( open my $fh, '<', $filename ) {
		$pod = do { local $/ = <$fh> };
		close $fh;
	}
	else {
		$self->app->log->warn("Cannot open $filename");
	}

	return $pod;
}

# Convert Perl POD source to HTML
method pod2html {
	my $text  = $self->param('source') // '';
	my $style = $self->param('style')  // 'metacpan';

	$self->render( text => _pod2html( $text, $style ), format => 'html' );
}

func _pod2html ($text, $style) {

	require Pod::Simple::HTML;
	my $psx = Pod::Simple::HTML->new;

	#$psx->no_errata_section(1);
	#$psx->no_whining(1);
	$psx->output_string( \my $html );
	$psx->parse_string_document($text);

	my %stylesheets = (
		'cpan' =>
		  [ 'assets/podstyle/orig/cpan.css', 'assets/podstyle/cpan.css' ],
		'metacpan' => [
			'assets/podstyle/orig/metacpan.css',
			'assets/podstyle/metacpan/shCore.css',
			'assets/podstyle/metacpan/shThemeDefault.css',
			'assets/podstyle/metacpan.css'
		],
		'github' =>
		  [ 'assets/podstyle/orig/github.css', 'assets/podstyle/github.css' ],
		'none' => []
	);

	my $t = '';
	for my $style ( @{ $stylesheets{$style} } ) {
		$t .=
qq{<link class="pod-stylesheet" rel="stylesheet" type="text/css" href="$style">\n};
	}
	$html =~ s{(</head>)}{</head>$t$1};

	return $html;
}

method md2html {
	my $text = $self->param('text') // '';

	require Text::Markdown;
	my $m    = Text::Markdown->new;
	my $html = $m->markdown($text);

	$self->render( text => $html );
}

# Code borrowed from Padre::Plugin::Experimento - written by me :)
method pod_check {
	my $source = $self->param('source') // '';

	require Pod::Checker;
	require IO::String;

	my $checker = Pod::Checker->new;
	my $output  = '';
	$checker->parse_from_file( IO::String->new($source),
		IO::String->new($output) );

	my $num_errors   = $checker->num_errors;
	my $num_warnings = $checker->num_warnings;
	my @problems;

	say "$num_warnings, $num_errors";

	# Handle only errors/warnings. Forget about 'No POD in current document'
	if ( $num_errors != -1 and ( $num_errors != 0 or $num_warnings != 0 ) ) {
		for ( split /^/, $output ) {
			if (/^(.+?) at line (\d+) in file \S+$/) {
				push @problems,
				  {
					message => $1,
					line    => int($2),
				  };
			}
		}
	}

	$self->render( json => \@problems );
}

# Find a list of matched actions
method find_action {

	# Quote every special regex character
	my $query = quotemeta( $self->param('action') // '' );

	# Find matched actions
	my @matches;
	for my $action_id ( keys %actions ) {
		my $action      = $actions{$action_id};
		my $action_name = $action->{name};
		if ( $action_name =~ /^.*$query.*$/i ) {
			push @matches,
			  {
				id   => $action_id,
				name => $action_name,
				help => $action->{help},
			  };
		}
	}

	# Sort so that shorter matches appear first
	@matches = sort { $a->{name} cmp $b->{name} } @matches;

	# And return matches array reference
	$self->render( json => \@matches );
}

# Find a list of matches files
method find_file {

	# Quote every special regex character
	my $query = quotemeta( $self->param('filename') // '' );

	# Determine directory
	require Cwd;
	my $dir = $self->param('dir');
	if ( !$dir || $dir eq '' ) {
		$dir = Cwd::getcwd;
	}

	require File::Find::Rule;
	my $rule = File::Find::Rule->new;
	$rule->or(
		$rule->new->directory->name( 'CVS', '.svn', '.git', 'blib', '.build' )
		  ->prune->discard,
		$rule->new
	);

	$rule->file->name(qr/$query/i);
	my @files = $rule->in($dir);

	my @matches;
	for my $file (@files) {
		push @matches,
		  {
			id   => $file,
			name => path($file)->basename,
		  };
	}

	# Sort so that shorter matches appear first
	@matches = sort { $a->{name} cmp $b->{name} } @matches;

	my $MAX_RESULTS = 100;
	if ( scalar @files > $MAX_RESULTS ) {
		@matches = @matches[ 0 .. $MAX_RESULTS - 1 ];
	}

	# Return the matched file array reference
	$self->render( json => \@matches );
}

# Return the file contents or a failure string
method open_file {

	my $filename = $self->param('filename') // '';

	my %result = ();
	if ( open my $fh, '<', $filename ) {

		# Slurp the file contents
		local $/ = undef;
		$result{value} = <$fh>;
		close $fh;

		# Retrieve editor mode
		require Farabi::MIME;
		my $o = Farabi::MIME::find_editor_mode_and_mime_type($filename);
		$result{mode}      = $o->{mode};
		$result{mime_type} = $o->{mime_type};

		# Simplify filename
		$result{filename} = path($filename)->basename;

		# Add or update record file record
		$self->_add_or_update_recent_file_record($filename);

		# We're ok :)
		$result{ok} = 1;
	}
	else {
		# Error!
		$result{value} = "Could not open file: $filename";
		$result{ok}    = 0;
	}

	# Return the file contents or the error message
	$self->render( json => \%result );
}

# Add or update record file record
method _add_or_update_recent_file_record ($filename) {

	require DBIx::Simple;
	my $db_name = $self->app->db_name;
	my $db      = DBIx::Simple->connect("dbi:SQLite:dbname=$db_name");

	my $sql = <<'SQL';
SELECT id, name, datetime(last_used,'localtime')
FROM recent_list
WHERE name = ? and type = 'file'
SQL

	my ( $id, $name, $last_used ) = $db->query( $sql, $filename )->list;

	if ( defined $id ) {

		# Found recent file record, update last used timestamp;
		$db->query(
			q{UPDATE recent_list SET last_used = datetime('now') WHERE id = ?},
			$id
		);

		$self->app->log->info("Update '$filename' in recent_list");
	}
	else {
		# Not found... Add new recent file record
		$sql = <<'SQL';
INSERT INTO recent_list(name, type, last_used)
VALUES(?, 'file', datetime('now'))
SQL
		$db->query( $sql, $filename );

		$self->app->log->info("Add '$filename' to recent_list");
	}

	$db->disconnect;
}

# Save(s) the specified filename
method save_file {
	my $filename = $self->param('filename');
	my $source   = $self->param('source');

	# Define output and error strings
	my %result = ( err => '', );

	# Check filename parameter
	unless ($filename) {

		# The error
		$result{err} = "filename parameter is invalid";

		# Return the result
		$self->render( json => \%result );
		return;
	}

	# Check contents parameter
	unless ($source) {

		# The error
		$result{err} = "source parameter is invalid";

		# Return the result
		$self->render( json => \%result );
		return;
	}

	if ( open my $fh, ">", $filename ) {

		# Saving...
		print $fh $source;
		close $fh;
	}
	else {
		# Error: Cannot open the file for writing/saving
		$result{err} = "Cannot save $filename";
	}

	$self->render( json => \%result );
}

# Find duplicate Perl code in the current 'lib' folder
method code_cutnpaste {

	my $dirs = $self->param('dirs');

	my %result = (
		count  => 0,
		output => '',
		error  => '',
	);

	unless ($dirs) {

		# Return the error result
		$result{error} = "Error:\ndirs parameter is invalid";
		$self->render( json => \%result );
		return;
	}

	my @dirs;
	$dirs =~ s/^\s+|\s+$//g;
	if ( $dirs ne '' ) {

		# Extract search directories
		@dirs = split ',', $dirs;
	}

	my $cutnpaste;
	eval {
		# Create an cut-n-paste object
		require Code::CutNPaste;
		$cutnpaste = Code::CutNPaste->new(
			dirs         => [@dirs],
			renamed_vars => 1,
			renamed_subs => 1,
		);
	};
	if ($@) {

		# Return the error result
		$result{error} = "Code::CutNPaste validation error:\n" . $@;
		$self->render( json => \%result );
		return;
	}

	# Finds the duplicates
	my $duplicates = $cutnpaste->duplicates;

	# Construct the output
	my $output = '';
	foreach my $duplicate (@$duplicates) {
		my ( $left, $right ) = ( $duplicate->left, $duplicate->right );
		$output .=
		  sprintf <<'END', $left->file, $left->line, $right->file, $right->line;

	Possible duplicate code found
	Left:  %s line %d
	Right: %s line %d

END
		$output .= $duplicate->report;
	}

	# Returns the find duplicate perl code result
	$result{count}  = scalar @$duplicates;
	$result{output} = $output;

	$self->render( json => \%result );
}

# Dumps the PPI tree for the given source parameter
method dump_ppi_tree {

	my $source = $self->param('source');

	my %result = (
		output => '',
		error  => '',
	);

	# Make sure that the source parameter is not undefined
	unless ( defined $source ) {

		# Return the error JSON result
		$result{error} = "Error:\nSource parameter is undefined";
		$self->render( json => \%result );
		return;
	}

	# Load PPI at runtime
	require PPI;
	require PPI::Dumper;

	# Load a document
	my $module = PPI::Document->new( \$source );

	# No whitespace tokens
	$module->prune('PPI::Token::Whitespace');

	# Create the dumper
	my $dumper = PPI::Dumper->new($module);

	# Dump the document as a string
	$result{output} = $dumper->string;

	# Return the JSON result
	$self->render( json => \%result );
}

# Syntax check the provided source string
method syntax_check {
	my $source = $self->param('source');

	my $result = $self->_capture_cmd_output( "$^X", ["-c"], source => $source );

	require Parse::ErrorString::Perl;
	my $parser = Parse::ErrorString::Perl->new;
	my @errors = $parser->parse_string( $result->{stderr} );

	my @problems;
	foreach my $error (@errors) {
		push @problems,
		  {
			message => $error->message,
			file    => $error->file,
			line    => $error->line,
		  };
	}

	# Sort problems by line numerically
	@problems = sort { $a->{line} <=> $b->{line} } @problems;

	$self->render( json => \@problems );
}

# Create a project using Module::Starter
method create_project ($opt) {
	...;
}

method change_project_dir ($dir) {
	...;
}

method import_project {
	...;
}

# Run git 'diff|log" and return its output
method git {
	my $cmd = $self->param('cmd') // '';

	my %valid_cmds = ( 'diff' => 1, 'log' => 1, 'status' => 1 );
	my $o;
	if ( defined $valid_cmds{$cmd} ) {
		$o = $self->_capture_cmd_output( 'git', [$cmd] );
	}
	else {
		$o = {
			stdout => 'Unknown git command',
			stderr => '',
			'exit' => 0,
		};
	}

	$self->render( json => $o );
}

# Search files in your current project folder for a textual pattern
method ack {
	my $text = $self->param('text');

 #TODO needs more thought on how to secure it again --xyz-command or escaping...
 # WARNING at the moment this is not secure
	my $o = $self->_capture_cmd_output( 'ack',
		[ q{--literal}, q{--sort-files}, q{--match}, qq{$text} ] );

	$self->render( json => $o );
}

# Check requires & test_requires of your package for CPAN inclusion.
method midgen {

	my $o = $self->_capture_cmd_output( 'midgen', [] );

	# Remove ansi color sequences
	$o->{stdout} =~ s/\e\[[\d;]*[a-zA-Z]//g;
	$o->{stderr} =~ s/\e\[[\d;]*[a-zA-Z]//g;

	$self->render( json => $o );
}

# Install module XYZ via App::cpanminus
method cpanm {
	my $module = $self->param('module') // '';

	my $o = $self->_capture_cmd_output( 'cpanm', [$module] );

	$self->render( json => $o );
}

# Runs dzil or makefile build commands in the current project folder
method project {
	my $cmd = $self->param('cmd') // '';

	# Detect project type
	my $project_type = 'dzil';
	if ( -e 'dist.ini' ) {

		# Dist::Zilla (dzil) support
		$project_type = 'dzil';
	}
	elsif ( -e 'Makefile.PL' ) {

		# Module::Install or ExtUtils::MakeMaker project
		$project_type = 'make';
	}

	my %valid_cmds = ( 'build' => 1, 'test' => 1, 'clean' => 1 );
	my $o;
	if ( defined $valid_cmds{$cmd} ) {
		if ( $cmd eq 'build' ) {
			$o =
			  $self->_capture_cmd_output( $project_type,
				$project_type eq 'dzil' ? ['build'] : [] );
		}
		else {
			$o = $self->_capture_cmd_output( $project_type, [$cmd] );
		}
	}
	else {
		$o = {
			stdout => 'Unknown project command',
			stderr => '',
			'exit' => 0,
		};
	}

	$self->render( json => $o );
}

method perl_strip {
	my $source = $self->param('source');

	my %result = (
		error  => 1,
		source => '',
	);

	# Check 'source' parameter
	unless ( defined $source ) {
		$self->app->log->warn('Undefined "source" parameter');
		$self->render( json => \%result );
		return;
	}

	eval {
		require Perl::Strip;
		my $ps = Perl::Strip->new;
		$result{source} = $ps->strip($source);
	};

	$self->render( json => \%result );
}

method spellunker {
	my $text = $self->param('text');

	require Spellunker::Pod;
	my $spellunker = Spellunker::Pod->new();
	my @errors     = $spellunker->check_text($text);

	my @problems;
	foreach my $error (@errors) {
		push @problems,
		  {
			message => join( " ", @{ $error->[2] } ),
			,
			file => '-',
			line => $error->[0],
		  };
	}

	# Sort problems by line numerically
	@problems = sort { $a->{line} <=> $b->{line} } @problems;

	$self->render( json => \@problems );
}

method help {
	my $topic = $self->param('topic') // '';
	my $style = $self->param('style') // 'metacpan';

	if ( $topic eq '' ) {
		$self->render( text => "No help found" );
		return;
	}

	my @cmd;
	if ( $Type{$topic} ) {
		@cmd = ( '-f', $topic );
	}
	else {
		@cmd = ($topic);
	}

	my $result = $self->_capture_cmd_output( 'perldoc', [ '-T', '-u', @cmd ] );

	my $html = _pod2html( $result->{stdout}, $style );

	$self->render( text => $html );
}

# The default root handler
method default {

	# Stash the source parameter so it can be used inside the template
	$self->stash( source => scalar $self->param('source') );

	# Render template "editor/default.html.ep"
	$self->render;
}

method ping {
	$self->render( text => "pong" );
}

1;
