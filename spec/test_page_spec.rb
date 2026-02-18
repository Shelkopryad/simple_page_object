require './spec_helper'
require_relative '../pages/github_main_page'
require_relative '../pages/github_repos_page'
require_relative '../pages/github_repo_page'


describe 'Page Object' do
  it 'it works' do
    native_page.goto github_main_page
    github_page = GithubMainPage.new
    github_page.search_for 'playwright-ruby-client'
    repos_page = GithubReposPage.new
    repos_page.open_repo_by_author 'YusukeIwaki'
    repo_page = GithubRepoPage.new
    expect(repo_page.fork_counter).to eq '48'
  end
end