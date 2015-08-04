class AnalysisController < ApplicationController
  # Given a handle and limit, return a JSON response that contains the 10 most frequently used hashtags by that user in their last <limit> tweets
  def index
    handle = params[:handle]
    limit = params[:limit].to_i || 2000

    twitter = Twitter::REST::Client.new do |config|
      config.consumer_key = ENV['TWITTER_API_KEY']
      config.consumer_secret = ENV['TWITTER_API_SECRET']
    end

    # Initialize some parameters:
    max_id = nil # The maximum ID of tweets to retrieve in later requests (to ensure no tweets are retrieved twice)
    since_id = TweetRecord.where(handle: handle).maximum(:tweet_id) # The minimum ID to retrieve from Twitter; any older tweets are pre-processed
    hashtags = Hash.new(0) # A store of the encountered hashtags and their counts
    new_tweet_records = [] # A store of new tweet records to be saved to the local database
    api_tweets_processed = 0 # The number of tweets processed by calling the API (used for debugging)
    db_tweets_processed = 0 # The number of tweets processed by querying the DB (used for debugging)


    # Use the Twitter API to paginate through a user's tweets until either <limit> tweets have been processed, or there are no more tweets to process
    catch (:finished) do
      loop do
        # Grab a single page of up to 200 tweets with ID less than the maximum ID already read, and greater than the last ID already processed
        # - Do not retrieve the full user object, as we don't need it
        # - Include replies to tweets
        # - Do not retrieve details of contributors
        # - Include re-tweets
        options = { count: 200, trim_user: true, exclude_replies: false, contributor_details: false, include_rts: true}
        if max_id
          options[:max_id] = max_id - 1
        end
        if since_id
          options[:since_id] = since_id
        end
        tweets = twitter.user_timeline(handle, options)

        # If no tweets were found,
        if tweets.empty?
          throw :finished
        end

        # For each tweet, we store its ID as the new max ID, and scan its hashtags, incrementing every found hashtag count by 1
        tweets.each do |tweet|
          max_id = tweet.id
          tweet.hashtags.each do |hashtag|
            hashtags[hashtag.text] += 1
          end

          # Store this tweet as a local DB object so we don't have to query Twitter for it in the future
          # We don't want to save it until AFTER we have queried the DB, to avoid processing duplicates
          new_tweet_records << TweetRecord.new(handle: handle, tweet_id: tweet.id, hashtags: tweet.hashtags.map { |item| item.text})
          api_tweets_processed += 1

          # If we've already processed the maximum number of tweets, the algorithm is done
          if api_tweets_processed >= limit
            throw :finished
          end
        end
      end
    end

    Rails.logger.info "#{api_tweets_processed} tweets processed from Twitter"

    # If we still have not processed <limit> tweets, check the DB for
    if api_tweets_processed < limit
      TweetRecord.where(handle: handle).limit(limit - api_tweets_processed).each do |tweet_record|
        tweet_record.hashtags.each do |hashtag|
          hashtags[hashtag] += 1
        end
        db_tweets_processed += 1
      end
    end

    Rails.logger.info "#{db_tweets_processed} tweets processed from the database"

    # NOW we can safely save the processed tweets
    TweetRecord.import new_tweet_records
    # new_tweet_records.each do |new_tweet_record|
    #   new_tweet_record.save!
    # end

    # Sort the resulting hashtags by descending count value, grab the first 10 elements, and return them as a new Hash
    render json: hashtags.sort_by { |h, v| -v }[0..9].to_h
  end
end
