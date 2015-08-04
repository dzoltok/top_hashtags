require 'twitter_api'

class AnalysisController < ApplicationController
  rescue_from Twitter::Error::NotFound, :with => :no_such_user

  # Given a handle and limit, return a JSON response that contains the 10 most frequently used hashtags by that user in their last <limit> tweets
  def index
    # Parameter checking the hard way: handle is required, limit is optional but must be a non-negative integer
    if params.has_key? :handle
      handle = params[:handle]
    else
      render json: { error: 'Handle required.' }, status: 500 and return
    end

    if params.has_key?(:limit)
      if params[:limit].to_i.to_s != params[:limit]
        render json: { error: 'Limit must be an integer.' }, status: 500 and return
      elsif params[:limit].to_i < 0
        render json: { error: 'Limit must be non-negative.' }, status: 500 and return
      elsif params[:limit].to_i > 2000
        render json: { error: 'Limit must be less than 2000.' }, status: 500 and return
      end
      limit = params[:limit].to_i
    else
      limit = 2000
    end

    hashtags = Hash.new(0)

    # Note that since_id only works if ALL tweets prior to since_id have already been processed. If the user makes a request with a small
    # limit, and then with a large limit, this expectation no longer applies. The simplest way to allow since_id to work is to
    # pre-process the user's last 2000 tweets if this is the first time they are making a request.
    process_from_twitter(handle, 2000) if TweetRecord.where(handle: handle).empty?

    # Now, we can correctly calculate the since_id from the records in the database
    since_id = TweetRecord.where(handle: handle).maximum(:tweet_id) # The minimum ID to retrieve from Twitter; any older tweets are treated as pre-processed

    # We can then use that since_id to only grab new tweets from the API
    results = process_from_twitter(handle, limit, since_id)

    # If we still haven't processed enough tweets to hit the limit, check the DB
    hashtags = process_from_database(results[:hashtags], handle, limit - results[:processed], results[:maximum_id]) if results[:processed] < limit

    # Sort the resulting hashtags by descending count value, grab the first 10 elements, and return them as a new array of Hashes
    render json: hashtags.sort_by { |h, v| -v }[0..9].map{ |item| { hashtag: item[0], count: item[1] }}
  end

  private

  # Process the last <limit> tweets from <handle>'s timeline and save the corresponding records into the database
  # Returns the set of hashtags analyzed, just in case
  def process_from_twitter(handle, limit, since_id = nil)
    tweets_processed = 0
    new_tweet_records = []
    hashtags = Hash.new(0)
    max_id = nil

    twitter = TwitterAPI.instance.client

    options = { count: 200, trim_user: true, exclude_replies: false, contributor_details: false, include_rts: true}
    if since_id
      options[:since_id] = since_id
    end

    catch (:limit_reached) do
      loop do
        if max_id
          options[:max_id] = max_id - 1
        end
        tweets = twitter.user_timeline(handle, options)

        # If no tweets were found, we're done processing
        if tweets.empty?
          throw :limit_reached
        end

        # For each tweet, we store its ID as the new max ID, and scan its hashtags, incrementing every found hashtag count by 1
        tweets.each do |tweet|
          max_id = tweet.id
          tweet.hashtags.each do |hashtag|
            hashtags[hashtag.text] += 1
          end

          # Store this tweet as a local DB object so we don't have to query Twitter for it in the future
          new_tweet_records << TweetRecord.new(handle: handle, tweet_id: tweet.id, hashtags: tweet.hashtags.map { |item| item.text})
          tweets_processed += 1

          # If we've already processed the maximum number of tweets, we're done processing
          if tweets_processed >= limit
            throw :limit_reached
          end
        end
      end
    end

    TweetRecord.import new_tweet_records

    return {
      hashtags: hashtags,
      processed: tweets_processed,
      maximum_id: max_id
    }
  end

  def process_from_database(hashtags, handle, limit, maximum_id = nil)
    records = TweetRecord.where(handle: handle).limit(limit)
    records = record.where('tweet_id < ?', maximum_id) unless maximum_id.nil?
    records.each do |tweet_record|
      tweet_record.hashtags.each do |hashtag|
        hashtags[hashtag] += 1
      end
    end
    return hashtags
  end

  def no_such_user(error)
    render json: { error: error.message }, status: 500
  end

end
