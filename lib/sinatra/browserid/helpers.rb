module Sinatra
  module BrowserID
    module Helpers
      # Returns true if the current user has logged in and presented
      # a valid assertion.
      def authorized?
        ! session[:browserid_email].nil?
      end

      # If the current user is not logged in, redirects to a login
      # page. Override the login page by setting the Sinatra
      # option <tt>:browserid_login_url</tt>.
      def authorize!(redirect: nil)
        session[:authorize_redirect_url] = request.url
        session[:authorize_redirect_url] = redirect if redirect
        login_url = settings.browserid_login_url
        redirect login_url unless authorized?
      end

      # Logs out the current user.
      def logout!
        session[:browserid_email] = nil
      end

      # Returns the BrowserID verified email address, or nil if the
      # user is not logged in.
      def authorized_email
        session[:browserid_email]
      end

      # Normalize the email like the broker will do it, see
      # https://github.com/portier/portier.github.io/blob/master/specs/Email-Normalization.md
      def normalize_email(email)
        begin
            user, domain = email.split("@")
            if user == nil or user.empty?
                raise ArgumentError.new('user part must not be empty')  
            end 
            user = user.downcase
            domain = SimpleIDN.to_ascii(domain).downcase
            begin
                IPAddr.new(domain)
            rescue
                # if domain could not be parsed as IP we are good
                return user + "@" + domain
            end
            raise ArgumentError.new('domain must not be an IP')  
        rescue Exception => e
            raise ArgumentError, 'Not a valid email adress: ' + e.message
        end
      end

      # Returns the HTML to render the Persona login form.
      # Optionally takes a URL parameter for where the user should
      # be redirected to after the assert POST back.
      def render_login_button(redirect_url = nil)
        if session[:authorize_redirect_url]
          redirect_url = session[:authorize_redirect_url]
          session[:authorize_redirect_url] = nil
        end
        redirect_url ||= request.url
        session['redirect_url'] = redirect_url

        if session[:nonce]
            nonce = session[:nonce]
            # Try to limit how many nonces are stored by keeping the session nonce alive
            Cachy.delete_key(nonce)
            Cachy.cache(nonce, expires_in: 600) { true }
        else
            session[:nonce] = nonce = SecureRandom.base64
            Cachy.cache(nonce, expires_in: 600) { true }
        end

        template = ERB.new(Templates::LOGIN_BUTTON)
        template.result(binding)
      end
    end # module Helpers
  end
end

