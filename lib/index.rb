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

@event_json = read_json(ENV["GITHUB_EVENT_PATH"]) if ENV["GITHUB_EVENT_PATH"]
@github_data = {
  sha: ENV["GITHUB_SHA"],
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
