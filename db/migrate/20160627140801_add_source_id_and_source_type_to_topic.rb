class AddSourceIdAndSourceTypeToTopic < ActiveRecord::Migration
  def change
    add_column :topics, :source_id, :integer, comment: "来源id"
    add_column :topics, :source_type, :string, comment: "来源类型"
  end
end
