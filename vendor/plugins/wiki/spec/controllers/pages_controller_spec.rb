require File.dirname(__FILE__) + "/../spec_helper"

def create_page
  Page.create(:title => "hee haw", :body => "moop", :group_id => 1)
end
def create_delete_page
  Page.create(:title => "to be delete", :body => "moop", :group_id => 1)
end
describe PagesController, " with group that requires login, a user not logged in" do
  fixtures :groups, :pages, :page_versions, :users, :profiles
  integrate_views
  before do
    controller.stub!(:logged_in?).and_return false
    controller.stub!(:current_user).and_return :false
    controller.stub!(:current_profile).and_return nil
  end
  
  it "show all pages" do
    get :index
    response.should be_success
    response.should render_template("index")
  end
    
  it "shows page if it exists" do
    page = create_page
    page.body = "MEEP"
    page.save!

    get :show, :id => page.permalink
    response.should be_success
    response.should render_template("show")      
  end
  
  it "redirect to session/new if page is a private page" do
    page = create_page
    page.private_page = true
    page.save!

    get :show, :id => page.permalink
    assigns[:message].should == "You must be logged to access this page."    
  end
  
  it "redirect to page/new (and it will in turn redirect to session/new) if showing a page that does not exist" do
    get :show, :id => "unavailable"
    response.should redirect_to("wiki/pages/new")      
  end
  
  it "does not render 'new'" do
    get :new
    assigns[:message].should == "You must be logged to access this page."
  end
  
  it "does not render 'diff'" do
    page = create_page
    page.body = "MEEP"
    page.save!

    get :diff, :id => page.permalink, :v1 => page.version, :v2 => page.version - 1
    assigns[:message].should == "You must be logged to access this page."
  end
  
  it "does not render 'revisions'" do
    page = create_page
    get :revisions, :id => page.permalink
    assigns[:message].should == "You must be logged to access this page."
  end

  it "does not render 'edit'" do
    page = create_page
    get :edit, :id => page.permalink
    assigns[:message].should == "You must be logged to access this page."
  end

  it "renders 'revision'" do
    page = create_page
    page.body = "moep MEEPp"
    page.save!

    get :revision, :id => page.permalink, :version => page.version - 1
    response.should be_success
    response.should render_template("show")    
  end
  
  it "searches for pages" do
    get :search, :query => "home"
    response.should be_success
  end
  
  it "can not lock a page" do
    get :lock, :id => 'hai'
    assigns[:message].should == "You must be logged to access this page."
  end
  
  it "can not rollback a page" do
    page = create_page
    page.body = "MEEP"
    page.save!
    current_version = page.version

    get :rollback, :id => page.permalink, :version => 1
    assigns[:message].should == "You must be logged to access this page."
    
    page = page.reload
    page.version.should be == current_version
  end
  
  it "can not edit a page" do
    page = create_page
    
    lambda do
      post :update, :id => page.permalink, :page => {:body => "hehehe"}
      assigns[:message].should == "You must be logged to access this page."
    end.should_not change(page, :body)
  end
  
  it "can not create a page" do
    lambda do
      post :create, :page => { :group_id => 1, :title => "o hai", :body => "meeg000!!" }
      assigns[:message].should == "You must be logged to access this page."
    end.should_not change(Page, :count)
  end
  
  it "can not delete a page" do
    page = create_delete_page
    
    lambda do
    delete :destroy, :id => page.permalink
    assigns[:message].should == "You must be logged to access this page."
    end.should_not change(Page, :count)
  end
end

describe PagesController, " with group that does not require login, a user not logged in" do
  fixtures :groups, :pages, :page_versions, :users, :profiles
  integrate_views
  before do
    group = Group.find(:first)
    group.wiki_requires_login_to_post = false
    group.save!

    controller.stub!(:logged_in?).and_return false
    controller.stub!(:current_user).and_return :false
    controller.stub!(:current_profile).and_return nil
  end
  
  it "show all pages" do
    get :index
    response.should be_success
    response.should render_template("index")
  end
    
  it "shows page if it exists" do
    page = create_page
    page.body = "MEEP"
    page.save!

    get :show, :id => page.permalink
    response.should be_success
    response.should render_template("show")      
  end
  
  it "shows new page if it does not exist" do
    get :show, :id => "unavailable"
    response.should redirect_to("wiki/pages/new")      
  end
  
  it "renders 'new'" do
    get :new
    response.should be_success
  end
  
  it "shows 'diff'" do
    page = create_page
    page.body = "MEEP"
    page.save!

    get :diff, :id => page.permalink, :v1 => page.version, :v2 => page.version - 1
    assigns(:v1).should == page.versions.find_by_version(params[:v1])
    assigns(:v2).should == page.versions.find_by_version(params[:v2])
    response.should be_success
    response.should render_template("diff")
  end
  
  it "shows 'revisions'" do
    page = create_page
    get :revisions, :id => page.permalink
    assigns(:revisions).should == page.versions
    response.should be_success
    response.should render_template("revisions")   
  end
  
  it "shows 'edit'" do
    page = create_page
    get :edit, :id => page.permalink
    assigns(:page).should == page
    response.should be_success
    response.should render_template("edit")   
  end

  it "can rollback a page" do
    page = create_page
    page.body = "MEEP"
    page.save!
    current_version = page.version

    get :rollback, :id => page.permalink, :version => 1
    response.should redirect_to("wiki/#{page.permalink}")
    
    page = page.reload
    page.version.should be < current_version
  end
  
  it "can edit a page" do
    page = create_page
    
    lambda do
      post :update, :id => page.permalink, :page => {:body => "hehehe"}
      response.should redirect_to("wiki/#{page.permalink}")
      page.reload
    end.should change(page, :body)
  end
  
  it "can create a page" do
    lambda do
      post :create, :page => { :group_id => 1, :title => "o hai", :body => "meeg000!!" }
      response.should redirect_to('wiki/o-hai')
    end.should change(Page, :count)
  end
  
  it "cannot delete a page" do
    page = create_delete_page
    lambda do
      delete :destroy, :id => page.permalink
      assigns[:message].should == "You must be logged to access this page."
    end.should_not change(Page, :count)
  end

end

describe PagesController, "a user logged in as normal user" do
  fixtures :groups, :pages, :page_versions, :users, :profiles
  integrate_views
  
  before do
    controller.stub!(:require_login)
    controller.stub!(:logged_in?).and_return true
    controller.stub!(:current_user).and_return users(:jeremy)
    controller.stub!(:current_profile).and_return profiles(:jeremy_profile)
  end
  
  it "show all pages" do
    get :index
    response.should be_success
    response.should render_template("index")
  end
    
  it "shows page if it exists" do
    page = create_page
    page.body = "MEEP"
    page.save!

    get :show, :id => page.permalink
    response.should be_success
    response.should render_template("show")      
  end
  
  it "shows new page if it does not exist" do
    get :show, :id => "unavailable"
    response.should redirect_to("wiki/pages/new")      
  end
    
  it "renders 'new'" do
    get :new
    response.should be_success
    response.should render_template("new")
  end

  it "shows 'revisions'" do
    page = create_page
    get :revisions, :id => page.permalink
    assigns(:revisions).should == page.versions
    response.should be_success
    response.should render_template("revisions")   
  end
  
  it "renders 'revision'" do
    page = create_page
    page.body = "MEEP"
    page.save!

    get :revision, :id => page.permalink, :version => page.version - 1
    response.should be_success
    response.should render_template("show")   
  end
  it "shows 'edit'" do
    page = create_page
    get :edit, :id => page.permalink
    assigns(:page).should == page
    response.should be_success
    response.should render_template("edit")   
  end
  
  it "shows 'diff'" do
    page = create_page
    page.body = "MEEP"
    page.save!

    get :diff, :id => page.permalink, :v1 => page.version, :v2 => page.version - 1
    assigns(:v1).should == page.versions.find_by_version(params[:v1])
    assigns(:v2).should == page.versions.find_by_version(params[:v2])
    response.should be_success
    response.should render_template("diff")
  end
  
  it "searches for pages" do
    get :search, :query => "home"
    response.should be_success
  end
  
  it "can edit a page" do
    page = create_page
    
    lambda do
      post :update, :id => page.permalink, :page => {:body => "hehehe"}
      response.should redirect_to("wiki/#{page.permalink}")
      page = page.reload
    end.should change(page, :body)
  end

  it "can create a page" do
    lambda do
      post :create, :page => { :group_id => 1, :title => "o hai", :body => "meeg000!!" }
      response.should redirect_to('wiki/o-hai')
    end.should change(Page, :count)
  end

  it "can rollback a page" do
    page = Page.create(:title => "hee haw", :body => "moop", :group_id => 1)
    page.body = "MEEP"
    page.save!
    current_version = page.version

    get :rollback, :id => page.permalink, :version => 1
    response.should redirect_to("wiki/#{page.permalink}")
    
    page = page.reload
    page.version.should be < current_version
  end

  it "can not lock a page" do
    get :lock, :id => 'hai'
    assigns[:message].should == "You must be an administrator to visit this page."
  end
  
  it "can delete a page" do
    page = create_delete_page
    page.title = "to be delete"
    page.save
    lambda do
      delete :destroy, :id => page.permalink
      response.should redirect_to('wiki/pages')
    end.should change(Page, :count)
  end
end

describe PagesController, "a user logged in as admin" do
  fixtures :groups, :pages, :page_versions, :users, :profiles
  integrate_views
  before do
    controller.stub!(:require_login)
    controller.stub!(:logged_in?).and_return true
    controller.stub!(:current_user).and_return users(:admin)
    controller.stub!(:current_profile).and_return profiles(:admin_profile)
  end

  it "show all pages" do
    get :index
    response.should be_success
    response.should render_template("index")
  end
    
  it "shows page if it exists" do
    page = create_page
    page.body = "MEEP"
    page.save!

    get :show, :id => page.permalink
    response.should be_success
    response.should render_template("show")      
  end
  
  it "shows new page if it does not exist" do
    get :show, :id => "unavailable"
    response.should redirect_to("wiki/pages/new")      
  end
    
  it "renders 'new'" do
    get :new
    response.should be_success
    response.should render_template("new")
  end

  it "shows 'revisions'" do
    page = create_page
    get :revisions, :id => page.permalink
    assigns(:revisions).should == page.versions
    response.should be_success
    response.should render_template("revisions")   
  end
  it "shows 'edit'" do
    page = create_page
    get :edit, :id => page.permalink
    assigns(:page).should == page
    response.should be_success
    response.should render_template("edit")   
  end
  
  it "renders 'revision'" do
    page = create_page
    page.body = "MEEP"
    page.save!

    get :revision, :id => page.permalink, :version => page.version - 1
    response.should be_success
    response.should render_template("show")   
  end
  
  it "shows 'diff'" do
    page = create_page
    page.body = "MEEP"
    page.save!

    get :diff, :id => page.permalink, :v1 => page.version, :v2 => page.version - 1
    assigns(:v1).should == page.versions.find_by_version(params[:v1])
    assigns(:v2).should == page.versions.find_by_version(params[:v2])
    response.should be_success
    response.should render_template("diff")
  end
  it "searches for pages" do
    get :search, :query => "home"
    response.should be_success
  end
  
  it "can edit a page" do
    page = create_page
    
    lambda do
      post :update, :id => page.permalink, :page => {:body => "hehehe"}
      response.should redirect_to("wiki/#{page.permalink}")
      page = page.reload
    end.should change(page, :body)
  end

  it "can create a page" do
    lambda do
      post :create, :page => { :group_id => 1, :title => "o hai", :body => "meeg000!!" }
      response.should redirect_to('wiki/o-hai')
    end.should change(Page, :count)
  end

  it "can rollback a page" do
    page = Page.create(:title => "hee haw", :body => "moop", :group_id => 1)
    page.body = "MEEP"
    page.save!
    current_version = page.version

    get :rollback, :id => page.permalink, :version => 1
    response.should redirect_to("wiki/#{page.permalink}")
    
    page = page.reload
    page.version.should be < current_version
  end

  it "can lock a page" do
    get :lock, :id => 'hai'
    response.should redirect_to('wiki/hai')
  end
  
  it "can unlock a page" do
    page = create_page
    page.lock
    
    get :lock, :id => page.permalink
    page.reload
    page.should_not be_locked
  end
  it "can delete a page" do
    page = create_delete_page
    page.title = "to be delete"
    page.save
    lambda do
      delete :destroy, :id => page.permalink
      response.should redirect_to('wiki/pages')
    end.should change(Page, :count)
  end
end

