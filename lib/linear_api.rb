require "httparty"
require_relative "persistent_memory"

class LinearAPI
  include HTTParty

  base_uri "https://api.linear.app/"

  headers "Content-Type": "application/json"
  headers "Authorization": ENV["LINEAR_API_TOKEN"]

  STATE_IN_PROGRESS = "c692bedf-432b-40ba-acbb-3657ad8113e2"

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
    result["data"]["issue"]
  end

  def get_current_issues
    query = <<~GRAPHQL
      issues(filter: {
        team: { name: { eq: "Platform" } }
        state: { name: { in: ["In Progress", "Review"] } }
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
    result["data"]["issues"]["nodes"]
  end

  def get_next_cycle_issue
    query = <<~GRAPHQL
      cycles(filter: {
        isActive: { eq: true }
        team: { name: { eq: "Platform" } }
      }) {
        nodes {
          issues(
            filter: {
              state: { name: { eq: "To Do" } }
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

    issues.sort_by do |issue|
      [priority_map[issue["priority"]], issue["sortOrder"]]
    end.first
  end

  def assign_issue(issue_id)
    user_id = PersistentMemory.new("user_id").state
    return puts("User ID not set. Use via setup") if user_id.nil?

    query = <<~GRAPHQL
      issueUpdate(
        id: "#{issue_id}",
        input: {
          stateId: "#{STATE_IN_PROGRESS}",
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

  def get_viewer_id
    query = <<~GRAPHQL
      viewer {
        id
      }
    GRAPHQL
    result = self.class.post("/graphql", body: {query: "{#{query}}"}.to_json)
    result["data"]["viewer"]["id"]
  end
end
