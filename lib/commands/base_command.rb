require "tty-option"

module Via
  class BaseCommand
    include TTY::Option

    usage do
      program "via"
      no_command

      description "Via Toolkit",
        "\nCommands:",
        "  via issue - Interact with Linear issues",
        "  via setup - Setup the project"
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
