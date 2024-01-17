require "httparty"

module OpenAI
  GPT_3_5_TURBO = "gpt-3.5-turbo"
  GPT_4 = "gpt-4"

  module ClassMethods
    def prompt(message)
      @prompt = message
    end

    def get_prompt
      @prompt
    end

    def model(gpt_model)
      @@model = gpt_model
    end

    def get_model
      if defined?(@@model)
        @@model
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

    response = self.class.post "/completions", body: {
      model: self.class.get_model,
      messages: @messages,
      temperature: 0.7
    }.to_json

    new_message = JSON.parse(response.body)["choices"][0]["message"]
    @messages << new_message
    new_message["content"]
  end
end
