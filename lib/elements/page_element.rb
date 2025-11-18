require_relative '../page_object'
require_relative './elements_helper'

class PageElement
  include Capybara::DSL
  include ElementsHelper

  attr_accessor :element

  def initialize(element)
    @element = element
    additional_locators
  end

  def additional_locators; end

  def click
    scroll_to @element
    @element.click
    self
  end
end

