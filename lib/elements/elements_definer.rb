require_relative './elements_helper'

module ElementDefiner

  include ElementsHelper

  def element(name, path, type = :xpath)
    define_method name do
      retriable_find(name, path, type)
    end

    define_path_method name, path
  end

  # Defines a new elements_collection
  # @param [Symbol] collection_name
  # @param [String] path
  # @!macro [name] elements
  def elements(collection_name, path, type = :xpath)
    define_method collection_name do
      with_retries(collection_name, action: :all, type: type, path: path)
    end

    define_path_method collection_name, path
  end

  def define_path_method(element_name, path)
    define_method "#{element_name}_path" do
      path
    end
  end

  def block(name, clazz, *args, &block)
    define_method name do
      clazz.new(*args, &block)
    end
  end
end
