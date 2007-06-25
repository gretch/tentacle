class UsersController < ApplicationController
  before_filter :login_required, :only   => :update
  before_filter :admin_required, :except => :update
  
  def index
    @users = User.paginate :all, :page => params[:page], :order => 'identity_url'
  end
  
  def create
    @user = User.new(params[:user])
    if params[:user]
      @user.admin = params[:user][:admin] == '1'
    end
    
    render :update do |page|
      if @user.save
        UserMailer.deliver_invitation(current_user, @user)
        page.redirect_to users_path
      else
        page["error-#{dom_id @user}"].show.replace_html(error_messages_for(:user))
      end
    end
  end
  
  def update
    if params[:id].blank?
      @sheet = 'profile-form'
      @user  = current_user
    else
      return unless admin_required
      @user  = User.find params[:id]
      @sheet = "profile-#{dom_id @user}"
    end
    @user.attributes = params[:user]
    if params[:id] && params[:user]
      @user.admin = params[:user][:admin] == '1'
    end
    @user.save
    respond_to do |format|
      format.html { redirect_to(params[:to] || root_path) }
      format.js
    end
  end
  
  def destroy
    @user = User.find params[:id]
    @user.destroy
    respond_to do |format|
      format.js
    end
  end
end
