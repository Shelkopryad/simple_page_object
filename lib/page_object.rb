require_relative './elements/elements_helper'
require_relative './elements/elements_definer'
require 'rspec-wait'

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

  include Capybara::DSL
  include ElementsHelper
  extend ElementDefiner

  def initialize(page_name:, log_init: true)
    wait_for_ready_state(timeout: Capybara.default_max_wait_time)
    log_step_with_screenshot "The page #{page_name} is successfully loaded" if log_init
  end
end

class Block < Page
  def initialize(page_name:)
    super(page_name: page_name, log_init: false)
    log_step "The block #{page_name} is successfully loaded"
  end
end
