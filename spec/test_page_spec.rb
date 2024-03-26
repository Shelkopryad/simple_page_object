# frozen_string_literal: true
require_relative '../spec_helper'
require_relative '../src/pages/my_artec/login_page'
require_relative '../src/pages/my_artec/home_page'
require_relative '../src/pages/crm/new_order_page'

feature 'Page Object' do
  scenario 'it works' do
    visit 'https://staging-booth-my.artec3d.com'
    ma_login_page = PageObject::MA::LoginPage.new
    puts ma_login_page.current_url
    ma_login_page.login_with email: 'welkopr9d@gmail.com',
                             password: 'qwerty$4'
    visit 'https://staging.arteccrm.com'

    # binding.pry
    # crm_order_page = PageObject::CRM::NewOrderPage.new
    # crm_order_page.set_attributes distr: 'welkopr9d@gmail.com', client: 'artec-user-2712@yandex.ru'

  end
end