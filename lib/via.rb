require "tty-option"
require_relative "commands/base_command"
require_relative "commands/setup_command"
require_relative "commands/issue_command"

module Via
  def self.init
    cmd, args = case ARGV[0]
    when "issue", "i"
      [Via::IssueCommand.new, ARGV[1..]]
    when "setup"
      [Via::SetupCommand.new, ARGV[1..]]
    else
      [Via::BaseCommand.new, ARGV]
    end

    cmd.parse args
    cmd.run
  end
end
