require 'rspec-wait'
require './spec_helper'
require 'waitutil'

# Defines page and block classes
# @example
#   class Footer < Block
#     element :contact_us, '//a[@id="contact-us"]'
#   end
#
#   class LoginPage < Page
#     element :login, '//input[@id="login"]'
#     element :password, '//input[@id="login"]'
#     element :submit, '//input[@id="submit"]'
#
#     block :footer, Footer
#
#     def initialize
#       super('Login Page')
#       validate_presence :login, :password
#     end
#
#     def login(creds)
#       login.set(creds[:email])
#       password.set(creds[:password])
#       submit.click
#     end
#
#     def go_to_contact_form
#       footer.contact_us.click
#     end
#   end
class Page
  include AllureHelper

  def self.block(name, clazz, *args, &block)
    define_method name do
      clazz.new(*args, &block)
    end
  end

  def self.element(name, path, type = :xpath)
    define_method name do
      native_page.locator(path)
    end

    define_path_method name, path
  end

  def self.elements(collection_name, path, type = :xpath)
    define_method collection_name do
      all(type, path)
    end

    define_path_method collection_name, path
  end

  def self.define_path_method(element_name, path)
    define_method "#{element_name}_path" do
      path
    end
  end

  def validate_presence(*elements)
    elements.each do |el_name|
      path = send("#{el_name}_path")
      puts "Checking presence of: #{el_name}"
      native_page.locator(path).wait_for(state: 'visible', timeout: 10_000)
    end
  end

  def initialize(page_name:, log_init: true)
    wait_for_page_loaded
    log_step_with_screenshot "The page #{page_name} is successfully loaded" if log_init
  end

  def wait_for_page_loaded(timeout: 30_000)
    native_page.wait_for_load_state(state: 'networkidle', timeout: timeout)
  rescue Playwright::TimeoutError
    puts "Warning: Page load timed out (networkidle), but continuing..."
  end
end

class Block < Page
  def initialize(page_name:)
    super(page_name: page_name, log_init: false)
    log_step "The block #{page_name} is successfully loaded"
  end
end
