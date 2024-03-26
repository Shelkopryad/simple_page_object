# frozen_string_literal: true
module ElementsHelper
  def with_retries(name, action: :find, path: nil)
    retries = 0
    begin
      case action
      when :find
        result = find(:xpath, path)
      when :all
        result = all(:xpath, path)
      else
        raise ArgumentError, "Unknown action: #{action}"
      end
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
      sleep 1
      retries += 1
      retry if retries < 5
      raise "Too many retries for element #{name}"
    end
    if result.nil? || (result.is_a?(Array) && result.empty?)
      raise "Could not find element #{name} after 5 retries. Please check xPath [#{path}]"
    end
    result
  end

  def retriable_all(name, path)
    with_retries name, action: :all, path: path
  end

  def retriable_find(name, path)
    with_retries name, action: :find, path: path
  end
end
