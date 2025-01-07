# frozen_string_literal: true

require_relative "../debug_util"

module ImapMogura
  class RuleElement
    def match?(mail)
      raise NotImplementedError
    end

    private

    def debug_out_before_trying_rule(msg)
      DebugUtil.debug "## checking if it matches the rule: #{msg}"
    end

    def debug_out_if_it_matches_rule(match_result)
      if match_result
        DebugUtil.debug "## it matches the rule"
      else
        DebugUtil.debug "## it doesn't match"
      end
    end
  end

  class LogicalOperator < RuleElement
    def initialize(operands)
      @operands = operands

      super()
    end

    def to_s
      "#<#{self.class} operands=#{@operands}>"
    end

    attr_reader :operands
  end

  class AndOperator < LogicalOperator
    def match?(mail)
      debug_out_before_trying_rule("All of the operands match the rule")
      debug_out_if_it_matches_rule(@operands.all? { |elm| elm.match?(mail) })
    end
  end

  class OrOperator < LogicalOperator
    def match?(mail)
      debug_out_before_trying_rule("Any of the operands matches the rule")
      debug_out_if_it_matches_rule(@operands.any? { |elm| elm.match?(mail) })
    end
  end

  class FieldMatcher < RuleElement
    def initialize(regexp)
      @regexp = Regexp.new(regexp)

      super()
    end

    attr_reader :regexp
  end

  class SpecialFieldMatcher < FieldMatcher; end

  class FromMatcher < SpecialFieldMatcher
    def match?(mail)
      debug_out_before_trying_rule("From #{mail.from.inspect} matches the regexp #{@regexp}")
      debug_out_if_it_matches_rule(
        case mail.from
        when Enumerable
          mail.from.any? { |address| address&.match?(@regexp) }
        else
          mail.from&.match?(@regexp)
        end
      )
    end
  end

  class SenderMatcher < SpecialFieldMatcher
    def match?(mail)
      debug_out_before_trying_rule("Sender #{mail.sender.inspect} matches the regexp #{@regexp}")
      debug_out_if_it_matches_rule(mail.sender&.match?(@regexp))
    end
  end

  class ToMatcher < SpecialFieldMatcher
    def match?(mail)
      debug_out_before_trying_rule("To #{mail.to.inspect} matches the regexp #{@regexp}")
      debug_out_if_it_matches_rule(
        case mail.to
        when Enumerable
          mail.to.any? { |address| address&.match?(@regexp) }
        else
          mail.to&.match?(@regexp)
        end
      )
    end
  end

  class CcMatcher < SpecialFieldMatcher
    def match?(mail)
      debug_out_before_trying_rule("Cc #{mail.cc.inspect} matches the regexp #{@regexp}")
      debug_out_if_it_matches_rule(
        case mail.cc
        when Enumerable
          mail.cc.any? { |address| address&.match?(@regexp) }
        else
          mail.cc&.match?(@regexp)
        end
      )
    end
  end

  class SubjectMatcher < SpecialFieldMatcher
    def match?(mail)
      debug_out_before_trying_rule("Subject \"#{mail.subject}\" matches the regexp #{@regexp}")
      debug_out_if_it_matches_rule(mail.subject&.match?(@regexp))
    end
  end

  class DateMatcher < SpecialFieldMatcher
    def match?(mail)
      # TODO: impl
      raise NotImplementedError
    end
  end

  class GeneralFieldMatcher < FieldMatcher
    def initialize(field_name, regexp)
      @field_name = field_name

      super(regexp)
    end

    def match?(mail)
      debug_out_before_trying_rule("header field \"#{@field_name}\" with value \"#{mail.headers[@field_name]&.value}\" matches the regexp #{@regexp}")
      debug_out_if_it_matches_rule(mail.headers[@field_name]&.value&.match?(@regexp))
    end
  end
end
