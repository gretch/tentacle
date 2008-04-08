ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'
require 'mocha'
require 'test/spec'
require 'ruby-debug'
Debugger.start

class Test::Unit::TestCase
  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures  = false
  fixtures :all
  
  protected
    def login_as(user)
      @controller.stubs(:current_user).returns(user ? users(user) : nil)
    end

    def stub_node(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      path    = args.first || ''
      returning stub(options.merge(:path => path, :dir? => true)) do |stub|
        stub.stubs(:accessible_by?).returns(true)
      end
    end
end

Tentacle.domain = 'test.host'
Tentacle.permission_command = Tentacle.password_command = nil
# makes model/controller tests explode
#Tentacle::Command.configure(ActiveRecord::Base.configurations['test'].symbolize_keys)