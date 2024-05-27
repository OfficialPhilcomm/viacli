require "pastel"
require "tty-markdown"
require "markdown_stream_formatter"
require_relative "../linear_api"
require_relative "../openai"

class SummarizeModel
  include OpenAI

  model OpenAI::GPT_3_5_TURBO

  prompt <<~PROMPT
    You are given a tech issue. Please give a quick summary of the issue. Thank you
  PROMPT
end

class PoemizeModel
  include OpenAI

  model OpenAI::GPT_3_5_TURBO

  prompt <<~PROMPT
    You are given a tech issue. Please summarize it in a poem. Thank you
  PROMPT
end

class Issue
  attr_reader :identifier, :title, :description, :comments, :branch

  def initialize(args)
    @identifier = args["identifier"]
    @title = args["title"]
    @description = args["description"]
    @comments = args["comments"]
    @branch = args["branchName"]
  end

  def to_markdown
    text = [title_markdown, description_markdown]
    text << comments_markdown if @comments["nodes"].any?

    text.join("\n\n")
  end

  def title_markdown
    pastel = Pastel.new

    "#{pastel.cyan(identifier)}: #{pastel.green(title)}"
  end

  def description_markdown
    pastel = Pastel.new

    TTY::Markdown
      .parse(
        description.gsub(/~.*~/) do |str|
          pastel.strikethrough(str[1..-2])
        end
      ).chomp
  end

  def comments_markdown
    pastel = Pastel.new

    @comments["nodes"].map do |comment|
      pastel.green(comment["user"]["name"] + " commented:") + "\n" + TTY::Markdown.parse(comment["body"]).chomp
    end
  end

  def summarize
    prompt = <<~STR
      Title: #{title}
      Description: #{description}
    STR

    formatter = MarkdownStreamFormatter.new
    SummarizeModel.new.next(prompt) do |chunk|
      print formatter.next(chunk)
    end
    puts "\n\n=================\n\n"

    puts to_markdown
  end

  def poemize
    prompt = <<~STR
      Title: #{title}
      Description: #{description}
    STR

    print "\e[32m"
    PoemizeModel.new.next(prompt) do |chunk|
      print chunk
    end
    puts "\e[0m\n\n"

    puts to_markdown
  end
end
