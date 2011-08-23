#!/usr/bin/env ruby

require "test/unit"
require "AdduserLDAP"
require 'stringio'
require 'FakeLDAP'

$config_data = Hash.new

def YAML.load_file(filename)
  $config_data = {
    "server" => "ldap.odd-e.com", 
    "port" => 10389,
    "basedn" => "ou=People,dc=odd-e,dc=com",
    "ssl" => "true",
    "starttls" => "false",
    "gidnumber_default" => "30000",
    "loginshell_default" => "/bin/bash",
    "homedir_base" => "/var/rhome/",
    "rdn" => "uid",
    "add_group" => "true",
    "groupdn" => "ou=Groups,dc=odd-e,dc=com"
    }
  $config_data
end

class TestCredentialsDirectory < Test::Unit::TestCase
  def setup
    $o_stdin = $stdin
    $o_stdout = $stdout
    $stdin = StringIO.new
    $stdout = StringIO.new
    $terminal = HighLine.new($stdin, $stdout)
    
    @fakeLDAP = FakeLDAP.new
    
    @password = "password\n"
    $stdin.string = @password

    @HIGHEST_UID_NUMBER = 5000
    @TEST_USER_NAME = "test_user"

    @default_file = "config.yml"
    @arguments = ["-f", "Test User", "-D", "uid=admin,ou=system", @TEST_USER_NAME]
  end

  def teardown
    $stdin = $o_stdin
    $stdout = $o_stdout
  end

  def test_user_does_not_exist
    @cli = AdduserLDAP::CLI.new(@default_file, @arguments, @fakeLDAP)

    assert_equal(false, @cli.find("boo"))
  end

  def __test_group_does_not_exist
    @cli = AdduserLDAP::CLI.new(@default_file, @arguments, @fakeLDAP)

    assert_equal(false, @cli.findgroup("boo"))
  end

  def add_dummy_user
    dummyUser = Entry.new
    dummyUser.records["uidNumber"] = @HIGHEST_UID_NUMBER
    dummyUser.records["uid"] = "dummy"
    @fakeLDAP.users[0] = dummyUser
  end
  
  def test_user_exists
    @cli = AdduserLDAP::CLI.new(@default_file, @arguments, @fakeLDAP)
    add_dummy_user
    
    assert_equal(true, @cli.find("dummy"))
  end

  def test_retrieve_next_available_uidNumber
    @config = AdduserLDAP::Config.new(@default_file, @arguments)
    @user = AdduserLDAP::User.new(@config, @fakeLDAP)
    add_dummy_user
    
    assert_equal(@HIGHEST_UID_NUMBER + 1, @user.highest_uidnumber)
  end

  def add_user
    $stdin.string += "1\n"
    $stdin.string += "pass\n"
    $stdin.string += "pass\n"
    $stdin.string += "y\n"
    @cli.adduser
  end
  
  def test_add_user
    @cli = AdduserLDAP::CLI.new(@default_file, @arguments, @fakeLDAP)
    add_dummy_user

    add_user
    
    assert_equal(true, @cli.find(@TEST_USER_NAME))
  end

  def __test_add_group
    @cli = AdduserLDAP::CLI.new(@default_file, @arguments, @fakeLDAP)
    add_dummy_user

    add_user

    assert_equal(true, @cli.findgroup(@TEST_USER_NAME))
  end
end