require 'stringio'

module Clamp

  module Help
    
    LEFT_COLUMN_WIDTH = 20

    def usage(usage)
      @declared_usage_descriptions ||= []
      @declared_usage_descriptions << usage
    end

    attr_reader :declared_usage_descriptions

    def description=(description)
      @description = description.dup
      if @description =~ /^\A\n*( +)/
        indent = $1
        @description.gsub!(/^#{indent}/, '')
      end
      @description.strip!
    end
    
    attr_reader :description
    
    def derived_usage_description
      parts = parameters.map { |a| a.name }
      parts.unshift("[OPTIONS]") if has_options?
      parts.join(" ")
    end

    def usage_descriptions
      declared_usage_descriptions || [derived_usage_description]
    end

    def help(invocation_path)
      help = StringIO.new
      usage_descriptions.each_with_index do |usage, i|
        help.print i == 0 ? "Usage: " : "       "
        help.puts "#{invocation_path} #{usage}".rstrip
      end
      if description
        help.puts ""
        help.puts description
      end
      detail_format = "  %-#{LEFT_COLUMN_WIDTH}s %s"
      if has_parameters?
        help.puts "\nParameters:"
        parameters.each do |parameter|
          help.puts detail_format % parameter.help
        end
      end
      if has_subcommands?
        help.puts "\nSubcommands:"
        recognised_subcommands.each do |subcommand|
          help.puts detail_format % subcommand.help
        end
      end
      if has_options?
        help.puts "\nOptions:"
        recognised_options.each do |option|
          help.puts detail_format % option.help
        end
      end
      help.string
    end

  end

end
