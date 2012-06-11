require 'json'
require 'oauth'

module OauthSystem
  class GeneralError < StandardError
  end
  class RequestError < OauthSystem::GeneralError
  end
  class NotInitializedError < OauthSystem::GeneralError
  end

  # controller method to handle logout
  def signout
    self.current_user = false
    flash[:notice] = "You have been logged out."
    redirect_to root_url
  end

  # controller method to handle twitter callback (expected after login_by_oauth invoked)
  def callback
    Rails.logger.info("########callback")

    self.twitagent.exchange_request_for_access_token( session[:request_token], session[:request_token_secret], params[:oauth_verifier] )

    user_info = self.twitagent.verify_credentials
    Rails.logger.info("########callback"+user_info.inspect)
    raise OauthSystem::RequestError unless user_info['id'] && user_info['screen_name'] && user_info['profile_image_url']

    # We have an authorized user, save the information to the database.
    @subscriber = SubscriberPreference.new({
                                               :provider => "twitter",
                                               :name => user_info['screen_name'],
                                               :access_token => self.twitagent.access_token.token,
                                               :access_secret => self.twitagent.access_token.secret,
                                               :profile_image_url => user_info['profile_image_url'] })

    if @subscriber.save!
      @subscriber
    else
      raise OauthSystem::RequestError
    end
    # Redirect to the show page
    flash[:notice] = "You have been counted . Thanks #{@subscriber}"
    redirect_to root_path

  rescue
    # The user might have rejected this application. Or there was some other error during the request.
    Rails.logger.info "Failed to get user info via OAuth"
    flash[:error] = "Twitter API failure (account login)"
    redirect_to root_url
  end

  protected




  def twitagent( user_token = nil, user_secret = nil )
    Rails.logger.info("########twitagent")
    self.twitagent = TwitterOauth.new( user_token, user_secret )  if user_token && user_secret
    self.twitagent = TwitterOauth.new( ) unless @twitagent
    @twitagent ||= raise OauthSystem::NotInitializedError
  end
  def twitagent=(new_agent)
    Rails.logger.info("########twitagent new_agent")
    @twitagent = new_agent || false
    Rails.logger.info("########twitagent new_agent"+@twitagent.inspect)

  end

  # Accesses the current user from the session.
  # Future calls avoid the database because nil is not equal to false.
  def oauth_login_required
    Rails.logger.info("########oauth_login_required")
    login_by_oauth
  end


  def login_by_oauth
    Rails.logger.info("########login_by_oauth")

    request_token = self.twitagent.get_request_token
    Rails.logger.info("########request_token"+request_token.inspect)
    session[:request_token] = request_token.token
    session[:request_token_secret] = request_token.secret
    # Send to twitter.com to authorize
    redirect_to request_token.authorize_url
  rescue => err
    puts "Exception in exchainitializenge_request_for_access_token: #{err}"
    raise err
    # The user might have rejected this application. Or there was some other error during the request.
    Rails.logger.info "Failed to login via OAuth"
    flash[:error] = "Twitter API failure (account login)"
    redirect_to root_url
  end



  # controller wrappers for twitter API methods

  # Twitter REST API Method: statuses/update
  def update_status!(  status , in_reply_to_status_id = nil )
    self.twitagent.update_status!(  status , in_reply_to_status_id )
  rescue => err
    # The user might have rejected this application. Or there was some other error during the request.
    Rails.logger.info "#{err.message} Failed update status"
    return
  end

  # Twitter REST API Method: statuses friends
  def friends(user=nil)
    self.twitagent.friends(user)
  rescue => err
    Rails.logger.info "Failed to get friends via OAuth for #{current_user.inspect}"
    flash[:error] = "Twitter API failure (getting friends)"
    return
  end

  # Twitter REST API Method: statuses followers
  def followers(user=nil)
    self.twitagent.followers(user)
  rescue => err
    Rails.logger.info "Failed to get followers via OAuth for #{current_user.inspect}"
    flash[:error] = "Twitter API failure (getting followers)"
    return
  end

  # Twitter REST API Method: statuses mentions
  def mentions( since_id = nil, max_id = nil , count = nil, page = nil )
    self.twitagent.mentions( since_id, max_id, count, page )
  rescue => err
    Rails.logger.info "Failed to get mentions via OAuth for #{current_user.inspect}"
    flash[:error] = "Twitter API failure (getting mentions)"
    return
  end

  # Twitter REST API Method: direct_messages
  def direct_messages( since_id = nil, max_id = nil , count = nil, page = nil )
    self.twitagent.direct_messages( since_id, max_id, count, page )
  rescue => err
    Rails.logger.info "Failed to get direct_messages via OAuth for #{current_user.inspect}"
    flash[:error] = "Twitter API failure (getting direct_messages)"
    return
  end


end