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

    # Repeat this loop until no more tweets are received OR <limit> tweets have been processed OR all remaining tweets are already in the DB
    catch (:finished) do
      loop do
        # Grab a single page of up to 200 tweets with ID less than the maximum ID already read
        if max_id
          tweets = twitter.user_timeline(handle, count: 200, max_id: (max_id - 1), trim_user: true, exclude_replies: false, include_rts: true)
        else
          tweets = twitter.user_timeline(handle, count: 200, trim_user: true, exclude_replies: false, include_rts: true)
        end
        # If no tweets were found, the algorithm is done
        if tweets.empty?
          throw :finished
        end
        # For each tweet, we store its ID as the new max ID, and scan its hashtags, incrementing every found hashtag count by 1
        tweets.each do |tweet|
          max_id = tweet.id
          tweet.hashtags.each do |hashtag|
            hashtags[hashtag.text] += 1
          end
          tweets_processed += 1
          # If we've already processed the maximum number of tweets, the algorithm is done
          if tweets_processed >= limit.to_i
            throw :finished
          end
        end
      end
    end

    # Sort the resulting hashtags by descending count value, grab the first 10 elements, and return them as a new Hash
    render json: hashtags.sort_by { |h, v| -v }[0..9].to_h
  end
end
