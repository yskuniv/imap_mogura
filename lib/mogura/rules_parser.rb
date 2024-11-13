# frozen_string_literal: true

require "json"
require "yaml"

require_relative "rules_parser/errors"
require_relative "rules_parser/rule_set"

module Mogura
  module RulesParser
    class << self
      def parse(yaml)
        rules = YAML.safe_load(yaml)

        raise ParseError, "top level is required to be just only one array" unless rules.is_a?(Array)

        rules.map do |item|
          rule_set = RuleSet.new(item)

          @parsed_rule = []
          parse_rule(rule_set.raw_rule)
          rule_set.parsed_rule = @parsed_rule

          rule_set
        rescue ArgumentError
          raise ParseError,
                "keywords \"destination\" and \"rule\" are required but some keywords are not specified or unknown keywords are specified. specified keywords: #{item.keys.map do |k|
                  "\"#{k}\""
                end.join(", ")}"
        end
      end

      private

      def parse_rule(rule)
        unless rule.is_a?(Hash) && rule.keys.count == 1
          raise ParseError,
                "rule should be a hash having only one key, illegal rule: #{JSON.dump(rule)}"
        end

        k = rule.keys.first

        case k
        when /^[Aa]nd$/
          rule_list = rule[k]

          @parsed_rule << { cond_operator: :AND, operands: rule_list.length }
          parse_rule_list(rule_list)
        when /^[Oo]r$/
          rule_list = rule[k]

          @parsed_rule << { cond_operator: :OR, operands: rule_list.length }
          parse_rule_list(rule_list)
        when /^([Ff]rom|[Ss]ender|[Tt]o|[Cc]c|[Ss]ubject)$/
          @parsed_rule << { special_field: k, regexp: rule[k] }
        else
          @parsed_rule << { field_name: k, regexp: rule[k] }
        end
      end

      def parse_rule_list(rule_list)
        rule_list.each do |rule|
          parse_rule(rule)
        end
      end
    end
  end
end
