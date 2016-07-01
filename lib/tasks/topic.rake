require File.expand_path("../../stackoverflow_api", __FILE__)

namespace :topic do

  task :fetch_stackoverflow => :environment do

    StackoverflowApi.klass.fetch do |item|
      user = User.find_or_initialize_by(email: item[:user][:email])
      user.username = item[:user][:username]
      user.trust_level = 0
      user.password = item[:user][:password]
      if user.save
        topic = Topic.find_or_initialize_by(
          source_type: item[:topic][:source_type],
          source_id: item[:topic][:source_id]
        )
        topic.title = item[:topic][:title]
        topic.visible = false
        topic.category = Category.first
        topic.user = user
        unless topic.persisted?
          if topic.save
            topic.posts.create(
              raw: item[:topic][:body],
              user: user
            )
            puts "topic: #{item[:topic][:source_id]}"
          else
            puts "topic errors: #{topic.errors.full_messages}"
          end
        end
      else
        puts "user errors: #{user.errors.full_messages}, #{item[:topic][:id]}"
      end
    end

  end
end