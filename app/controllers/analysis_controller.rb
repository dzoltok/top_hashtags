class AnalysisController < ApplicationController
  # Given a handle and limit, return a JSON response that contains the 10 most frequently used hashtags by that user
  def index
    handle = params[:handle]
    limit = params[:limit] || 2000
    twitter = Twitter::REST::Client.new do |config|
      config.consumer_key = ENV['TWITTER_API_KEY']
      config.consumer_secret = ENV['TWITTER_API_SECRET']
    end
    render json: twitter.user(handle)
  end
end
