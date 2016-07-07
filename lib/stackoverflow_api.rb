require 'rest-client'
require 'nokogiri'
require 'open-uri'

class StackoverflowApi

  def initialize
    @domain = 'https://api.stackexchange.com/2.2/'
    @config_path = "#{Rails.root}/spider_config"
  end

  def get_config
    if File.exists?(@config_path)
      JSON.parse(File.read(@config_path)).symbolize_keys
    else
      opts = {page: 1, pagesize: 100, fromdate: Time.parse("2015-01-01").to_i, todate: Time.parse("2016-06-30").to_i}
      set_config(opts)
    end
  end



  def fetch_by(ids = [])
    RestClient.get("#{@domain}/questions/#{ids.join(';')}", {params: {order: 'asc', sort: "activity", site: "stackoverflow"}}) do |response, request, result|
      unless response.code == 200
        puts "code: #{response.code}, #{response.body}"
        return
      end
      res = JSON.parse(response.body)
      res["items"].map do |item|
        opts = format_result(item)
        yield(opts) if block_given?
        opts
      end
    end
  end

  def fetch_answers(post_id, doc)
    RestClient.get("#{@domain}/questions/#{post_id}/answers", {params: {order: 'desc', sort: "votes", site: "stackoverflow"}}) do |response, request, result|
      unless response.code == 200
        puts "code: #{response.code}, #{response.body}"
        return
      end
      res = JSON.parse(response.body)
      res["items"].map do |item|
        {
          id: item["answer_id"],
          created_at: Time.at(item["creation_date"]),
          body: doc.css("#answer-#{item['answer_id']} .post-text").inner_html,
          post_type: item["is_accepted"] ? 2 : 1,
          user: format_user(item["owner"]),
          last_activity_date: Time.at(item["last_activity_date"])
        }
      end
    end
  end

  def fetch(&block)
    RestClient.get("#{@domain}/questions", {:params => {order: 'asc', sort: "activity", site: "stackoverflow"}.merge(get_config)}) do |response, request, result|
      unless response.code == 200
        puts "code: #{response.code}, #{response.body}"
        return
      end
      res = JSON.parse(response.body)
      if res["error_id"].present?
        puts "error: #{res}"
        return
      end

      res["items"].each do |item|
        opts = format_result(item)
        yield(opts) if block_given?
      end
      opts = get_config
      set_config(opts.merge(page: opts[:page]+1))
    end
  end

  private

  def set_config(opts = {})
    f = File.new(@config_path, 'w')
    f.write(opts.to_json)
    f.close
    opts
  end

  def resolve_content(url, doc)
    items = doc.css(".question .post-text")
    if items.present?
      return <<-HTML
        #{items[0].inner_html}
        \n
        原文链接：<a href='#{url}'>#{url}</a>
      HTML
    end
  end

  def format_result(item)
    doc = Nokogiri::HTML(open(item['link']))
    {
      user: format_user(item["owner"]),
      topic: {
        id: item['question_id'],
        title: item['title'],
        source_id: item['question_id'],
        source_type: 'StackOverFlow',
        tags: item["tags"],
        body: resolve_content(item['link'], doc),
        last_activity_date: Time.at(item["last_activity_date"]),
        answers: fetch_answers(item['question_id'], doc)
      }
    }
  end

  def format_user(item)
    username = item['display_name'].gsub(/[^\w|\-|_]/, "")
    username = "#{username}#{rand(0..100)}" if username.length < 3
    {
      email: "#{item['user_id']}@stackoverflow.com",
      username: username,
      password: "#{item['user_id']}stackoverflow"
    }
  end

  def self.klass
    @instance ||= new
  end
end