require_relative './page_element'

class Select < PageElement
  def select(value, picking_policy)
    scroll_to @element
    @element.click
    yield if block_given?
    wait_for_options_to_appear
    pick_option value, picking_policy
  end

  def choose_random
    scroll_to @element
    @element.click
    wait_for_options_to_appear
    random_option = options.map { |it| it.text }.sample
    pick_option random_option, :include
  end

  def choose(value, picking_policy = :include)
    select value, picking_policy
  end

  def search_and_choose(value, picking_policy = :include)
    select(value, picking_policy) do
      find(:xpath, @input_xpath).set value
    end
  end

  def options
    all(:xpath, @options_xpath)
  end

  def wait_for_options_to_appear
    WaitUtil.wait_for_condition(
      'select options appears on the page',
      timeout_sec: 10,
      delay_sec: 1,
    ) { options.any? }
  end

  def pick_option(value, picking_policy)
    retries = 0
    begin
      picking_method = {
        include: :include?,
        exact_equality: '=='
      }[picking_policy]

      option_fits = proc do |option|
        option.text.send(picking_method, value)
      end
      options.select { |i| option_fits.call(i) }.first.click
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
      if retries < 5
        sleep 1
        retries += 1
        retry
      else
        raise 'Too many retries'
      end
    end
  end
end
