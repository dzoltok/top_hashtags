class AnalysisController < ApplicationController
  # Given a handle and limit, return a JSON response that contains the 10 most frequently used hashtags by that user
  def index
    handle = params[:handle]
    limit = params[:limit] || 2000
    twitter = Twitter::REST::Client.new do |config|
      config.consumer_key = ENV['TWITTER_API_KEY']
      config.consumer_secret = ENV['TWITTER_API_SECRET']
    end

    # Grab a list of the most recent <limit> tweets by the given handle
    max_id = nil
    tweets_processed = 0
    hashtags = Hash.new(0)
    catch (:finished) do
      loop do
        if max_id
          tweets = twitter.user_timeline(handle, count: 200, max_id: (max_id - 1), trim_user: true, exclude_replies: false, include_rts: true)
        else
          tweets = twitter.user_timeline(handle, count: 200, trim_user: true, exclude_replies: false, include_rts: true)
        end
        if tweets.empty?
          throw :finished
        end
        tweets.each do |tweet|
          max_id = tweet.id
          tweet.hashtags.each do |hashtag|
            hashtags[hashtag.text] += 1
          end
          tweets_processed += 1
          if tweets_processed >= limit.to_i
            throw :finished
          end
        end
      end
    end

    render json: hashtags.sort_by { |h, v| -v }[0..9].to_h
  end
end
