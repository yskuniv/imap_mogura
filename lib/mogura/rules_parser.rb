# frozen_string_literal: true

require "English"
require "json"

require_relative "rules_parser/errors"
require_relative "rules_parser/rule_set"
require_relative "rules_parser/rule_elements"

module Mogura
  module RulesParser
    class << self
      def parse(rules)
        raise ParseError, "rules is required to be just only one array" unless rules.is_a?(Array)

        rules.map do |item|
          rule_set = RuleSet.new(item)

          rule_set.parsed_rule = parse_rule(rule_set.raw_rule)

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

          AndOperator.new(parse_rule_list(rule_list))
        when /^[Oo]r$/
          rule_list = rule[k]

          OrOperator.new(parse_rule_list(rule_list))
        when /^(?<special_field_name>[Ff]rom|[Ss]ender|[Tt]o|[Cc]c|[Ss]ubject|[Dd]ate)$/
          case $LAST_MATCH_INFO[:special_field_name]
          when /^[Ff]rom$/
            FromMatcher
          when /^[Ss]ender$/
            SenderMatcher
          when /^[Tt]o$/
            ToMatcher
          when /^[Cc]c$/
            CcMatcher
          when /^[Ss]ubject$/
            SubjectMatcher
          when /^[Dd]ate$/
            DateMatcher
          end.new(rule[k])
        else
          GeneralFieldMatcher.new(k, rule[k])
        end
      end

      def parse_rule_list(rule_list)
        rule_list.map { |rule| parse_rule(rule) }
      end
    end
  end
end
