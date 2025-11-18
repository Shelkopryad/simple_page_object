module ElementsHelper

  def wait_for_ready_state(timeout: Capybara.default_max_wait_time, network_quiet_time: 0.5)
    deadline = Time.now + timeout
    quiet_since = nil

    loop do
      dom_ready = page.evaluate_script('document.readyState') == 'complete'
      inflight  = page.evaluate_script('window.__inflightCount') || 0

      if dom_ready && inflight.zero?
        quiet_since ||= Time.now
        return true if Time.now - quiet_since >= network_quiet_time
      else
        quiet_since = nil
      end

      raise 'Timeout waiting for full page load' if Time.now > deadline

      sleep 0.1
    end
  end

  def with_retries(name, action: :find, type:, path: nil, wait: nil, max_retries: 5, retry_interval: 0.5, raise_rspec: false)
    wait ||= Capybara.default_max_wait_time
    wait_for_ready_state(timeout: wait)

    retries = 0
    begin
      case action
      when :find
        result = find(type, path, wait: wait)
      when :all
        result = all(type, path, wait: wait)
      else
        raise ArgumentError, "Unknown action: #{action}"
      end
    rescue Selenium::WebDriver::Error::StaleElementReferenceError => e
      retries += 1
      Logger.debug "StaleElementReferenceError while finding #{name}, retry #{retries}/#{max_retries}: #{e.message}"
      raise e if retries > max_retries

      sleep retry_interval * (2 ** (retries - 1))
      retry
    rescue Capybara::ElementNotFound => e
      raise RSpec::Expectations::ExpectationNotMetError, e.message if raise_rspec

      raise
    end

    if result.respond_to?(:empty?) && result.empty?
      raise Capybara::ElementNotFound, "Could not find element #{name} after #{max_retries} retries. Locator: #{path}"
    end

    result
  end

  def retriable_find(name, path, type)
    with_retries name, action: :find, type: type, path: path
  end

  def validate_presence(*elements)
    missing = []

    elements.each do |element|
      Logger.debug "Check that element #{element} appears on the page"
      begin
        found = send(element)
        is_missing = if found.nil?
                       true
                     elsif found.respond_to?(:empty?)
                       found.empty?
                     else
                       false
                     end
        missing << element if is_missing
      rescue Capybara::ElementNotFound, RSpec::Expectations::ExpectationNotMetError => e
        Logger.debug "Element #{element} missing: #{e.class}: #{e.message}"
        missing << element
      end
    end

    raise "Missing elements: #{missing.join(', ')}" unless missing.empty?

    true
  end

  private :wait_for_ready_state, :with_retries
end
