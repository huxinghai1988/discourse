require File.expand_path("../../stackoverflow_api", __FILE__)
require File.expand_path("../../sanitize_view_helper", __FILE__)

namespace :topic do

  task :fetch_stackoverflow => :environment do

    StackoverflowApi.klass.fetch do |item|
      puts "item: #{item}"
      user = find_or_create(item[:user])
      if user
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
              raw: SanitizeViewHelper.untils.strip_tags(item[:topic][:body]),
              user: user,
              cooked: item[:topic][:body],
              last_version_at: item[:topic][:last_activity_date]
            )
            item[:topic][:answers].each do |answer|
              user = find_or_create(answer[:user])
              next unless user
              topic.posts.create({
                raw: SanitizeViewHelper.untils.strip_tags(answer[:body]),
                user: user,
                cooked: answer[:body],
                post_type: answer[:post_type],
                last_version_at: answer[:last_activity_date]
              })
            end
            puts "topic: #{item[:topic][:source_id]}"
          else
            puts "topic errors: #{topic.errors.full_messages}"
          end
        end

      end
    end

  end
end

def find_or_create(item)
  user = User.find_or_initialize_by(email: item[:email])
  user.username = item[:username]
  user.trust_level = 0
  user.password = item[:password]
  user.active = false
  return user if user.save
  puts "user errors: #{user.errors.full_messages}, #{item}"
end