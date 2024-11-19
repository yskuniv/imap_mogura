# frozen_string_literal: true

module ImapMogura
  class RuleElement
    def match?(mail)
      raise NotImplementedError
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
      @operands.all? { |elm| elm.match?(mail) }
    end
  end

  class OrOperator < LogicalOperator
    def match?(mail)
      @operands.any? { |elm| elm.match?(mail) }
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
      case mail.from
      when Enumerable
        mail.from.any? { |address| address&.match?(@regexp) }
      else
        mail.from&.match?(@regexp)
      end
    end
  end

  class SenderMatcher < SpecialFieldMatcher
    def match?(mail)
      mail.sender&.match?(@regexp)
    end
  end

  class ToMatcher < SpecialFieldMatcher
    def match?(mail)
      case mail.to
      when Enumerable
        mail.to.any? { |address| address&.match?(@regexp) }
      else
        mail.to&.match?(@regexp)
      end
    end
  end

  class CcMatcher < SpecialFieldMatcher
    def match?(mail)
      case mail.cc
      when Enumerable
        mail.cc.any? { |address| address&.match?(@regexp) }
      else
        mail.cc&.match?(@regexp)
      end
    end
  end

  class SubjectMatcher < SpecialFieldMatcher
    def match?(mail)
      mail.subject&.match?(@regexp)
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
      mail.headers[@field_name]&.value&.match?(@regexp)
    end
  end
end
