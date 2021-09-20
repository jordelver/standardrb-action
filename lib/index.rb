# frozen_string_literal: true

require "net/http"
require "json"
require "time"
require_relative "./report_adapter"
require_relative "./github_check_run_service"
require_relative "./github_client"

def read_json(path)
  JSON.parse(File.read(path))
end

@event_json = read_json(ENV["GITHUB_EVENT_PATH"]) if ENV["GITHUB_EVENT_PATH"]
@github_data = {
  sha: ENV["GITHUB_SHA"],
  token: ENV["GITHUB_TOKEN"],
  owner: ENV["GITHUB_REPOSITORY_OWNER"] || @event_json.dig("repository", "owner", "login"),
  repo: ENV["GITHUB_REPOSITORY_NAME"] || @event_json.dig("repository", "name"),
}

puts ENV["FILES_TO_CHECK"].inspect

@report =
  if ENV["REPORT_PATH"]
    read_json(ENV["REPORT_PATH"])
  else
    Dir.chdir(ENV["GITHUB_WORKSPACE"]) do
      if ENV["FILES_TO_CHECK"]
        # Run on selected files if there are any
        if !ENV["FILES_TO_CHECK"].empty?
          JSON.parse(`standardrb --parallel -f json #{ENV["FILES_TO_CHECK"]}`)
        end
      else
        # Run over the whole codebase
        JSON.parse(`standardrb --parallel -f json`)
      end
    end
  end

GithubCheckRunService.new(@report, @github_data, ReportAdapter).run
