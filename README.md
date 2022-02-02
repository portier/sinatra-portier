Sinatra plugin that allows authentication against portier, the successor for [Persona](https://github.com/mozilla/persona). Like Persona, this lets you verify the email identity of a user.

To be a drop-in replacement, the code keeps using the browserid namespace.

---

To learn more, [read about portier](https://portier.github.io/).

Note that logins are not done from within a form on your site -- you provide a login form, and that will start up the login flow and redirect back to your main page.

## How to get started

Install the gem **sinatra-portier**:

```
gem install sinatra-portier
```

Then use it in your code:
 

```ruby
require 'sinatra'
require 'sinatra/browserid'


register Sinatra::BrowserID

set :sessions, true
# Disabling origin-check is needed to make webkit-browsers like Chrome work. 
# Behind a proxy you will also need to disable :remote_token, regardless for which browser.
set :protection, except: [:http_origin] 
get '/' do
    if authorized?
        "Welcome, #{authorized_email}"
    else
        render_login_button
    end
end

get '/secure' do
    authorize!                 # require a user be logged in

    authorized_email   # browserid email
end

get '/logout' do
    logout!

    redirect '/'
end

```

See the rdoc for more details on the helper functions.  For a functioning
example app, start the app in the example directory:

```
bundle install
bundle exec rackup -p PORT

```

Available sinatra settings:

 * <tt>:browserid_url</tt>: If you're using an alternate auth provider
  other than https://broker.portier.io
 * <tt>:browserid_login_url</tt>: URL users get redirected to when the
  <tt>authorize!(redirect: nil)</tt> helper is called and a user is not logged in. `redirect` is an optional parameter to set the redirect target on the function call instead.
 * <tt>:browserid_button_class</tt>: Css class of the login button
 * <tt>:browserid_button_text</tt>: Text of the login button
