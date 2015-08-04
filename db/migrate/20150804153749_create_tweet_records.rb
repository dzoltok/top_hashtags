class CreateTweetRecords < ActiveRecord::Migration
  def change
    create_table :tweet_records do |t|
      t.string :handle, null: false
      t.column :tweet_id, :bigint
      t.text :hashtags, array: true, default: []

      t.timestamps null: false
    end
  end
end
