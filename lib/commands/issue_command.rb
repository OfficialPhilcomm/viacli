require "tty-option"
require "launchy"

module Via
  class IssueCommand
    include TTY::Option

    usage do
      program "via"
      command "issue"

      description "Open a specific GitHub issue"
    end

    argument :issue_id do
      required
      desc "GitHub Issue ID"
      convert Integer
    end

    flag :help do
      short "-h"
      long "--help"
      desc "Print this page"
    end

    def run
      if params[:help]
        print help
        exit
      end

      if !params[:issue_id]
        print "Please provide an issue id"
      end

      Launchy.open("https://github.com/viaeurope/viaeurope/issues/#{params[:issue_id]}")
    end
  end
end
