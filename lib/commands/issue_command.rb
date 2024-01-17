require "tty-option"
require "tty-markdown"
require "pastel"
require_relative "../linear_api"

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
      permit %w[branch]
    end

    flag :help do
      short "-h"
      long "--help"
      desc "Print this page"
    end

    def run
      if params[:help]
        print help
      elsif params.errors.any?
        puts params.errors.summary
      else
        issues = case params[:id]
        when "current"
          LinearAPI.new.get_current_issues
        when "next"
          [LinearAPI.new.get_next_cycle_issue]
        else
          [LinearAPI.new.get_issue(params[:id])]
        end

        if params[:option] == "branch"
          puts(
            issues.map do |issue|
              issue["branchName"]
            end.join("\n")
          )
        else
          puts(issues.map do |issue|
            issue_to_text(issue)
          end.join("\n\n"))
        end
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

      <<~TEXT
        #{pastel.cyan(issue["identifier"])}: #{pastel.green(issue["title"])}

        #{formatted_description}
      TEXT
    end
  end
end
