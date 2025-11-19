require 'json'
require 'fileutils'
require 'securerandom'

# Расширение модуля Allure для принудительной отметки шагов как проваленных
module Allure
  # Выполняет шаг и принудительно помечает его как FAILED
  # Это необходимо для принудительной отметки шага как проваленного в Allure,
  # так как библиотека Allure не предоставляет такой функциональности по умолчанию
  #
  # @param name [String] имя шага
  # @yield блок кода для выполнения
  # @return [Object] результат выполнения блока
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

# Утилиты для работы с Allure
module AllureUtils
  # Проверяет, включен ли Allure через переменную окружения
  # @return [Boolean] true, если ALLURE='true'
  def self.enabled?
    ENV['ALLURE'] == 'true'
  end
end

# Модуль для работы с Allure отчетностью
# Может быть включен в spec_helper через config.include AllureHelper
module AllureHelper
  # Формат времени для имен файлов скриншотов
  SCREENSHOT_TIME_FORMAT = '%Y%m%d%H%M%S'.freeze
  # Расширение файлов скриншотов
  SCREENSHOT_EXTENSION = '.png'.freeze
  # Максимальная длина имени файла (без расширения)
  MAX_FILENAME_LENGTH = 100

  # Логирует шаг со скриншотом
  # @param step_name [String] имя шага
  # @return [void]
  def log_step_with_screenshot(step_name)
    if AllureUtils.enabled?
      Allure.run_step step_name do
        attach_screenshot(step_name)
      end
    else
      ArtecLogger.info step_name
    end
  end

  # Логирует шаг с ошибкой и скриншотом
  # @param fail_message [String] сообщение об ошибке
  # @return [void]
  def log_fail_step_with_screenshot(fail_message)
    if AllureUtils.enabled?
      step_name = build_fail_step_name(fail_message)
      Allure.run_fail_step step_name do
        attach_screenshot('Test failed')
      end
    else
      ArtecLogger.info fail_message
    end
  end

  # Логирует шаг без скриншота
  # @param step_name [String] имя шага
  # @param status [Symbol] статус шага (:passed, :failed, :skipped, :broken)
  # @return [void]
  def log_step(step_name, status: :passed)
    if AllureUtils.enabled?
      Allure.step name: step_name, status: status
    else
      ArtecLogger.info step_name
    end
  end

  # Логирует шаг с параметрами
  # @param step_name [String] имя шага
  # @param params [Hash] параметры шага (ключ-значение)
  # @return [void]
  def log_step_params(step_name, params)
    return unless AllureUtils.enabled?
    return unless params.is_a?(Hash)

    Allure.run_step step_name do
      params.each do |key, value|
        param = value.is_a?(Array) || value.is_a?(Hash) ? JSON.generate(value) : value
        Allure.step_parameter key, param
      end
    end
  end

  # Прикрепляет скриншот к Allure отчету
  # @param step_name [String] имя шага (используется для генерации имени файла)
  # @return [void]
  # @raise [StandardError] если не удалось создать скриншот
  def attach_screenshot(step_name)
    return unless AllureUtils.enabled?

    ensure_screenshots_directory_exists

    screenshot_name = generate_screenshot_filename(step_name)
    screenshot_path = File.join(ALLURE_SCREENSHOTS_DIR, screenshot_name)

    begin
      Capybara.page.save_screenshot(screenshot_path) if page_available?
      Allure.add_attachment name: screenshot_name,
                            source: File.new(screenshot_path),
                            type: Allure::ContentType::PNG
    rescue StandardError => e
      ArtecLogger.warn "Failed to attach screenshot: #{e.message}"
      # Не пробрасываем ошибку, чтобы не сломать тест из-за проблемы со скриншотом
    end
  end

  # Прикрепляет описание к Allure отчету
  # @param description [String] описание
  # @return [void]
  def attach_description(description)
    return unless AllureUtils.enabled?
    return if description.nil? || description.empty?

    Allure.add_description description
  end

  private

  # Создает безопасное имя файла скриншота
  # @param step_name [String] имя шага
  # @return [String] имя файла
  def generate_screenshot_filename(step_name)
    sanitized_name = sanitize_filename(step_name)
    timestamp = Time.now.strftime(SCREENSHOT_TIME_FORMAT)
    unique_id = SecureRandom.hex(4)
    pid = Process.pid

    filename = "#{sanitized_name}_#{pid}_#{unique_id}_#{timestamp}#{SCREENSHOT_EXTENSION}"
    filename.downcase
  end

  # Санитизирует имя файла, убирая недопустимые символы
  # @param filename [String] исходное имя файла
  # @return [String] санитизированное имя файла
  def sanitize_filename(filename)
    return 'screenshot' if filename.nil? || filename.empty?

    # Убираем недопустимые символы для файловых систем
    sanitized = filename.gsub(/[\/\\:*?"<>|]/, '_')
    # Заменяем множественные пробелы и подчеркивания на одно
    sanitized = sanitized.gsub(/[\s_]+/, '_')
    # Убираем пробелы и подчеркивания в начале и конце
    sanitized = sanitized.strip
    # Ограничиваем длину
    sanitized = sanitized[0, MAX_FILENAME_LENGTH] if sanitized.length > MAX_FILENAME_LENGTH
    # Если после санитизации имя пустое, используем значение по умолчанию
    sanitized.empty? ? 'screenshot' : sanitized
  end

  # Создает имя шага для проваленного теста
  # @param fail_message [String] сообщение об ошибке
  # @return [String] имя шага
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

  # Безопасно получает текущий URL страницы
  # @return [String, nil] текущий URL или nil, если недоступен
  def safe_current_url
    return nil unless page_available?

    begin
      Capybara.page.current_url
    rescue StandardError => e
      ArtecLogger.warn "Failed to get current URL: #{e.message}"
      nil
    end
  end

  # Проверяет, доступна ли страница Capybara
  # @return [Boolean] true, если страница доступна
  def page_available?
    defined?(Capybara) && Capybara.respond_to?(:page) && !Capybara.page.nil?
  rescue StandardError
    false
  end

  # Создает директорию для скриншотов, если она не существует
  # @return [void]
  def ensure_screenshots_directory_exists
    return if Dir.exist?(ALLURE_SCREENSHOTS_DIR)

    begin
      FileUtils.mkdir_p(ALLURE_SCREENSHOTS_DIR)
      ArtecLogger.info "Created screenshots directory: #{ALLURE_SCREENSHOTS_DIR}"
    rescue StandardError => e
      ArtecLogger.warn "Failed to create screenshots directory: #{e.message}"
      raise
    end
  end
end

# Глобальные функции для обратной совместимости
# Эти функции создают временный объект с включенным модулем AllureHelper
# и вызывают соответствующие методы

# @!method log_step_with_screenshot(step_name)
#   Глобальная функция для логирования шага со скриншотом
#   @param step_name [String] имя шага
#   @return [void]
def log_step_with_screenshot(step_name)
  helper = Object.new.extend(AllureHelper)
  helper.log_step_with_screenshot(step_name)
end

# @!method log_fail_step_with_screenshot(fail_message)
#   Глобальная функция для логирования проваленного шага со скриншотом
#   @param fail_message [String] сообщение об ошибке
#   @return [void]
def log_fail_step_with_screenshot(fail_message)
  helper = Object.new.extend(AllureHelper)
  helper.log_fail_step_with_screenshot(fail_message)
end

# @!method log_step(step_name, status: :passed)
#   Глобальная функция для логирования шага
#   @param step_name [String] имя шага
#   @param status [Symbol] статус шага
#   @return [void]
def log_step(step_name, status: :passed)
  helper = Object.new.extend(AllureHelper)
  helper.log_step(step_name, status: status)
end

# @!method log_step_params(step_name, params)
#   Глобальная функция для логирования шага с параметрами
#   @param step_name [String] имя шага
#   @param params [Hash] параметры шага
#   @return [void]
def log_step_params(step_name, params)
  helper = Object.new.extend(AllureHelper)
  helper.log_step_params(step_name, params)
end

# @!method attach_screenshot(step_name)
#   Глобальная функция для прикрепления скриншота
#   @param step_name [String] имя шага
#   @return [void]
def attach_screenshot(step_name)
  helper = Object.new.extend(AllureHelper)
  helper.attach_screenshot(step_name)
end

# @!method attach_description(description)
#   Глобальная функция для прикрепления описания
#   @param description [String] описание
#   @return [void]
def attach_description(description)
  helper = Object.new.extend(AllureHelper)
  helper.attach_description(description)
end
