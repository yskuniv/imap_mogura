# frozen_string_literal: true

module ImapMogura
  RuleSet = Struct.new(:destination, :raw_rule, :parsed_rule) do
    HASH_KEYS = %w[destination rule].freeze # rubocop:disable Lint/ConstantDefinitionInBlock

    def initialize(hash)
      validate_hash(hash)

      super(*HASH_KEYS.map { |k| hash[k] }, nil)
    end

    alias_method :rule, :parsed_rule

    private

    def validate_hash(hash)
      HASH_KEYS.each do |k|
        hash.fetch(k)
      rescue KeyError => e
        raise ArgumentError, "given hash doesn't have required key: \"#{e.key}\""
      end

      return if hash.keys.sort == HASH_KEYS.sort

      raise ArgumentError,
            "given hash has unknown keys: #{(hash.keys - HASH_KEYS).map { |k| "\"#{k}\"" }.join(", ")}"
    end
  end
end
