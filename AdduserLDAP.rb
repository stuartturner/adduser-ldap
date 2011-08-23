#!/usr/bin/env ruby
# Author:: Adam Jacob (<adam@hjksolutions.com>)
# Copyright:: Copyright (c) 2008 iLike Inc. and HJK Solutions, LLC
# License:: GNU General Public License version 2 or later
# 
# This program and entire repository is free software; you can
# redistribute it and/or modify it under the terms of the GNU 
# General Public License as published by the Free Software 
# Foundation; either version 2 of the License, or any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
# 

require 'rubygems'

module AdduserLDAP
  class Config
    require 'yaml'
    require 'optparse'
    
    attr_accessor :config
    attr_accessor :verbose
    
    def initialize(yamlfile, args)
      @config = Hash.new
      load_yaml(yamlfile) if yamlfile
      load_args(args) if args
      
      @config["server"]   ||= 'localhost'
      @config["port"]     ||= 389
      @config["starttls"] ||= false
      @config["rdn"]      ||= "uid"
      
      raise "You must specify a basedn!" unless @config["basedn"]
    end
    
    def [](arg)
      @config[arg]
    end
    
    private
      def load_yaml(yamlfile)
        @config = YAML.load_file(File.expand_path(yamlfile))
      end
    
      def load_args(args)
        
        loaded_config = nil
        
        opts = OptionParser.new do |opts|
          opts.banner = "Usage: #{$0} (config-file) (options) username"
                    
          opts.on("-l SERVER", "--ldapserver SERVER", "LDAP Server to use") do |l|
            @config["server"] = l
          end
          
          opts.on("-t", "--starttls", "Use starttls") do |t|
            @config["starttls"] = t
          end
          
          opts.on("-b BASEDN", "--basedn BASEDN", "Specify basedn for users") do |b|
            @config["basedn"] = b
          end
          
          opts.on("-r ATTR", "--rdn ATTR", "Specify the rdn for users") do |r|
            @config["rdn"] = r
          end
          
          opts.on("-d HOMEDIR", "--home HOMEDIR", "Specify this users homedir") do |d|
            @config["homedir"] = d
          end
          
          opts.on("-s SHELL", "--shell SHELL", "Specify this users shell") do |s|
            @config["shell"] = s
          end
          
          opts.on("-u UIDNUMBER", "--uid UIDNUMBER", "Specify the uid") do |u|
            @config["uid"] = u
          end
          
          opts.on("-g GIDNUMBER", "--gid GIDNUMBER", "Specify the gid") do |g|
            @config["gid"] = g
          end
          
          opts.on("-f FULLNAME", "--fullname FULLNAME", "Specify the users real name") do |f|
            @config["fullname"] = f
          end
          
          opts.on("-p PORT", "--port PORT", "Specify the LDAP Port number") do |p|
            @config["port"] = p.to_i
          end
          
          opts.on("-D BINDDN", "--binddn BINDDN", "Specify the DN to bind with") do |bdn|
            @config["binddn"] = bdn
          end
              
          opts.on_tail("-v", "--verbose", "Be verbose") do
            @verbose = true
          end
          
          opts.on_tail("-h", "--help", "Show this message") do
            puts opts
            exit
          end
        end
        opts.parse!(args)
             
        if args.length != 1
          puts "You must specify a username!"
          puts opts.help
          exit 1
        end

        @config["uid"] = args.shift
      end
  end
  
  class CLI    
    require 'highline/import'
    require 'base64'
    require 'digest/md5'
    
    def initialize(yamlfile, args, ldap = nil)
      @config = AdduserLDAP::Config.new(yamlfile, args)
      @user = AdduserLDAP::User.new(@config, ldap)
      bind_pw = get_password("Enter Your LDAP Password: ")
      @user.bind(ENV["USER"], bind_pw)
      @loginshells = Array.new
      IO.foreach("/etc/shells") { |line| @loginshells << line.chomp unless line =~ /^(#|\s)/ }
    end
    
    def get_password(prompt)
      ask(prompt) { |q| q.echo = "x" }
    end
    
    def adduser
      raise "User already exists" if @user.exists?(@config["uid"])
      @config.config["uidnumber"] ||= @user.highest_uidnumber
      @config.config["fullname"]  ||= get_fullname
      @config.config["shell"]     ||= get_shell
      @config.config["gidnumber"] ||= get_gidnumber
      @config.config["homedir"]   ||= get_homedir
      @config.config["password"]  = get_user_password
      
      if confirm() == "n"
        raise "Ok, do it again, see if I care."
      end
      
      @user.create(@config["uid"], @config["fullname"], @config["uidnumber"], @config["gidnumber"], @config["homedir"], @config["shell"], @config["password"])
    end
    
    def find(lattr)
      exists = false
      @user.search("(&(objectClass=posixAccount)(#{@config["rdn"]}=#{lattr}))") do |obj|
        exists = true
      end
      exists
    end

    private
      
      def get_user_password
        fpwd = get_password("New Password: ")
        spwd = get_password("Verify Password: ")
        if fpwd == spwd
          "{MD5}" + Base64.encode64(Digest::MD5.digest(fpwd)).chomp
        else 
          puts "Passwords don't match, try again!"
          get_user_password
        end
      end
    
      def confirm
        puts ""
        puts "Username: #{@config["uid"]}"
        puts "Full Name: #{@config["fullname"]}"
        puts "UID: #{@config["uidnumber"]}"
        puts "GID: #{@config["gidnumber"]}"
        puts "Shell: #{@config["shell"]}"
        puts "Home Directory: #{@config["homedir"]}"
        puts ""
        answer = ask("Create (y/n): ") { |q| q.validate = /^(y|n)$/i }
        answer.downcase
      end
    
      def get_homedir
        if @config["homedir_base"]
          File.join(@config["homedir_base"], @config["uid"])
        else
          ask("Home Directory: ")
        end
      end
      
      def get_gidnumber
        if @config["gidnumber_default"]
          @config["gidnumber_default"]
        else
          ask("Default Group: ") { |q| q.validate = /\d+/ }
        end
      end
    
      def get_fullname
        ask("Full Name (First Last): ") { |q| q.validate = /.+?\s.+/ } 
      end
      
      def get_shell
        choose do |menu|
          menu.prompt = "Select Login Shell: "
          @loginshells.each { |shell| menu.choice(shell) }
        end
      end    
  end
  
  class Group
    
  end
  
  class User
    require 'ldap'
    
    def initialize(config, ldap)
      @config = config
      if @config["ssl"]
        @ldap = LDAP::SSLConn.new(@config["server"], @config["port"], @config["starttls"])
      else
        @ldap = LDAP::Conn.new(@config["server"], @config["port"])
      end
      @ldap = ldap unless ldap.nil?
    end
    
    def bind(username, pw)
      bind_dn = @config["binddn"]
      unless bind_dn
        bind_dn = "#{@config["rdn"]}=#{username},#{@config["basedn"]}"
      end
      @ldap.bind(bind_dn, pw)
    end
    
    def exists?(lattr)
      exists = false
      search("(&(objectClass=posixAccount)(#{@config["rdn"]}=#{lattr}))") do |obj|
        exists = true
      end
      exists
    end
    
    def highest_uidnumber
      uidnumber = 0
      search("(uidnumber=*)") do |entry|
        entry.get_values("uidNumber").each do |un|
          un = un.to_i
          uidnumber = un if un > uidnumber
        end
      end
      uidnumber = uidnumber + 1
      puts "Highest uid: #{uidnumber}" if @config.verbose
      uidnumber
    end
    
    def search(filter="(objectclass=*)", &block)
      @ldap.search(@config["basedn"], LDAP::LDAP_SCOPE_SUBTREE, filter, &block)
    end
    
    def create(uid, fullname, uidnumber, gidnumber, homedir, shell, password)
      dn = "#{@config["rdn"]}=#{uid},#{@config["basedn"]}"
      givenname, sn = fullname.split(/ /)
      attrs = {
        "uid" => [ uid ],
        "sn" => [ sn ],
        "givenname" => [ givenname ],
        "cn" => [ fullname ],
        "loginshell" => [ shell ],
        "uidnumber" => [ uidnumber.to_s ],
        "gidnumber" => [ gidnumber.to_s ],
        "gecos" => [ fullname ],
        "homedirectory" => [ homedir ],
        "userpassword" => [ password ],
        "objectclass" => [ "posixAccount", "top", "inetOrgPerson" ],
      }
      @ldap.add(dn, attrs)
    end    
  end
end
