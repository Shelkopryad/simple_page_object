require 'json'
require 'fileutils'
require 'securerandom'

module Allure
  def run_fail_step(name)
    lifecycle.start_test_step(StepResult.new(name: name, stage: Stage::RUNNING))
    result = yield
    lifecycle.update_test_step { |step| step.status = Status::FAILED }

    result
  rescue StandardError, configuration.failure_exception => e
    lifecycle.update_test_step do |step|
      step.status = ResultUtils.status(e)
      step.status_details = ResultUtils.status_details(e)
    end
    raise(e)
  ensure
    lifecycle.stop_test_step
  end
end

module AllureUtils
  def self.allure_enabled?
    ENV['ALLURE'] == 'true'
  end
end

module AllureHelper
  ALLURE_SCREENSHOTS_DIR = "#{Dir.pwd}/reports/screenshots"
  SCREENSHOT_TIME_FORMAT = '%Y%m%d%H%M%S'.freeze
  SCREENSHOT_EXTENSION = '.png'.freeze
  MAX_FILENAME_LENGTH = 100

  def add_allure_metadata(&)
    Allure.instance_eval(&) if AllureUtils.allure_enabled?
  end

  def log_step_with_screenshot(step_name)
    if AllureUtils.allure_enabled?
      Allure.run_step step_name do
        attach_screenshot(step_name)
      end
    end
    puts step_name
  end

  def log_fail_step_with_screenshot(fail_message)
    if AllureUtils.allure_enabled?
      step_name = build_fail_step_name(fail_message)
      Allure.run_fail_step step_name do
        attach_screenshot('Test failed')
      end
    end

    puts fail_message
  end

  def log_step(step_name, status: :passed)
    if AllureUtils.allure_enabled?
      Allure.step name: step_name, status: status
    end

    puts step_name
  end

  def log_step_params(step_name, params)
    return unless params.is_a?(Hash)

    if AllureUtils.allure_enabled?
      Allure.run_step step_name do
        params.each do |key, value|
          param = value.is_a?(Array) || value.is_a?(Hash) ? JSON.generate(value) : value
          Allure.step_parameter key, param
        end
      end
    end

    puts params.inspect
  end

  def attach_screenshot(step_name)
    return unless AllureUtils.allure_enabled?

    ensure_screenshots_directory_exists

    screenshot_name = generate_screenshot_filename(step_name)
    screenshot_path = File.join(ALLURE_SCREENSHOTS_DIR, screenshot_name)

    begin
      native_page.screenshot(path: screenshot_path)
      Allure.add_attachment name: screenshot_name,
                            source: File.new(screenshot_path),
                            type: Allure::ContentType::PNG
    rescue StandardError => e
      puts "Failed to attach screenshot: #{e.message}"
    end
  end

  def attach_description(description)
    return unless AllureUtils.allure_enabled?
    return if description.nil? || description.empty?

    Allure.add_description description
  end

  private

  def generate_screenshot_filename(step_name)
    sanitized_name = sanitize_filename(step_name)
    timestamp = Time.now.strftime(SCREENSHOT_TIME_FORMAT)
    unique_id = SecureRandom.hex(4)
    pid = Process.pid

    filename = "#{sanitized_name}_#{pid}_#{unique_id}_#{timestamp}#{SCREENSHOT_EXTENSION}"
    filename.downcase
  end

  def sanitize_filename(filename)
    return 'screenshot' if filename.nil? || filename.empty?

    sanitized = filename.gsub(/[\/\\:*?"<>|]/, '_')
    sanitized = sanitized.gsub(/[\s_]+/, '_')
    sanitized = sanitized.strip
    sanitized = sanitized[0, MAX_FILENAME_LENGTH] if sanitized.length > MAX_FILENAME_LENGTH
    sanitized.empty? ? 'screenshot' : sanitized
  end

  def build_fail_step_name(fail_message)
    url = safe_current_url
    base_message = fail_message.to_s.strip

    if base_message.empty?
      url ? "Test failed on the page #{url}" : 'Test failed'
    elsif url
      "Test failed: #{base_message} (page: #{url})"
    else
      "Test failed: #{base_message}"
    end
  end

  def safe_current_url
    begin
      native_page.url
    rescue StandardError => e
      puts "Failed to get current URL: #{e.message}"
      nil
    end
  end

  def ensure_screenshots_directory_exists
    return if Dir.exist?(ALLURE_SCREENSHOTS_DIR)

    begin
      FileUtils.mkdir_p(ALLURE_SCREENSHOTS_DIR)
      puts "Created screenshots directory: #{ALLURE_SCREENSHOTS_DIR}"
    rescue StandardError => e
      puts "Failed to create screenshots directory: #{e.message}"
      raise
    end
  end
end

def log_step_with_screenshot(step_name)
  helper = Object.new.extend(AllureHelper)
  helper.log_step_with_screenshot(step_name)
end

def log_fail_step_with_screenshot(fail_message)
  helper = Object.new.extend(AllureHelper)
  helper.log_fail_step_with_screenshot(fail_message)
end

def log_step(step_name, status: :passed)
  helper = Object.new.extend(AllureHelper)
  helper.log_step(step_name, status: status)
end

def log_step_params(step_name, params)
  helper = Object.new.extend(AllureHelper)
  helper.log_step_params(step_name, params)
end

def attach_screenshot(step_name)
  helper = Object.new.extend(AllureHelper)
  helper.attach_screenshot(step_name)
end

def attach_description(description)
  helper = Object.new.extend(AllureHelper)
  helper.attach_description(description)
end
