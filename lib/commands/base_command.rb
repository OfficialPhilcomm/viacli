require "tty-option"

module Via
  class BaseCommand
    include TTY::Option

    usage do
      program "via"
      no_command

      description "Via Toolkit",
        "\nCommands:",
        "  via issue [issue] - Create a new project"
    end

    flag :help do
      short "-h"
      long "--help"
      desc "Print this page"
    end

    def run
      print help
    end
  end
end
