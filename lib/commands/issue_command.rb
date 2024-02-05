require "git"
require "tty-option"
require "tty-prompt"
require "tty-markdown"
require "pastel"
require "launchy"
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

      issues = case params[:id]
      when "current"
        LinearAPI.new.get_current_issues
      when "next"
        [LinearAPI.new.get_next_cycle_issue]
      else
        [LinearAPI.new.get_issue(params[:id])]
      end

      return puts("No issues found") if issues.none?

      if params[:checkout]
        git = Git.open(Dir.pwd)
        issue = select_issue(issues)
        git.branch(issue["branchName"]).checkout
      elsif params[:open]
        issues.each do |issue|
          Launchy.open("https://linear.app/viaeurope/issue/#{issue["identifier"]}")
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
  end
end
