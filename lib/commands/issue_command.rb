require "git"
require "tty-option"
require "tty-prompt"
require "tty-markdown"
require "pastel"
require "launchy"
require "markdown_stream_formatter"
require_relative "../linear_api"
require_relative "../openai"
require_relative "../persistent_memory"
require_relative "../models/issue"

class AskGPTModel
  include OpenAI

  model OpenAI::GPT_4_TURBO

  def initialize(issue)
    self.class.prompt <<~PROMPT
      Here is a tech issue. Please assist with any questions.

      Title: #{issue.title}
      Description: #{issue.description}
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

      description "Interact with Linear issues"
    end

    argument :id do
      required
      desc "Linear Issue ID, can also be #{Pastel.new.yellow("next")} to fetch next unassigned issue in To Do, or #{Pastel.new.yellow("current")} for issues assigned to you that are in progress. #{Pastel.new.yellow("last")} will use the last issue interacted with."
    end

    flag :help do
      short "-h"
      long "--help"
      desc "Print this page"
    end

    flag :checkout do
      short "-c"
      long "--checkout"
      desc "Checkout the issue branch"
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
      desc "Allow selection of specific issue, if multiple are found, e.g. with #{Pastel.new.yellow("current")}"
    end

    flag :gpt do
      short "-g"
      long "--gpt"
      desc "Let GPT answer questions about the issue"
    end

    flag :finish do
      long "--finish"
      desc "Mark the issue as done"
    end

    option :format do
      short "-f"
      long "--format string"
      desc "Format of the output, and add a gpt generated summary, or poem"
      default "markdown"
      permit %w[markdown summary poem]
    end

    def run
      return print(help) if params[:help]
      return puts(params.errors.summary) if params.errors.any?

      issues = resolve_issues

      return puts("No issues found") if issues.none?

      last_issues.state = issues.map {|issue| issue.identifier}.join("\n")

      issues = [select_issue(issues)] if params[:select]

      if params[:gpt]
        issue = select_issue(issues)

        ask_gpt(issue)
      elsif params[:checkout]
        git = Git.open(Dir.pwd)
        issue = select_issue(issues)
        git.branch(issue.branch).checkout
      elsif params[:open]
        issues.each do |issue|
          Launchy.open("https://linear.app/viaeurope/issue/#{issue.identifier}")
        end
      elsif params[:assign]
        issue = select_issue(issues)
        result = LinearAPI.new.assign_issue(issue.identifier)

        if result["issueUpdate"]["success"]
          puts "You are now assigned to issue #{result["issueUpdate"]["issue"]["identifier"]}"
        else
          puts "Something went wrong"
        end
      elsif params[:finish]
        issue = select_issue(issues)
        result = LinearAPI.new.finish_issue(issue.identifier)

        if result["issueUpdate"]["success"]
          puts "Issue #{result["issueUpdate"]["issue"]["identifier"]} is now marked as done!"
        else
          puts "Something went wrong"
        end
      else
        case params[:format]
        when "summary"
          issues.each_with_index do |issue, index|
            issue.summarize

            puts "\n" if index < issues.size - 1
          end
        when "poem"
          issues.each_with_index do |issue, index|
            issue.poemize

            puts "\n" if index < issues.size - 1
          end
        else
          issues.each_with_index do |issue, index|
            puts issue.to_markdown

            puts "\n" if index < issues.size - 1
          end
        end
      end
    end

    def select_issue(issues)
      return issues.first if issues.one?

      formatted_issues = issues.map do |issue|
        {name: issue.title_markdown, value: issue}
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

          formatter = MarkdownStreamFormatter.new

          puts "\n\e[32m\e[4mGPT\e[0m"
          gpt.next(input) do |chunk|
            print formatter.next(chunk)
          end

          puts "\n\n"
        rescue Interrupt
          quit = true
        end
      end
    end
  end
end
