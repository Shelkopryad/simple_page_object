require './lib/page_object'

class GithubReposPage < Page
  element :result_list, '//div[@data-testid="results-list"]'

  def initialize(log_init: true)
    super page_name: 'Github Repositories Page', log_init: log_init
    validate_presence :result_list
  end

  def open_repo_by_author(value)
    result_list
      .locator('xpath=.//div[contains(@class,"search-title")]')
      .filter(hasText: value)
      .first.click
  end
end

