require 'pry'
require_relative './elements/elements_helper'

module PageObject
  class Page
    include Capybara::DSL
    include ElementsHelper

    class << self
      # Defines a new element
      # @param [Symbol] name
      # @param [String] path
      # @!macro [name] element
      def element(name, path)
        define_method name do
          retriable_find(name, path)
        end
      end

      # Defines a new elements_collection
      # @param [Symbol] collection_name
      # @param [String] path
      # @!macro [name] elements
      def elements(collection_name, path)
        define_method collection_name do
          retriable_all(collection_name, path)
        end
      end

      # Defines a new block
      # @param [Symbol] name
      # @param [Class] clazz
      # @!macro [name] block
      def block(name, clazz, *args, &block)
        define_method name do
          clazz.new(args, &block)
        end
      end
    end

    def validate_presence(*elements)
      missing_elements = []
      elements.each do |element|
        begin
          send(element)
        rescue Capybara::ElementNotFound => e
          missing_elements << element
        end
      end
      raise "Missing elements: #{missing_elements.join(', ')}" unless missing_elements.empty?
    end

    def initialize(page_name)
      puts page_name
    end
  end

  class Block < Page
  end
end


