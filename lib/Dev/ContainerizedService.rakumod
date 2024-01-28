=begin pod

=head1 NAME

Dev::ContainerizedService - Uses containers to provide services (such as databases) to ease getting a local development environment set up

=head1 SYNOPSIS

=begin code :lang<raku>

use Dev::ContainerizedService;

=end code

=head1 DESCRIPTION

This module aims to ease the process of setting up services (such as
Postgres) for the purpose of having a local development environment
for Raku projects.  For example, one might have a Raku web application
that uses a database. In order to try out the application locally, a
database instance needs to be set up. Ideally this should be effortless
and also isolated.

As the name suggests, this module achieves its aims using containers.
It depends on nothing more than Raku and having a functioning C<docker>
installation.

=head1 Usage

=head2 Getting Started

Let's assume we have a web application that uses a Postgres database
and expects that the C<DB_CONN_INFO> environment variable will be
populated with a connection string.

To make a development environment configuration using this module,
we create a script C<devenv.raku>:

=begin code :lang<raku>

#!/usr/bin/env raku
use Dev::ContainerizedService;

service 'postgres', :tag<13.0>, -> (:$conninfo, *%) {
    env 'DB_CONN_INFO', $conninfo;
}

=end code

The C<service> function specifies the service ID, a Docker image tag,
and a block that should be called when the service is up and running.
The C<env> function, located in a service, specifies an environment
variable to be set.

We can then (assuming C<chmod +x devenv.raku>) use the script as follows:

=begin code

$ ./devenv.raku run raku -Ilib service.raku

=end code

This will:

=item 1. Pull the Postgres docker container if required

=item 2. Run the container, setting up a database user/password and
binding it to a free port

=item 3. Run C<raku -Ilib service.raku> with the C<DB_CONN_INFO>
environment variable set

When using the C<cro> development tool, one could do:

=begin code

$ ./devenv.raku run cro run

=end code

=head2 Additional Actions

The service block is run after the container is started (service
implementations include readiness checks). As well as - or instead
of - specifying environment variables to pass to the process, one
can write any Raku code there. For example, one could run database
migrations (in the case where it's desired to have them explicitly
applied to production, rather than having them applied at application
startup time).

=head2 Retaining data

By default, any created databases are not persisted once the C<run>
command is completed. To change this, alter the configuration file
to specify a project name (the name of your application) and call
C<store>:

=begin code :lang<raku>

#!/usr/bin/env raku
use Dev::ContainerizedService;

project 'my-app';
store;

service 'postgres', :tag<13.0>, -> (:$conninfo, *%) {
    env 'DB_CONN_INFO', $conninfo;
}

=end code

Now when using C<./devenv.raku run ...>, for services that support it,
Docker volume(s) will be created and the generated password(s) for
services will be saved (in your home directory). These will be reused
on subsequent runs.

To clean up this storage, use:

=begin code

$ ./devenv.raku delete

=end code

Which will remove any created volumes along with saved settings.

=head2 Showing produced configuration

When using storage, it is also possible to see the most recently passed
service settings for each service by using:

=begin code

$ ./devenv.raku show

=end code

The output looks like this:

=begin code

postgres
  conninfo: host=localhost port=29249 user=test password=xxlkC2MrOv4yJ3vP1V-pVI7 dbname=test
  dbname: test
  host: localhost
  password: xxlkC2MrOv4yJ3vP1V-pVI7
  port: 29249
  user: test

=end code

When used while C<run> is active, this is handy for obtainingi the
connection string information in order to connect to the database
using tools of your choice.

=head2 Tools

Some service specifications also come with a way to run related tools.
For example, the C<postgres> specification can run the C<psql> command
line client (using the version in the container, to be sure of server
compatibility), injecting the correct credentials. Thus:

=begin code

$ ./devenv.raku tool postgres client

=end code

Is sufficient to launch the client to look at the database. Note that
this only works when the service is running (so one would run it in
one terminal window, and then use the tool subcommand in another).

=head2 Multiple stores

Calling:

=begin code :lang<raku>

store;

=end code

Is equivalent to calling:

=begin code :lang<raku>

store 'default';

=end code

That is, it specifies the name of a default store. It is possible to
have multiple independent stores, which are crated using the
C<--store> argument before the C<run> subcommand:

=begin code

$ ./devenv.raku --store=bug42 run cro run

=end code

To see the created stores, use:

=begin code

$ ./devenv.raku stores

=end code

To show the produced service configuration for a particular store, use:

=begin code

$ ./devenv.raku --store=bug42 show

=end code

To use a tool against a particular store, use:

=begin code

$ ./devenv.raku --store=bug42 tool postgres client

=end code

To delete a particular store, rather than the default one, use:

=begin code

$ ./devenv.raku --store=bug42 delete

=end code

=head2 Multiple instances of a given service

One can have multiple instances of a given service. When doing this,
it is wise to assign them names (otherwise names like C<postgres-2>
will be generated, and this will not be too informative in C<show>
output):

=begin code :lang<raku>

service 'postgres', :tag<13.0>, :name<pg-products> -> (:$conninfo, *%) {
    env 'PRODUCT_DB_CONN_INFO', $conninfo;
}

service 'postgres', :tag<13.0>, :name<pg-billing> -> (:$conninfo, *%) {
    env 'BILLING_DB_CONN_INFO', $conninfo;
}

=end code

These names are used in the C<tool> subcommand:

=begin code

$ ./devenv.raku -tool pg-billing client

=end code

=head2 Is this magic?

Not really; the C<Dev::ContainerizedService> module exports a C<MAIN>
sub, which is how it gets to provide the program entrypoint.

=head1 Available Services

=head2 Postgres

Either obtain a connection string:

=begin code :lang<raku>

service 'postgres', :tag<13.0>, -> (:$conninfo, *%) {
    env 'DB_CONN_INFO', $conninfo;
}

=end code

Or the individual parts of the database connection details:

=begin code :lang<raku>

service 'postgres', :tag<13.0>, -> (:$host, :$port, :$user, :$password, :$dbname, *%) {
    env 'DB_HOST', $host;
    env 'DB_PORT', $port;
    env 'DB_USER', $user;
    env 'DB_PASS', $password;
    env 'DB_NAME', $dbname;
}

=end code

Postgres supports storage of the database between runs when C<store>
is used.

The C<client> tool is available, and runs the C<psql> client:

=begin code

$ ./devenv.raku tool postgres client

=end code

=head2 Redis

Obtain the host and port of the started instance:

=begin code :lang<raku>

service 'redis', :tag<7.0>, -> (:$host, :$port) {
    env 'REDIS_HOST', $host;
    env 'REDIS_PORT', $port;
}

=end code

Redis is currently always in-memory and will never be stored.

=head1 The service I want isn't here!

=item 1. Fork this repository.

=item 2. Add a module C<Dev::ContainerizedService::Spec::Foo>, and
in it write a class of the same name that does
C<Dev::ContainerizedService::Spec>. See the role's documentation as
well as other specs as an example

=item 3. Add a mapping to the C<constant %specs> in
C<Dev::ContainerizedService>

=item 4. Write a test to make sure it works

=item 5. Add an example to the documentation 

=item 6. Submit a pull request

=head1 Class / Methods reference

=end pod

use v6.d;
use Dev::ContainerizedService::Spec;
use Dev::ContainerizedService::Tool;
use JSON::Fast;

# Mapping of service names to the module name to require and (matching) class to use.
my constant %specs =
  'postgres' => 'Dev::ContainerizedService::Spec::Postgres',
  'redis' => 'Dev::ContainerizedService::Spec::Redis';

#| Details of a specified service.
my class Service {
    has Str $.name is required;
    has Str $.service-id is required;
    has Str $.image is required;
    has Dev::ContainerizedService::Spec $.spec is required;
    has Promise $.pull-promise is required;
    has &.setup is required;
    has %.env;

    method run-setup(--> Nil) {
        my $*D-CS-SERVICE = self;
        &!setup($!spec.service-data);
    }

    method add-env(Str $name, Str $value --> Nil) {
        %!env{$name} = $value;
    }
}

# Declared project name, if any.
my Str $project;

# Declared default storage key, if any.
my Str $default-store;

# Declared services.
my Service @services;

#| Declare a project name for the development configuration. This is required if
#| wanting to have persistent storage of the created services between runs.
sub project(Str $name --> Nil) is export {
    with $project {
        note "Already called `project` function; it can only be used once";
        exit 1;
    }
    else {
        $project = $name;
    }
}

#| Declare that we should store the service state that is produced (for example, by
#| having the data be on a persistent docker). Optionally provide a name for the
#| default store.
sub store(Str $name = 'default' --> Nil) is export {
    without $project {
        note "Must call the `project` function before using `store`";
        exit 1;
    }
    with $default-store {
        note "Already called `store` function; it can only be used once";
        exit 1;
    }
    else {
        $default-store = $name;
    }
}

#| Declare that a given development service is needed. The body block is run once the
#| service has been started, and can do any desired setup work or specify environment
#| variables to pass to the process that is run. A tag (for the container of the
#| service) can be specified, and the service can be given an explicit name (only
#| really important if one wishes to bring up, for example, two different Postgres
#| instances and have a clear way to refer to each one).
sub service(Str $service-id, &setup, Str :$tag, Str :$name, *%options) is export {
    # Resolve the service spec.
    my $spec-class = get-spec($service-id);

    # Figure out a name.
    my $base-name = $name // $service-id;
    my $chosen-name = $base-name;
    my $idx = 2;
    while @services.first(*.name eq $chosen-name) {
        $chosen-name = $base-name ~ '-' ~ $idx++;
    }

    # Instantiate the container specification.
    my Dev::ContainerizedService::Spec $spec = $spec-class.new(|%options);

    # Start pulling the container.
    my $image = $spec.docker-container ~ ":" ~ ($tag // $spec.default-docker-tag);
    my $pull-promise = start sink docker-pull-image($image);

    # Add service info to collected services.
    push @services, Service.new(:name($chosen-name), :$service-id, :$image, :$spec, :$pull-promise, :&setup);
}

#| Declare an environment variable be supplied to the process that is started.
sub env(Str $name, Str() $value --> Nil) is export {
    with $*D-CS-SERVICE {
        .add-env($name, $value);
    }
    else {
        die "Can only use 'env' in the scope of a 'service' block";
    }
}

#| Run a command in the containerized development environment.
multi sub MAIN('run', Str :$store = $default-store, *@command) is export {
    # Make sure we've completed pulling all services; if we have any errors, stop.
    await Promise.allof(@services.map(*.pull-promise));
    with @services.first(*.pull-promise.status == Broken) {
        note "Failed to pull container for service '{.service-id}':\n{.pull-promise.cause.message.indent(4)}";
        exit 1;
    }

    # If we have storage, then set the storage prefix and load any persisted settings.
    if $store {
        for @services -> Service $service {
            $service.spec.store-prefix = store-prefix($store, $service.name);
            my $settings-file = settings-file($store, $service.name());
            if $settings-file.e {
                $service.spec.load(from-json $settings-file.slurp);
            }
        }
    }

    react {
        # We'll keep track of running container processes.
        my class Container {
            has Str $.name is required;
            has Promise $.started is required;
            has Proc::Async $.container-process is required;
        }
        my Container @containers;

        # Start the container for each service.
        for @services.kv -> $idx, Service $service {
            my $name = "dev-service-$*PID-$idx";
            my $container-process = Proc::Async.new: 'docker', 'run', '-t', '--rm',
                    $service.spec.docker-options, '--name', $name, $service.image,
                    $service.spec.docker-command-and-arguments;
            my $started = Promise.new;
            @containers.push((Container.new(:$name, :$service, :$started, :$container-process)));
            whenever $container-process.ready {
                # If the container can't be started, give up with an error.
                QUIT {
                    default {
                        note "Failed to start '$service.service-id()': { .message }";
                        stop-services();
                        exit 1;
                    }
                }

                # Otherwise, wait for the service to be determined ready.
                whenever $service.spec.ready(:$name) {
                    $service.run-setup();
                    if $store {
                        my $settings-file = settings-file($store, $service.name);
                        $settings-file.spurt: to-json $service.spec.save;
                    }
                    $started.keep;
                    CATCH {
                        default {
                            note "An exception occurred in the service block for '$service.service-id()':\n{.gist.indent(4)}";
                            stop-services();
                            exit 1;
                        }
                    }
                }
            }
            $container-process.start;
        }

        # When containers are all started.
        whenever Promise.allof(@containers.map(*.started)) {
            # Form the environment.
            my %ENV = %*ENV;
            for flat @services.map(*.env.kv) -> $name, $value {
                %ENV{$name} = $value;
            }

            # Arguments given to us include the program name to run. Thus feed them directly into the
            # Proc::Async constructor, which uses the first as the program name.
            my $proc = Proc::Async.new(@command);
            whenever $proc.start(:%ENV) {
                stop-services();
                exit .exitcode;
            }
        }

        sub stop-services(--> Nil) {
            for @containers {
                .container-process.kill;
                try docker-stop .name;
            }
        }
    }
}

#| List stores for the project specified by this development environment script.
multi sub MAIN('stores') is export {
    ensure-stores-available();
    .say for project-dir().dir.grep(*.d).map(*.basename).sort;
}

#| Display the service data of the currently running or most recently run services,
#| optionally specifying the store name.
multi sub MAIN('show', Str :$store = $default-store) is export {
    ensure-stores-available();
    for @services -> Service $service {
        say $service.name;
        my $settings-file = settings-file($store, $service.name);
        if $settings-file.e {
            $service.spec.store-prefix = store-prefix($store, $service.name);
            $service.spec.load(from-json $settings-file.slurp);
            for $service.spec.service-data.sort(*.key) {
                say "  {.key}: {.value}";
            }
        }
        else {
            say "  Not run";
        }
    }
}

#| Run a tool for a service.
multi sub MAIN('tool', Str $service-name, Str $tool-name, *@extra-args, Str :$store = $default-store) {
    ensure-stores-available();
    with @services.first(*.name eq $service-name) -> Service $service {
        my $tool = $service.spec.tools.first(*.name eq $tool-name);
        if $tool ~~ Dev::ContainerizedService::Tool {
            my $settings-file = settings-file($store, $service.name);
            if $settings-file.e {
                $service.spec.store-prefix = store-prefix($store, $service.name);
                $service.spec.load(from-json $settings-file.slurp);
                my $tool-instance = $tool.new:
                        image => $service.image,
                        store-prefix => $service.spec.store-prefix,
                        service-data => $service.spec.service-data;
                $tool-instance.run(@extra-args);
            }
            else {
                note "Service '$service-name' has not yet been run for store '$store'; tools unavailable";
            }
        }
        elsif $service.spec.tools -> @tools {
            note "No such tool '$tool-name'; available: @tools.map(*.name).join(', ')";
            exit 1;
        }
        else {
            note "There are no tools available for $service-name";
            exit 1;
        }
    }
    else {
        note "No such service '$service-name'; available: @services.map(*.name).join(', ')";
        exit 1;
    }
}

#| Delete a store for this development environment script.
multi sub MAIN('delete', Str :$store = $default-store) {
    ensure-stores-available();
    for @services -> Service $service {
        my $settings-file = settings-file($store, $service.name);
        if $settings-file.e {
            $service.spec.store-prefix = store-prefix($store, $service.name);
            $service.spec.load(from-json $settings-file.slurp);
            $service.spec.cleanup();
            $settings-file.unlink;
        }
    }
}

sub ensure-stores-available(--> Nil) {
    without $project {
        note "This development environment script does not call `project`, so cannot use stores";
        exit 1;
    }
    without $default-store {
        note "This development environment script does not call `store`, so cannot use stores";
        exit 1;
    }
}

sub project-dir(--> IO::Path) {
    my $dir = $*HOME.add('.raku-dev-cs').add($project);
    $dir.mkdir unless $dir.d;
    return $dir
}

sub store-dir(Str $store --> IO::Path) {
    my $dir = project-dir.add($store);
    $dir.mkdir unless $dir.d;
    return $dir;
}

sub settings-file(Str $store, Str $service --> IO::Path) {
    store-dir($store).add($service)
}

sub store-prefix(Str $store, Str $service-name --> Str) {
    "$project-$store-$service-name-"
}

#| Look up the specification for a service of the given ID. Dies if it cannot be
#| found. Exported for modules building upon this one.
sub get-spec(Str $service-id --> Dev::ContainerizedService::Spec) is export(:get-spec) {
    with %specs{$service-id} -> $module {
        # Load the specification module.
        require ::($module);
        return ::($module);
    }
    else {
        die "No service specification for '$service-id'; available are: " ~
                %specs.keys.sort.join(", ")
    }
}

#| Tries to pull a docker image. Fails if it cannot. Exported for modules building upon
#| this one.
sub docker-pull-image(Str $image) is export(:docker) {
    my Str $error = '';
    react {
        my $proc = Proc::Async.new('docker', 'pull', $image);
        whenever $proc.stdout {}
        whenever $proc.stderr {
            $error ~= $_;
        }
        whenever $proc.start -> $result {
            if $result.exitcode != 0 {
                $error = "Exit code $result.exitcode()\n$error";
            }
            else {
                $error = Nil;
            }
        }
    }
    $error ?? fail($error) !! Nil
}

#| Sends the stop command to a docker container. Exported for modules building upon this one.
sub docker-stop(Str $name --> Nil) is export(:docker) {
    my $proc = Proc::Async.new('docker', 'stop', $name);
    .tap for $proc.stdout, $proc.stderr;
    try sink await $proc.start;
}

=begin pod

=head1 AUTHOR

Jonathan Worthington

=head1 COPYRIGHT AND LICENSE

Copyright 2022 - 2024 Jonathan Worthington

Copyright 2024 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
