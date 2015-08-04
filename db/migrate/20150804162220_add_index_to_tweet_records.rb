class AddIndexToTweetRecords < ActiveRecord::Migration
  def change
    add_index :tweet_records, :handle
  end
end
