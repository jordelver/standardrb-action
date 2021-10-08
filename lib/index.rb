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

def run_on_select_files?
  ENV["FILES_TO_CHECK"]
end

def files_to_check?
  !ENV["FILES_TO_CHECK"].empty?
end

def commit_to_annotate(event)
  # The value of GITHUB_SHA differs based on the event type.
  # For pull_request events GITHUB_SHA is "Last merge commit on the GITHUB_REF branch"
  # For push events GITHUB_SHA is "Commit pushed, unless deleting a branch"
  # As such we use the `after` attribute which should always point to the
  # latest commit on the branch.
  event["after"]
end

@event_json = read_json(ENV["GITHUB_EVENT_PATH"]) if ENV["GITHUB_EVENT_PATH"]
@github_data = {
  sha: commit_to_annotate(@event_json),
  token: ENV["GITHUB_TOKEN"],
  owner: ENV["GITHUB_REPOSITORY_OWNER"] || @event_json.dig("repository", "owner", "login"),
  repo: ENV["GITHUB_REPOSITORY_NAME"] || @event_json.dig("repository", "name"),
}

@report =
  if ENV["REPORT_PATH"]
    read_json(ENV["REPORT_PATH"])
  else
    Dir.chdir(ENV["GITHUB_WORKSPACE"]) do
      if run_on_select_files?
        if files_to_check?
          JSON.parse(`standardrb --parallel -f json #{ENV["FILES_TO_CHECK"]}`)
        end
      else
        JSON.parse(`standardrb --parallel -f json`)
      end
    end
  end

GithubCheckRunService.new(@report, @github_data, ReportAdapter).run
