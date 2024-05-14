require "json"
require "httparty"
require "event_stream_parser"

module OpenAI
  GPT_3_5_TURBO = "gpt-3.5-turbo"
  GPT_4_TURBO = "gpt-4-turbo"

  module ClassMethods
    def prompt(message)
      @prompt = message
    end

    def get_prompt
      @prompt
    end

    def model(gpt_model)
      @model = gpt_model
    end

    def get_model
      if defined?(@model)
        @model
      else
        GPT_3_5_TURBO
      end
    end
  end

  def self.included(base)
    base.extend(ClassMethods)
    base.include(HTTParty)

    base.base_uri "https://api.openai.com/v1/chat"
    base.headers "Content-Type": "application/json"
    base.headers "Authorization": "Bearer #{ENV["OPENAI_API_TOKEN"]}"
  end

  def initialize
    @messages = [{"role" => "system", "content" => self.class.get_prompt}]
  end

  def next(message)
    @messages << {"role" => "user", "content" => message}

    new_message = {"content" => ""}
    parser = EventStreamParser::Parser.new

    self.class.post "/completions", body: {
      model: self.class.get_model,
      messages: @messages,
      temperature: 0.7,
      stream: true
    }.to_json do |fragment|
      next unless fragment.code == 200

      parser.feed(fragment) do |_type, data, _id, _reconnection_time|
        if data != "[DONE]"
          delta = JSON.parse(data)["choices"][0]["delta"]

          new_message["role"] = delta["role"] if delta["role"]
          new_message["content"] += delta["content"] if delta["content"]

          yield(delta["content"]) if block_given?
        end
      end
    end

    @messages << new_message
    new_message["content"]
  end
end
