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

  def set_config(opts = {})
    f = File.new(@config_path, 'w')
    f.write(opts.to_json)
    f.close
    opts
  end

  def get_body(url)
    doc = Nokogiri::HTML(open(url))
    items = doc.css(".question .post-text")
    return items[0].inner_html if items.present?
  end

  def fetch
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
        username = item['owner']['display_name'].gsub(/[^\w|\-|_]/, "")
        username = "#{username}#{rand(0..100)}" if username.length < 3

        yield({
          user: {
            email: "#{item['owner']['user_id']}@stackoverflow.com",
            username: username,
            password: "#{item['owner']['user_id']}stackoverflow#{item["question_id"]}"
          },
          topic: {
            id: item['question_id'],
            title: item['title'],
            source_id: item['question_id'],
            source_type: 'StackOverFlow',
            tags: item["tags"],
            body: get_body(item['link'])
          }
        }) if block_given?
      end
      opts = get_config
      set_config(opts.merge(page: opts[:page]+1))
    end
  end

  def self.klass
    @instance ||= new
  end
end