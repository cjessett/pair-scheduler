require 'bundler'
Bundler.require

# load the Database and models
require './model'

Warden::Strategies.add(:password) do
  def valid?
    params['user'] && params['user']['username'] && params['user']['password']
  end

  def authenticate!
    user = User.first(username: params['user']['username'])

    if user.nil?
      throw(:warden, message: "The username you entered does not exist.")
    elsif user.authenticate(params['user']['password'])
      success!(user)
    else
      throw(:warden, message: "The username and password combination ")
    end
  end
end

class SinatraWarden < Sinatra::Base
	enable :sessions
	register Sinatra::Flash
	set :session_secret, ENV['SESSION_SECRET'] # try [env] variable

	use Warden::Manager do |config|
    # Tell Warden how to save our User info into a session.
    # Sessions can only take strings, not Ruby code, we'll store
    # the User's `id`
    config.serialize_into_session{|user| user.id }
    # Now tell Warden how to take what we've stored in the session
    # and get a User from that information.
    config.serialize_from_session{|id| User.get(id) }

    config.scope_defaults :default,
      # "strategies" is an array of named methods with which to
      # attempt authentication. We have to define this later.
      strategies: [:password],
      # The action is a route to send the user to when
      # warden.authenticate! returns a false answer. We'll show
      # this route below.
      action: 'auth/unauthenticated'
    # When a user tries to log in and cannot, this specifies the
    # app to send the user to.
    config.failure_app = self
  end

  Warden::Manager.before_failure do |env,opts|
    # Because authentication failure can happen on any request but
    # we handle it only under "post '/auth/unauthenticated'", we need
    # to change request to POST
    env['REQUEST_METHOD'] = 'POST'
    # And we need to do the following to work with  Rack::MethodOverride
    env.each do |key, value|
      env[key]['_method'] = 'post' if key == 'rack.request.form_hash'
    end
  end

  # Routes

  get '/' do
    redirect '/auth/login'
  end

  get '/auth/login' do
    erb :login
  end

  post '/auth/login' do
    env['warden'].authenticate!

    flash[:success] = "Successfully logged in"

    if session[:return_to].nil?
      redirect '/protected'
    else
      redirect session[:return_to]
    end
  end

  get '/auth/logout' do
    env['warden'].raw_session.inspect
    env['warden'].logout
    flash[:success] = "Successfully logged out"
    redirect '/'
  end

  post '/auth/unauthenticated' do
    session[:return_to] = env['warden.options'][:attempted_path] if session[:return_to].nil?

    # Set the error and use a fallback if the message is not defined
    flash[:error] = env['warden.options'][:message] || "You must log in"
    redirect '/auth/login'
  end

  get '/sign_up' do
    current_user = env['warden'].user
    if current_user == nil
      @groups = Group.all(:id.not => 1) # don't allow access to 'admin' group
      erb :sign_up
    else
      redirect '/protected'
    end
  end

  post '/sign_up' do
    username = params['user']['username']
    p = params['user']['password']
    confirm = params['confirm_user']['password']
    user = User.first(username: username)
    if user.nil? && p == confirm
      u = User.new
      u.username = username
      u.password = p
      u.time_zone = params[:time_zone].to_i
      u.name = params[:first_last]
      u.group_id = params[:group]
      u.save
    else
      redirect '/sign_up'
    end
    redirect '/auth/login'
  end

  get '/protected' do
    env['warden'].authenticate!

    redirect "/users/#{env['warden'].user.id}"
  end

  before '/users/*' do
    env['warden'].authenticate!
  end

  get '/users/:user_id' do
    id = params[:user_id].to_i
    @user = User.get (id)
    @assignments = Assignment.all(group_id: @user.group_id)
    erb :user_home
  end

  get '/availability/:assignment_id' do
    @user = env['warden'].user
    id = params[:assignment_id].to_i
    @assignments = Assignment.all(group_id: @user.group_id)
    @current_assignment = Assignment.first(id: id)

    @availabilities = Availability.all(user_id: @user.id)
    erb :availability
  end

  post '/availability' do
    a = Availability.new
    a.date = params[:date]
    a.start = params[:start]
    a.end = params[:end]
    user = env['warden'].user
    a.user_id = user.id
    a.assignment_id = Assignment.get(params[:assignment]).id
    a.save
    redirect '/availability/:assignment_id'
  end
end