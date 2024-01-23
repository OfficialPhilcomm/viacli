require "tty-option"
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

    argument :option do
      optional
      name "Action"
      permit %w[branch open]
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

      if params[:option] == "branch"
        if params[:checkout] && issues.one?
          system("git checkout #{issues.first["branchName"]}") || system("git checkout -b #{issues.first["branchName"]}")
        else
          puts(
            issues.map do |issue|
              issue["branchName"]
            end.join("\n")
          )
        end
      elsif params[:option] == "open"
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
        text << TTY::Markdown.parse(SummarizeModel.new.next(pastel.cyan(<<~STR)))
          Title: #{issue["title"]}
          Description: #{issue["description"]}
        STR
      when "poem"
        text << TTY::Markdown.parse(PoemizeModel.new.next(pastel.cyan(<<~STR)))
          Title: #{issue["title"]}
          Description: #{issue["description"]}
        STR
      end

      text << formatted_description

      text.join("\n\n")
    end
  end
end
