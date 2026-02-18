require './lib/page_object'

class GithubRepoPage < Page
  element :forks, '//a[@id="fork-button"]/span[@id="repo-network-counter"]'

  def initialize(log_init: true)
    super page_name: 'Github Repository Page', log_init: log_init
    validate_presence :forks
  end

  def fork_counter
    forks.inner_text
  end
end
