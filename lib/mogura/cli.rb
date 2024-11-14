# frozen_string_literal: true

require "thor"
require "base64"

module Mogura
  class CustomOptionError < Thor::Error
    def initialize(msg = "Custom option error message")
      super
    end
  end

  class CLI < Thor
    desc "start HOST", "connect to HOST and start watching"
    option :port, type: :numeric, default: 143, aliases: :p
    option :starttls, type: :boolean, default: true
    option :use_ssl, type: :boolean, default: false
    option :auth_type, type: :string, default: "LOGIN"
    option :user, type: :string, aliases: :u
    option :password_base64, type: :string
    option :config, type: :string, aliases: :c, required: true
    option :target_mailbox, type: :string, aliases: :b, required: true
    option :dry_run, type: :boolean, default: false
    def start(host)
      port = options[:port]
      starttls = options[:starttls]
      use_ssl = options[:use_ssl]
      auth_type = options[:auth_type] if use_ssl
      user = options[:user]
      password = Base64.decode64(options[:password_base64])
      config = options[:config]
      target_mailbox = options[:target_mailbox]

      @dry_run = options[:dry_run]

      warn "* parsing rules..."

      rules = RulesParser.parse(File.read(config))

      warn "* connecting the server..."

      @imap_handler = IMAPHandler.new(host, port, starttls: starttls, usessl: use_ssl, certs: nil, verify: true,
                                                  auth_info: { auth_type: auth_type, user: user, password: password })

      trap("INT") do
        @imap_handler.close
        exit
      end

      touch_all_mailboxes_in_rules(rules)

      warn "* start monitoring recent mails in \"#{target_mailbox}\""

      @imap_handler.monitor_recents(target_mailbox) do |message_id|
        warn "mail (id = #{message_id} on \"#{target_mailbox}\") is recent"

        filter_mail(target_mailbox, message_id, rules)
      end
    end

    desc "filter HOST", "filter mails on HOST"
    option :port, type: :numeric, default: 143, aliases: :p
    option :starttls, type: :boolean, default: true
    option :use_ssl, type: :boolean, default: false
    option :auth_type, type: :string, default: "LOGIN"
    option :user, type: :string, aliases: :u
    option :password_base64, type: :string
    option :config, type: :string, aliases: :c, required: true
    option :all_mailbox, type: :boolean, default: false, aliases: :a
    option :target_mailbox, type: :string, aliases: :b
    option :dry_run, type: :boolean, default: false
    def filter(host)
      port = options[:port]
      starttls = options[:starttls]
      use_ssl = options[:use_ssl]
      auth_type = options[:auth_type] if use_ssl
      user = options[:user]
      password = Base64.decode64(options[:password_base64])
      config = options[:config]
      all_mailbox = options[:all_mailbox]
      target_mailbox = options[:target_mailbox] unless all_mailbox

      raise CustomOptionError, "--all-mailbox (-a) or --target-mailbox (-b) is required" if !all_mailbox && target_mailbox.nil?

      @dry_run = options[:dry_run]

      warn "* parsing rules..."

      rules = RulesParser.parse(File.read(config))

      warn "* connecting the server..."

      @imap_handler = IMAPHandler.new(host, port, starttls: starttls, usessl: use_ssl, certs: nil, verify: true,
                                                  auth_info: { auth_type: auth_type, user: user, password: password })

      trap("INT") do
        @imap_handler.close
        exit
      end

      touch_all_mailboxes_in_rules(rules)

      if all_mailbox
        @imap_handler.all_mailbox_list.each do |mailbox|
          @imap_handler.handle_all_mails(mailbox) do |message_id|
            filter_mail(mailbox, message_id, rules)
          end
        end
      else
        @imap_handler.handle_all_mails(target_mailbox) do |message_id|
          filter_mail(target_mailbox, message_id, rules)
        end
      end

      @imap_handler.close
    end

    private

    def touch_all_mailboxes_in_rules(rules)
      return if @dry_run

      rules.each do |rule_set|
        dst_mailbox = rule_set.destination
        @imap_handler.touch_mailbox(dst_mailbox)
      end
    end

    def filter_mail(mailbox, message_id, rules)
      warn "filtering mail (id = #{message_id} on \"#{mailbox}\")..."

      mail = @imap_handler.fetch_header(mailbox, message_id)

      warn "start checking mail (id = #{message_id} on \"#{mailbox}\" with subject \"#{mail.subject}\") matches the rule..."

      rules.each do |rule_set|
        dst_mailbox = rule_set.destination
        rule = rule_set.rule

        next unless rule.match?(mail)

        warn "the mail matches for the destination \"#{dst_mailbox}\""
        warn "moving the mail..."

        if @dry_run
          warn "moving skipped because of dry run"
        else
          result = @imap_handler.move(mailbox, message_id, dst_mailbox, create_mailbox: true)

          if result.nil?
            warn "moving skipped because src and dst is the same mailbox"
          else
            warn "moving done"
          end
        end
      end

      @imap_handler.close_operation_for_mailbox(mailbox)
    end
  end
end
