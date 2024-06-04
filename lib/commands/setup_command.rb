require "tty-prompt"
require "tty-spinner"
require "pastel"
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

      pastel = Pastel.new
      prompt = TTY::Prompt.new(quiet: true)

      linear = LinearAPI.new

      user_id_spinner = spinner("Configuring Linear API user ID based on API key")
      user_id_memory = PersistentMemory.new("user_id")
      user_id_memory.state = linear.get_viewer_id
      if user_id_memory.state.nil?
        user_id_spinner.error
      else
        user_id_spinner.success
      end

      teams = linear.teams
      team = if teams.size == 1
        teams.first
      elsif teams.size > 1
        prompt.select "Which team do you want to be configured?", teams.map { |team| { name: team["name"], value: team["id"] } }
      else
        teams_spinner = spinner("Configuring team to use")
        teams_spinner.error(pastel.red("No team found"))
        puts "No team found"
        exit 1
      end
      teams_spinner = spinner("Configuring team to use")
      PersistentMemory.new("team_id").state = team
      teams_spinner.success

      states = linear.states(team)
      states_map = states.map { |state| { name: state["name"], value: state["id"] } }

      to_do_state = prompt.select "In which state are open issues (relevant for #{pastel.yellow "via issue next"})?", states_map
      to_do_state_spinner = spinner("Configuring to do state")
      PersistentMemory.new("to_do_state_id").state = to_do_state
      to_do_state_spinner.success

      assign_state = prompt.select "What state should the issue be assigned when using #{pastel.yellow "--assign"})?", states_map
      assign_state_spinner = spinner("Configuring assign state")
      PersistentMemory.new("assign_state_id").state = assign_state
      assign_state_spinner.success

      in_progress_states = prompt.multi_select "Which state is considered \"In Progress\" (relevant for #{pastel.yellow "via issue current"})?", states_map
      in_progress_states_spinner = spinner("Configuring in progress states")
      PersistentMemory.new("in_progress_state_ids").state = in_progress_states.join("\n")
      in_progress_states_spinner.success

      finish_state = prompt.select "Which state should the issue be set to when using the #{pastel.yellow "--finish"} option?", states_map
      finish_state_spinner = spinner("Configuring finish state")
      PersistentMemory.new("finish_state_id").state = finish_state
      finish_state_spinner.success
    end

    def spinner(text)
      pastel = Pastel.new

      progress_spinner = TTY::Spinner.new(
        "[:spinner] #{text}",
        format: :classic,
        success_mark: pastel.green("✔"),
        error_mark: pastel.red("✖")
      )

      progress_spinner.auto_spin

      progress_spinner
    end
  end
end
