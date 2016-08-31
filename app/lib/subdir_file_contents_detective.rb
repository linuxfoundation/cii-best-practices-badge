# frozen_string_literal: true
# Examine repository files at the top level and in key subdirectories
# (those conventionally used for source and documentation).
# Note that a key precondition is determining how to open repo files.

# frozen_string_literal: true

class SubdirFileContentsDetective < Detective
  INPUTS = [:repo_files].freeze
  OUTPUTS = %i(
    contribution_status license_location_status release_notes_status
    build_status build_common_tools_status
  ).freeze
  DOCS_BASICS = {
    folder: /\Adoc(s|umentation)?\Z/i,
    file: /(\.md|\.markdown|\.txt|\.html)?\Z/i,
    contents: [/install(ation)?/i, /us(e|ing)/i, /secur(e|ity)/i].freeze
  }.freeze

  def unmet_result(result_description)
    {
      value: 'Unmet',
      confidence: 1,
      explanation: "No #{result_description} file(s) found."
    }
  end

  def met_result(result_description)
    {
      value: 'Met',
      confidence: 3,
      explanation: "Some #{result_description} file contents found."
    }
  end

  def match_fso?(fso, type, name_pattern)
    fso['type'] == type && fso['name'].match(name_pattern)
  end

  def folder_named(name_pattern)
    @top_level.select do |fso|
      return fso['name'] if match_fso?(fso, 'dir', name_pattern)
    end
    nil
  end

  def get_content(fso, repo_files)
    content = repo_files.get_info(fso['path'])['content']
    encoding = fso['encoding']
    content = Base64.decode64(content) if encoding.nil? || encoding == 'base64'
    content
  end

  def get_relevant_files(repo_files, folder, patterns)
    files = repo_files.get_info(folder)
    files.select { |f| match_fso?(f, 'file', patterns[:file]) }
  end

  def match_file_contents(fso, content, pattern)
    match = content.match(pattern)
    Rails.logger.info('SubdirFileContentsDetective: ' + fso['path'] +
        ' matches?: ' + (match ? 'yes' : 'no'))
    match
  end

  def match_file_content(repo_files, folder, patterns, description)
    files = get_relevant_files(repo_files, folder, patterns)
    files.select do |f|
      content = get_content(f, repo_files)
      patterns[:contents].each do |p|
        return met_result description if match_file_contents(f, content, p)
      end
    end
    unmet_result description
  end

  def determine_content_results(repo_files, status, patterns, description)
    folder = folder_named(patterns[:folder])
    @results[status] =
      if folder.nil?
        unmet_result description
      else
        # match_file_content(repo_files.get_info(folder), patterns, description)
        match_file_content(repo_files, folder, patterns, description)
      end
  end

  def analyze(_evidence, current)
    repo_files = current[:repo_files]
    return {} if repo_files.blank?
    @results = {}

    # Top_level is iterable, contains a hash with name, size, type (file|dir).
    @top_level = repo_files.get_info('/')
    determine_content_results(
      repo_files, :documentation_basics_status, DOCS_BASICS,
      'documentation basics'
    )
    @results
  end
end
