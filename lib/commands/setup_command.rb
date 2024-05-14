require_relative "../linear_api"
require_relative "../persistent_memory"

module Via
  class SetupCommand
    include TTY::Option

    usage do
      program "via"
      command "setup"

      description "Sets up the project"
    end

    def run
      return print(help) if params[:help]
      return puts(params.errors.summary) if params.errors.any?

      PersistentMemory
        .new("user_id")
        .state = LinearAPI.new.get_viewer_id
    end
  end
end
