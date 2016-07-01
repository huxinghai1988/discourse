class CreateTagsTopics < ActiveRecord::Migration
  def change
    create_table :tags_topics do |t|
      t.integer :topic_id
      t.integer :tag_id

      t.timestamps null: false
    end
  end
end
