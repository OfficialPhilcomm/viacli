require "httparty"

class LinearAPI
  include HTTParty

  base_uri "https://api.linear.app/"

  headers "Content-Type": "application/json"
  headers "Authorization": ENV["LINEAR_API_TOKEN"]

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
      }
    GRAPHQL
    result = self.class.post("/graphql", body: {query: "{#{query}}"}.to_json)
    result["data"]["issue"]
  end

  def get_current_issues
    query = <<~GRAPHQL
      issues(filter: {
        team: { name: { eq: "Platform" } }
        state: { name: { eq: "In Progress" } }
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
          priority
          priorityLabel
          sortOrder
          branchName
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

    issues.sort_by do |issue|
      issue["sortOrder"]
    end.first
  end
end
