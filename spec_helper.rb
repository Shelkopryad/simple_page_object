require 'rspec'
require 'yaml'
require 'pry'
require './helpers/allure_helper'
require 'playwright'
require 'rspec-wait'
require 'allure-rspec'
require 'digest'

def project_config
  YAML.load File.read('./rspec_config.yml')
end

def github_main_page
  'https://github.com/'
end

def ma_url
  'https://staging-booth-my.artec3d.com'
end

def crm_url
  'https://staging.arteccrm.com'
end

module PlaywrightDriver
  extend self

  attr_reader :playwright, :browser, :page

  def start!
    @playwright = Playwright.create(playwright_cli_executable_path: "#{Dir.pwd}/node_modules/playwright/cli.js")
    @browser = @playwright.playwright.chromium.launch(
      headless: ENV['HEADLESS'] == 'true',
      args: ['--no-sandbox', '--disable-gpu', '--ignore-certificate-errors', '--window-size=1600,1200']
    )
    @page = @browser.new_page(
      viewport: { width: 1600, height: 1200 },
      record_video_dir: 'reports/videos'
    )
  end

  def quit!
    @page&.close
    unless (video = @page&.video).nil?
      video.delete
    end

    @browser&.close
    @playwright&.stop
    @page = @browser = @playwright = nil
  end

  def save_video(example)
    return unless (video = @page&.video)

    file_name = "#{example.description.gsub(/\s+/, '_').gsub(/[^0-9A-Za-z_]/, '')}.webm"
    final_path = File.join(Dir.pwd, 'reports/videos', file_name)

    FileUtils.mkdir_p(File.dirname(final_path))
    @page&.close
    video.save_as(final_path)

    if AllureUtils.allure_enabled? && File.exist?(final_path)
      Allure.add_attachment(
        name: "video-#{example.description}",
        source: File.read(final_path),
        type: Allure::ContentType::WEBM,
        test_case: true
      )
    end
  end
end

def native_page
  PlaywrightDriver.page
end

RSpec.configure do |config|
  config.include AllureHelper
  config.formatter = AllureUtils.allure_enabled? ? AllureRspecFormatter : :documentation

  if AllureUtils.allure_enabled?
    AllureRspec.configure do |c|
      c.results_directory = 'reports/allure-results'
      c.clean_results_directory = true
    end
  end

  unless ENV['WO_BROWSER'] == 'true'
    config.before(:example) do
      PlaywrightDriver.start!
    end

    config.after(:example) do |example|
      if example.exception
        log_fail_step_with_screenshot "Failed: #{example.exception.message}"
        PlaywrightDriver.save_video(example)
      end

      PlaywrightDriver.quit!
    end
  end
end
