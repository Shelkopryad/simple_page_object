require './lib/page_object'

class GithubMainPage < Page
  element :search_span, '//span[contains(text(), "Search or jump to...")]'
  element :search_input, '//input[@id="query-builder-test"]'

  def initialize(log_init: true)
    super page_name: 'Github Main Page', log_init: log_init
  end

  def search_for(value)
    search_span.click
    search_input.type value
    search_input.press 'Enter'
  end
end

