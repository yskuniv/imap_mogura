# frozen_string_literal: true

require "yaml"

require_relative "config_parser/errors"

module Mogura
  module ConfigParser
    class << self
      def parse(config_name)
        config = YAML.safe_load_file(config_name)

        raise ParseError, "config must be in hash format" unless config.is_a?(Hash)
        raise ParseError, "\"rules:\" must be defined" unless config.key?("rules")

        metadata = config["metadata"]
        rules = config["rules"]

        [metadata, rules]
      rescue YAML::SyntaxError => e
        raise ParseError, "failed to parse yaml: #{e.message}"
      end
    end
  end
end
