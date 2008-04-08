require File.dirname(__FILE__) + '/../test_helper'
Tentacle::Command.configure(ActiveRecord::Base.configurations['test'].symbolize_keys)

Tentacle::Syncer::SvnSyncer.send :attr_writer, :num
Tentacle::Syncer::SvnSyncer.send :public, :num=

context "Command Syncing" do
  setup do
    @node       = stub(:text? => true, :revision => 5)
    @silo       = stub(:fs => stub, :latest_revision => 50, :node_at => @node)
    @command    = Tentacle::Command.new
    @changes    = []
    @connection = {:changes => @changes}
    @command.stubs(:connection).returns(@connection)
    @repo = {:id => 1, :scm_type => 'svn', :changesets_count => 0}
    @changeset = {:id => 7, :revision => 5, :repository_id => @repo[:id], :author => 'rick', :message => 'brb going to moon', :changed_at => (Time.now - 300).utc}
    @user = {:id => 6, :login => 'justin'}
    @command.stubs(:silo_for).with(@repo).returns(@silo)
    @syncer = Tentacle::Syncer::SvnSyncer.new(@command.connection, @repo, @silo, 1)
  end

  specify "should sync revisions" do
    changesets = [@changeset.merge(:revision => 4)]
    @connection.update \
      :users => stub(:where => [@user.merge(:login => @changeset[:author])]), :repositories => stub(:where => @repo),
      :changesets => stub(:where => stub(:order => changesets))
    @connection.expects(:transaction).yields
    @syncer.expects(:create_changeset).with(@changeset[:revision]).returns(@changeset)
    @syncer.expects(:update_user_activity).with({:id => @user[:id], :login => @changeset[:author]}, @changeset[:changed_at])
    Tentacle::Syncer::SvnSyncer.expects(:new).with(@connection, @repo, @silo, 1).returns(@syncer)
    @command.send(:sync_revisions_for, @repo, 1)
    @repo[:changesets_count].should == 1
  end

  specify "should skip syncing if there are no revisions to sync" do
    @silo.stubs(:latest_revision).returns(5)
    changesets = [@changeset]
    @connection.update :changesets => stub(:where => stub(:order => changesets))
    @command.connection.expects(:transaction)
    @syncer.expects(:create_changeset).times(0)
    Tentacle::Syncer::SvnSyncer.expects(:new).with(@connection, @repo, @silo, 1).returns(@syncer)
    @command.sync_revisions_for(@repo, 1)
  end

  specify "should get latest revision" do
    @silo.expects(:latest_revision).returns(75)
    @command.send(:latest_revision_for, @repo).should == 75
  end
  
  specify "should update user activity" do
    @changesets_where = stub
    @changesets_where.expects(:select).with(:id.COUNT).returns 15
    @changesets = stub
    @changesets.expects(:where).with(:repository_id => @repo[:id], :author => @user[:login]).returns(@changesets_where)
    
    @permissions_where = stub
    @permissions_where.expects(:update).with(:last_changed_at => @changeset[:changed_at], :changesets_count => 15).returns(77)
    @permissions = stub
    @permissions.expects(:where).with(:user_id => @user[:id], :repository_id => @repo[:id]).returns(@permissions_where)
    
    @connection.update(:permissions => @permissions, :changesets => @changesets)
    @syncer.send(:update_user_activity, @user, @changeset[:changed_at]).should == 77
  end
  
  specify "should create changeset from revision" do
    @changesets = stub
    @changesets.expects(:<<).returns(@changeset[:id])
    @connection.update(:changesets => @changesets)
    @node.expects(:author).returns(@changeset[:author])
    @node.expects(:message).returns(@changeset[:message])
    @node.expects(:changed_at).returns(@changeset[:changed_at].localtime)
    @syncer.expects(:create_change_from_changeset).with(@node, @changeset, {:all => [], :diffable => false})
    
    @syncer.send(:create_changeset, @changeset[:revision]).should == @changeset
  end
  
  %w(A D M MVP).each do |name|
    specify "should create change with #{name}" do
      @changes.clear
      @syncer.send(:process_change_path_and_save, @node, "/foo", {:id => 1, :revision => 5, :diffable => 1}, name, {:all => []})
      @changes.should == [{:changeset_id => 1, :name => name, :path => "/foo", :diffable => true}]
    end
  end
  
  %w(MV CP).each do |change_type|
    specify "should create change with #{change_type}" do
      @changes.clear
      @syncer.send(:process_change_path_and_save, @node, [1,2,3], {:id => 1, :revision => 5, :diffable => 1}, change_type, {:all => []})
      @changes.should == [{:changeset_id => 1, :name => change_type, :path => 1, :from_path => 2, :from_revision => 3, :diffable => true}]
    end
  end
  
  specify "should process changeset changes" do
    @node.stubs(:added_files).returns(%w(/foo /foo/bar.txt))
    @node.stubs(:updated_files).returns(%w(/foo /foo/bar.txt))
    @node.stubs(:deleted_files).returns(%w(/copied /deleted /copied/file /deleted/file))
    @node.stubs(:copied_files).returns([%w(a /copied b), %w(a /original b), %w(a /copied/file b), %w(a /original/file b)])
    
    @changes = {:all => [], :diffable => false}
    
    @syncer.expects(:process_change_path_and_save).with(@node, '/foo', @changeset, 'A', @changes)
    @syncer.expects(:process_change_path_and_save).with(@node, '/foo/bar.txt', @changeset, 'A', @changes)
    @syncer.expects(:process_change_path_and_save).with(@node, '/foo', @changeset, 'M', @changes)
    @syncer.expects(:process_change_path_and_save).with(@node, '/foo/bar.txt', @changeset, 'M', @changes)
    @syncer.expects(:process_change_path_and_save).with(@node, '/deleted', @changeset, 'D', @changes)
    @syncer.expects(:process_change_path_and_save).with(@node, '/deleted/file', @changeset, 'D', @changes)
    @syncer.expects(:process_change_path_and_save).with(@node, %w(a /copied b), @changeset, 'MV', @changes)
    @syncer.expects(:process_change_path_and_save).with(@node, %w(a /copied/file b), @changeset, 'MV', @changes)
    @syncer.expects(:process_change_path_and_save).with(@node, %w(a /original b), @changeset, 'CP', @changes)
    @syncer.expects(:process_change_path_and_save).with(@node, %w(a /original/file b), @changeset, 'CP', @changes)
    
    @syncer.send(:create_change_from_changeset, @node, @changeset, @changes)
  end
end

context "Command Clearing" do
  setup do
    @silo = stub(:fs => stub) 
    @command = Tentacle::Command.new
  end
  specify "should fail early for bad repo subdomain" do
  end
    def clear_changesets_for(repo_subdomain)
      repo = repo_subdomain && connection[:repositories].where(:subdomain => repo_subdomain).first
      if repo_subdomain && repo.nil?
        puts "No repo(s) found, REPO=#{repo_subdomain.inspect} given."
        return
      end
      changesets = connection[:changesets]
      changes    = connection[:changes]
      if repo
        changesets = changesets.where(:repository_id => repo) 
        changes    = changes.where(:changeset_id => changesets.select(:id))
      end
      connection.transaction { [changes, changesets].each { |ds| ds.delete } }
      puts repo ? "All revisions for #{repo[:name].inspect} were cleared." : "All revisions for all repositories were cleared"
    end
end