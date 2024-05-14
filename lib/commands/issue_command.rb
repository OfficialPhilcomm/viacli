require "git"
require "tty-option"
require "tty-prompt"
require "tty-markdown"
require "pastel"
require "launchy"
require_relative "../linear_api"
require_relative "../openai"
require_relative "../persistent_memory"
require_relative "../markdown_formatter"

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

class AskGPTModel
  include OpenAI

  model OpenAI::GPT_4_TURBO

  def initialize(issue)
    self.class.prompt <<~PROMPT
      Here is a tech issue. Please assist with any questions.

      Title: #{issue["title"]}
      Description: #{issue["description"]}
    PROMPT

    @messages = [{"role" => "system", "content" => self.class.get_prompt}]
  end
end

module Via
  class IssueCommand
    include TTY::Option

    usage do
      program "via"
      command "issue"

      description "Open a specific GitHub issue"
    end

    argument :id do
      required
      desc "Linear Issue ID"
    end

    flag :help do
      short "-h"
      long "--help"
      desc "Print this page"
    end

    flag :checkout do
      short "-c"
      long "--checkout"
      desc "Checkout to the issue branch"
    end

    flag :open do
      short "-o"
      long "--open"
      desc "Opens the issue on Linear"
    end

    flag :assign do
      short "-a"
      long "--assign"
      desc "Assigns the issue on Linear, and sets it to In Progress"
    end

    flag :select do
      short "-s"
      long "--select"
      desc "Allow selection of specific issue"
    end

    flag :gpt do
      short "-g"
      long "--gpt"
      desc "Let GPT answer questions"
    end

    option :format do
      short "-f"
      long "--format string"
      desc "Format of the output"
      default "markdown"
      permit %w[markdown summary poem]
    end

    def run
      return print(help) if params[:help]
      return puts(params.errors.summary) if params.errors.any?

      issues = resolve_issues

      return puts("No issues found") if issues.none?

      last_issues.state = issues.map {|issue| issue["identifier"]}.join("\n")

      issues = [select_issue(issues)] if params[:select]

      if params[:gpt]
        issue = select_issue(issues)

        ask_gpt(issue)
      elsif params[:checkout]
        git = Git.open(Dir.pwd)
        issue = select_issue(issues)
        git.branch(issue["branchName"]).checkout
      elsif params[:open]
        issues.each do |issue|
          Launchy.open("https://linear.app/viaeurope/issue/#{issue["identifier"]}")
        end
      elsif params[:assign]
        issue = select_issue(issues)
        result = LinearAPI.new.assign_issue(issue["identifier"])

        if result["issueUpdate"]["success"]
          puts "You are now assigned to issue #{result["issueUpdate"]["issue"]["identifier"]}"
        else
          puts "Something went wrong"
        end
      else
        puts(issues.map do |issue|
          issue_to_text(issue)
        end.join("\n\n"))
      end
    end

    def issue_to_text(issue)
      pastel = Pastel.new

      formatted_description = TTY::Markdown
        .parse(
          issue["description"].gsub(/~.*~/) do |str|
            pastel.strikethrough(str[1..-2])
          end
        )

      text = ["#{pastel.cyan(issue["identifier"])}: #{pastel.green(issue["title"])}"]

      case params[:format]
      when "summary"
        text << pastel.bright_green(pastel.strip(TTY::Markdown.parse(SummarizeModel.new.next(<<~STR))))
          Title: #{issue["title"]}
          Description: #{issue["description"]}
        STR
      when "poem"
        text << pastel.bright_green(pastel.strip(TTY::Markdown.parse(PoemizeModel.new.next(<<~STR))))
          Title: #{issue["title"]}
          Description: #{issue["description"]}
        STR
      end

      text << formatted_description

      if issue.has_key? "comments"
        issue["comments"]["nodes"].each do |comment|
          formatted_comment = pastel.green(comment["user"]["name"] + " commented:") + "\n" + TTY::Markdown.parse(comment["body"])
          text << formatted_comment.chomp
        end
      end

      text.join("\n\n")
    end

    def select_issue(issues)
      return issues.first if issues.one?

      pastel = Pastel.new

      formatted_issues = issues.map do |issue|
        {name: "#{pastel.cyan(issue["identifier"])}: #{pastel.green(issue["title"])}", value: issue}
      end

      prompt = TTY::Prompt.new
      prompt.select("Which issue?", formatted_issues)
    end

    def resolve_issues
      case params[:id]
      when "current"
        LinearAPI.new.get_current_issues
      when "next"
        [LinearAPI.new.get_next_cycle_issue]
      when "last"
        if !last_issues.state.nil?
          last_issues.state
            .split("\n")
            .map do |ref|
              LinearAPI.new.get_issue(ref)
            end
        else
          puts "No last issue found"
          exit 1
        end
      else
        [LinearAPI.new.get_issue(params[:id])]
      end
    end

    def last_issues
      @_last_issues ||= PersistentMemory.new("last")
    end

    def ask_gpt(issue)
      gpt = AskGPTModel.new(issue)

      quit = false

      while !quit
        begin
          puts "\e[35m\e[4mUser\e[0m"
          input = STDIN.gets.chomp
          break if input == "exit"

          markdown_formatter = MarkdownFormatter.new

          puts "\n\e[32m\e[4mGPT\e[0m"
          gpt.next(input) do |chunk|
            print markdown_formatter.format(chunk)
          end

          puts "\n\n"

          # puts "#{TTY::Markdown.parse(gpt.next(input))}\n"
        rescue Interrupt
          quit = true
        end
      end
    end
  end
end
