class UserMailer < ActionMailer::Base
  include ActionController::UrlWriter

  def invitation(creator, user)
    setup_user(user)
    @subject        = "New Tentacle account for #{Tentacle.domain}"
    @body[:creator] = creator
  end

  def forgot_password(user)
    setup_user(user)
    @subject    = "[Tentacle] Request to change your password."
  end

  protected
    def setup_user(user)
      @recipients  = "#{user.email}"
      @body[:user] = user
      @body[:url]  = reset_url(:token => user.token, :host => Tentacle.domain)
      setup_email
    end
    
    def setup_email
      @from        = "#{Tentacle.mail_from}"
      @sent_on     = Time.now
    end
end
