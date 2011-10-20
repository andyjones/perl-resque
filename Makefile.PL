use inc::Module::Install;
  
# Define metadata
name           'Resque';
all_from       'lib/Resque.pm';
  
# Specific dependencies
requires       'Redis'                => '1.904';
requires       'JSON'                 => '0';
requires       'DateTime'             => '0';
requires       'Devel::StackTrace'    => '0';
requires       'Class::Accessor::Fast'=> '0';
requires       'Sys::Hostname'        => '0';
requires       'Time::HiRes'          => '0';

test_requires  'Test::More'  => '0.42';
no_index       'directory'   => '/lib/t';
  
WriteAll;
