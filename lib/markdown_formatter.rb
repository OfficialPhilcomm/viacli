class MarkdownFormatter
  attr_reader :total_width
  attr_accessor :current_line_size

  def initialize(total_width = 60)
    @total_width = total_width
    @current_line_size = 0

    @bold = false
    @simple_code = false
    @multiline_code = false
  end

  def format(text)
    return unless text

    # listify(text)
    boldify(text)
    # codify(text)
    update_current_line_size(text)

    text
  end

  private

  def update_current_line_size(text)
    @current_line_size += text.size
    if text.end_with?("\n")
      @current_line_size = 0
      # puts "reset!"
    end
  end

  def listify(text)
    if @current_line_size == 0 && text.match(/\A\s*\d+\./)
      match = text.match(/\A\s*\d+\./)[0]

      text.sub!(match, "\e[33m\e[1m#{match}\e[0m")
    end
  end

  def boldify(text)
    while text.include? "**"
      if @bold
        text.sub!("**", "\e[0m")
      else
        text.sub!("**", "\e[32m\e[1m")
      end

      @bold = !@bold
    end
  end

  def codify(text)
    while text.include? "`"
      if text.include? "```"
        if @multiline_code
          puts "removing multicode"
          text.sub!("```", "\e[0m")
        else
          puts "adding multicode"
          text.sub!("```", "\e[33m\e[1m")
        end

        @multiline_code = !@multiline_code
      else
        if @simple_code
          text.sub!("`", "\e[0m")
        else
          text.sub!("`", "\e[33m\e[1m")
        end

        @simple_code = !@simple_code
      end
    end
  end
end
