#!/usr/bin/env ruby

require "open-uri"
require 'json'
require 'url_safe_base64'
require 'jwt'
require 'simpleidn'
require 'ipaddr'
require "sinatra/base"
require 'sinatra/browserid/helpers'
require 'sinatra/browserid/template'
require 'addressable/uri'
require 'cachy'
require 'moneta'


# This module provides an interface to verify a users email address
# with browserid.org.
module Sinatra
    module BrowserID

        # Init an in-memory cache via the cachy gem. We use this
        # instead of the session because of dropped sessions
        # after redirects, see https://github.com/sinatra/sinatra/issues/1742.
        Cachy.cache_store = Moneta.new(:Memory, expires: 600) # 10 minutes
                                                              # We need to set a global :expires here because of https://github.com/grosser/cachy/issues/7
    
        def self.registered(app)
            app.helpers BrowserID::Helpers

            app.set :browserid_url, "https://broker.portier.io"
            app.set :browserid_login_button, :red
            app.set :browserid_login_url, "/_browserid_login"
            app.set :browserid_button_class, ""
            app.set :browserid_button_text, "Log in"

            app.get '/_browserid_login' do
                render_login_button
            end

          app.post '/_browserid_assert' do
              begin
                  # Server checks signature
                  # For that, fetch the public key from the LA instance (TODO: Do that beforehand for trusted instances, and generally cache the key)
                  public_key_jwks_uri = Addressable::URI.parse(settings.browserid_url + '/keys.json')
                  public_key_jwks = ::JSON.parse(URI.parse(public_key_jwks_uri).read)
                  public_key = OpenSSL::PKey::RSA.new
                  if public_key.respond_to? :set_key
                    # Set n and d via the new set_key function, as direct access to n and e is blocked for some ruby and openssl versions.
                    # Note that we have no d, as this is a public key, which would be the third param
                    public_key.set_key( (OpenSSL::BN.new UrlSafeBase64.decode64(public_key_jwks["keys"][0]["n"]), 2),
                                        (OpenSSL::BN.new UrlSafeBase64.decode64(public_key_jwks["keys"][0]["e"]), 2),
                                        nil)
                  else
                    public_key.e = OpenSSL::BN.new UrlSafeBase64.decode64(public_key_jwks["keys"][0]["e"]), 2 
                    public_key.n = OpenSSL::BN.new UrlSafeBase64.decode64(public_key_jwks["keys"][0]["n"]), 2
                  end
                  
                  id_token = JWT.decode params[:id_token], public_key, true, { :algorithm => 'RS256' }
                  id_token = id_token[0]
                  # Needs to make sure token is still valid
                  if (id_token["iss"] == settings.browserid_url &&
                      id_token["aud"] == request.base_url.chomp('/') &&        
                      id_token["exp"] > Time.now.to_i &&
                      id_token["email_verified"] &&
                      # nonce is really known to us
                      Cachy.get(id_token["nonce"]))
                          session[:browserid_email] = id_token['email']
                          Cachy.delete_key(id_token["nonce"])
                          session.delete(:nonce)  # it's possible the session persisted
                          if session['redirect_url']
                            redirect session['redirect_url']
                          else
                            redirect "/"
                          end
                  else
                    # Even when the token check failed the nonce has to be invalidated
                    Cachy.delete_key(id_token["nonce"])
                    session.delete(:nonce)
                  end
              rescue OpenURI::HTTPError => e
                  puts "could not validate token: " + e.to_s
              end
              halt 403
              
            end
        end
    end
    register BrowserID
end

