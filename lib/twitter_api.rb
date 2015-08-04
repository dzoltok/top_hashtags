require 'singleton'

class TwitterAPI
  include Singleton

  def initialize
    @client = Twitter::REST::Client.new do |config|
      config.consumer_key = ENV['TWITTER_API_KEY']
      config.consumer_secret = ENV['TWITTER_API_SECRET']
    end
  end

  def client
    @client
  end

  def client=(client)
    @client = client
  end
end
