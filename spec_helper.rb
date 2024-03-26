require 'capybara'
require 'capybara/dsl'
require 'capybara/rspec'
require 'rspec'
require 'selenium/webdriver'
require 'yaml'
require 'pry'

def project_config
  YAML.load File.read('./config.yml')
end

Capybara.register_driver :chrome do |app|
  chrome_args = []
  chrome_args << %w[headless disable-gpu] if ENV['HEADLESS']
  chrome_args << %w{no-sandbox user-data-dir=/root} if ENV['DOCKERIZED']
  chrome_args.flatten!

  p "chrome args: #{chrome_args}"
  prefs = {
    download: {
      prompt_for_download: false,
      extensions_to_open: 'dmg, pdf, exe',
      default_directory: "#{Dir.pwd}/downloads"
    }
  }
  capabilities = Selenium::WebDriver::Remote::Capabilities.chrome(
    'goog:chromeOptions': { args: chrome_args, prefs: prefs }
  )
  Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    timeout: 300,
    # desired_capabilities: capabilities,
    clear_local_storage: true,
    clear_session_storage: true
  )
end

Capybara.configure do |config|
  config.run_server = false
  config.default_driver = :chrome
  config.javascript_driver = :chrome
  config.default_max_wait_time = 10

  puts "PID: #{Process.pid} \n"
end

RSpec.configure do |config|
  config.formatter = :documentation
  config.tty = true
  config.before(:suite) do |x|
    Capybara.page.driver.browser.manage.window.maximize if ENV['BROWSER']
  end
end

