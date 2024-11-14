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

      dry_run = options[:dry_run]

      with_all_preparation_ready(config, host, port, starttls, use_ssl,
                                 auth_info: { auth_type: auth_type, user: user, password: password },
                                 dry_run: dry_run) do |imap_handler, rules|
        warn "* start monitoring recent mails in \"#{target_mailbox}\""

        imap_handler.monitor_recents(target_mailbox) do |message_id|
          warn "mail (id = #{message_id} on \"#{target_mailbox}\") is recent"

          filter_mail(imap_handler, rules, target_mailbox, message_id, dry_run: dry_run)
        end
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

      dry_run = options[:dry_run]

      with_all_preparation_ready(config, host, port, starttls, use_ssl,
                                 auth_info: { auth_type: auth_type, user: user, password: password },
                                 dry_run: dry_run) do |imap_handler, rules|
        if all_mailbox
          imap_handler.all_mailbox_list.each do |mailbox|
            filter_all_mails(imap_handler, rules, mailbox, dry_run: dry_run)
          end
        else
          filter_all_mails(imap_handler, rules, target_mailbox, dry_run: dry_run)
        end
      end
    end

    private

    def with_all_preparation_ready(config, host, port, starttls, use_ssl, certs: nil, verify: true, auth_info: nil, dry_run: false, &block)
      rules = RulesParser.parse(File.read(config))

      warn "* connecting the server \"#{host}:#{port}\"..."

      imap_handler = IMAPHandler.new(host, port,
                                     starttls: starttls, usessl: use_ssl, certs: certs, verify: verify,
                                     auth_info: auth_info)

      trap("INT") do
        imap_handler.close
        exit
      end

      touch_all_mailboxes_in_rules(imap_handler, rules, dry_run: dry_run)

      block[imap_handler, rules]

      imap_handler.close
    end

    def touch_all_mailboxes_in_rules(imap_handler, rules, dry_run: false)
      rules.each do |rule_set|
        dst_mailbox = rule_set.destination

        if dry_run
          warn "creation or existence check of mailbox \"#{dst_mailbox}\" is skipped because this is dry run"
        else
          result = imap_handler.touch_mailbox(dst_mailbox)
          warn "mailbox \"#{dst_mailbox}\" is created" if result
        end
      end
    end

    def filter_all_mails(imap_handler, rules, mailbox, dry_run: false)
      imap_handler.handle_all_mails(mailbox) do |message_id|
        filter_mail(imap_handler, rules, mailbox, message_id, dry_run: dry_run)
      end
    end

    def filter_mail(imap_handler, rules, mailbox, message_id, dry_run: false)
      mail = imap_handler.fetch_header(mailbox, message_id)

      rules.each do |rule_set|
        dst_mailbox = rule_set.destination
        rule = rule_set.rule

        next unless rule.match?(mail)

        warn "the mail of subject \"#{mail.subject}\" matches for the rule of the destination \"#{dst_mailbox}\""
        warn "moving the mail..."

        if dry_run
          warn "moving skipped because this is dry run"
        else
          result = imap_handler.move(mailbox, message_id, dst_mailbox, create_mailbox: true)
          warn "moving done" if result
        end
      end

      imap_handler.close_operation_for_mailbox(mailbox)
    end
  end
end
