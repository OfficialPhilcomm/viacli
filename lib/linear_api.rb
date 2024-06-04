require "json"
require "httparty"
require_relative "persistent_memory"
require_relative "models/issue"

class LinearAPI
  include HTTParty

  base_uri "https://api.linear.app/"

  headers "Content-Type": "application/json"
  headers "Authorization": ENV["LINEAR_API_TOKEN"]

  TEAM = PersistentMemory.new("team_id").state
  STATE_TO_DO = PersistentMemory.new("to_do_state_id").state
  STATE_ASSIGN = PersistentMemory.new("assign_state_id").state
  STATE_IN_PROGRESS = PersistentMemory.new("in_progress_state_ids").state
  STATE_FINSIH = PersistentMemory.new("finish_state_id").state

  def get_issue(ref)
    query = <<~GRAPHQL
      issue(id: "#{ref}") {
        identifier
        title
        description
        state {
          name
        }
        priority
        priorityLabel
        sortOrder
        branchName
        comments {
          nodes {
            body
            user {
              name
            }
          }
        }
      }
    GRAPHQL
    result = self.class.post("/graphql", body: {query: "{#{query}}"}.to_json)
    Issue.new(result["data"]["issue"])
  end

  def get_current_issues
    query = <<~GRAPHQL
      issues(filter: {
        team: { id: { eq: "#{TEAM}" } }
        state: { id: { in: [#{in_progress_states_string}] } }
        assignee: {
          isMe: { eq: true }
        }
      }) {
        nodes {
          identifier
          title
          description
          state {
            name
          }
          assignee {
            name
            id
          }
          priority
          priorityLabel
          sortOrder
          branchName
          comments {
            nodes {
              body
              user {
                name
              }
            }
          }
        }
      }
    GRAPHQL
    result = self.class.post("/graphql", body: {query: "{#{query}}"}.to_json)
    result["data"]["issues"]["nodes"].map do |issue|
      Issue.new(issue)
    end
  end

  def get_next_cycle_issue
    query = <<~GRAPHQL
      cycles(filter: {
        isActive: { eq: true }
        team: { id: { eq: "#{TEAM}" } }
      }) {
        nodes {
          issues(
            filter: {
              state: { id: { eq: "#{STATE_TO_DO}" } }
              assignee: {
                null: true
              }
            }
          ) {
            nodes {
              identifier
              title
              description
              state {
                name
              }
              priority
              priorityLabel
              sortOrder
              branchName
            }
          }
        }
      }
    GRAPHQL

    result = self.class.post("/graphql", body: {query: "{#{query}}"}.to_json)
    issues = result["data"]["cycles"]["nodes"].first["issues"]["nodes"]

    priority_map = [5, 1, 2, 3, 4]

    issue = issues.sort_by do |issue|
      [priority_map[issue["priority"]], issue["sortOrder"]]
    end.first

    Issue.new(issue)
  end

  def assign_issue(issue_id)
    user_id = PersistentMemory.new("user_id").state
    return puts("User ID not set. Use via setup") if user_id.nil?

    query = <<~GRAPHQL
      issueUpdate(
        id: "#{issue_id}",
        input: {
          stateId: "#{STATE_ASSIGN}",
          assigneeId: "#{user_id}"
        }
      ) {
        success
        issue {
          identifier
        }
      }
    GRAPHQL
    result = self.class.post("/graphql", body: {query: "mutation {#{query}}"}.to_json)
    result["data"]
  end

  def finish_issue(issue_id)
    user_id = PersistentMemory.new("user_id").state
    return puts("User ID not set. Use via setup") if user_id.nil?

    query = <<~GRAPHQL
      issueUpdate(
        id: "#{issue_id}",
        input: {
          stateId: "#{STATE_FINSIH}"
        }
      ) {
        success
        issue {
          identifier
        }
      }
    GRAPHQL
    result = self.class.post("/graphql", body: {query: "mutation {#{query}}"}.to_json)
    result["data"]
  end

  def get_viewer_id
    query = <<~GRAPHQL
      viewer {
        id
      }
    GRAPHQL
    result = self.class.post("/graphql", body: {query: "{#{query}}"}.to_json)
    result["data"]["viewer"]["id"]
  end

  def teams
    query = <<~GRAPHQL
      viewer {
        teams {
          nodes {
            id
            name
          }
        }
      }
    GRAPHQL
    result = self.class.post("/graphql", body: {query: "{#{query}}"}.to_json)
    result["data"]["viewer"]["teams"]["nodes"]
  end

  def states(team_id)
    query = <<~GRAPHQL
      team(id: "#{team_id}") {
        states {
          nodes {
            id
            name
          }
        }
      }
    GRAPHQL
    result = self.class.post("/graphql", body: {query: "{#{query}}"}.to_json)
    result["data"]["team"]["states"]["nodes"]
  end

  private

  def in_progress_states_string
    STATE_IN_PROGRESS.split("\n").map do |state|
      "\"#{state}\""
    end.join(", ")
  end
end
