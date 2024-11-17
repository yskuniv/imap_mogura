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
    class << self
      def exit_on_failure?
        true
      end
    end

    desc "start HOST", "connect to HOST and start watching"
    option :port, type: :numeric, default: 143, aliases: :p
    option :starttls, type: :boolean, default: true
    option :use_ssl, type: :boolean, default: false
    option :auth_type, type: :string, default: "LOGIN"
    option :user, type: :string, aliases: :u
    option :password_base64, type: :string
    option :config, type: :string, aliases: :c, required: true
    option :target_mailbox, type: :string, aliases: :b, required: true
    option :create_directory, type: :boolean, default: true
    option :dry_run, type: :boolean, default: false
    def start(host)
      port = options[:port]
      starttls = options[:starttls]
      use_ssl = options[:use_ssl]
      auth_type = options[:auth_type] if use_ssl
      user = options[:user]
      password = Base64.decode64(options[:password_base64])
      config_name = options[:config]
      target_mailbox = options[:target_mailbox]

      create_directory = options[:create_directory]
      dry_run = options[:dry_run]

      with_all_preparation_ready(config_name, host, port, starttls, use_ssl,
                                 auth_info: { auth_type: auth_type, user: user, password: password },
                                 create_directory: create_directory,
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
    option :exclude_mailboxes, type: :array, default: []
    option :target_mailbox, type: :string, aliases: :b
    option :create_directory, type: :boolean, default: true
    option :dry_run, type: :boolean, default: false
    def filter(host)
      port = options[:port]
      starttls = options[:starttls]
      use_ssl = options[:use_ssl]
      auth_type = options[:auth_type] if use_ssl
      user = options[:user]
      password = Base64.decode64(options[:password_base64])
      config_name = options[:config]
      all_mailbox = options[:all_mailbox]
      exclude_mailboxes = options[:exclude_mailboxes]
      target_mailbox = options[:target_mailbox] unless all_mailbox

      raise CustomOptionError, "--all-mailbox (-a) or --target-mailbox (-b) is required" if !all_mailbox && target_mailbox.nil?

      create_directory = options[:create_directory]
      dry_run = options[:dry_run]

      with_all_preparation_ready(config_name, host, port, starttls, use_ssl,
                                 auth_info: { auth_type: auth_type, user: user, password: password },
                                 excluded_mailboxes: exclude_mailboxes,
                                 create_directory: create_directory,
                                 dry_run: dry_run) do |imap_handler, rules, options|
        if all_mailbox
          excluded_mailboxes = options[:excluded_mailboxes]

          imap_handler.all_mailbox_list.reject { |mailbox| excluded_mailboxes.include?(mailbox) }.each do |mailbox|
            filter_all_mails(imap_handler, rules, mailbox, dry_run: dry_run)
          end
        else
          filter_all_mails(imap_handler, rules, target_mailbox, dry_run: dry_run)
        end
      end
    end

    desc "list HOST", "list mailboxes on HOST"
    option :port, type: :numeric, default: 143, aliases: :p
    option :starttls, type: :boolean, default: true
    option :use_ssl, type: :boolean, default: false
    option :auth_type, type: :string, default: "LOGIN"
    option :user, type: :string, aliases: :u
    option :password_base64, type: :string
    def list(host)
      port = options[:port]
      starttls = options[:starttls]
      use_ssl = options[:use_ssl]
      auth_type = options[:auth_type] if use_ssl
      user = options[:user]
      password = Base64.decode64(options[:password_base64])

      imap_handler = IMAPHandler.new(host, port,
                                     starttls: starttls, usessl: use_ssl, certs: nil, verify: true,
                                     auth_info: { auth_type: auth_type, user: user, password: password })

      puts imap_handler.all_mailbox_list

      imap_handler.close
    end

    private

    def with_all_preparation_ready(config_name,
                                   host, port,
                                   starttls, use_ssl, certs: nil, verify: true,
                                   auth_info: nil,
                                   excluded_mailboxes: [],
                                   create_directory: true,
                                   dry_run: false, &block)
      _, rules = load_and_handle_config(config_name)

      warn "* connecting the server #{host}:#{port}..."

      imap_handler = IMAPHandler.new(host, port,
                                     starttls: starttls, usessl: use_ssl, certs: certs, verify: verify,
                                     auth_info: auth_info)

      # FIXME: this doesn't work expectedly
      # trap("INT") do
      #   imap_handler.close
      #   exit
      # end

      touch_all_mailboxes_in_rules(imap_handler, rules, dry_run: dry_run) if create_directory

      options = { excluded_mailboxes: excluded_mailboxes }

      block[imap_handler, rules, options]

      imap_handler.close
    end

    def load_and_handle_config(config_name)
      metadata, raw_rules = ConfigParser.parse(config_name)

      rules = RulesParser.parse(raw_rules)

      [metadata, rules]
    rescue ConfigParser::ParseError => e
      raise Thor::Error, "Error: failed to parse config: #{e.message}"
    rescue RulesParser::ParseError => e
      raise Thor::Error, "Error: failed to parse rules: #{e.message}"
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

    def filter_all_mails(imap_handler, rules, mailbox, retry_count = 0, dry_run: false)
      imap_handler.handle_all_mails(mailbox) do |message_id|
        filter_mail(imap_handler, rules, mailbox, message_id, dry_run: dry_run)
      end
    rescue IMAPHandler::MailFetchError
      # if retry_count is over the threshold, terminate processing
      return unless retry_count < 3

      # wait a moment...
      sleep 10

      # retry filter all mails itself
      filter_all_mails(imap_handler, rules, mailbox, retry_count + 1, dry_run: dry_run)
    end

    def filter_mail(imap_handler, rules, mailbox, message_id, dry_run: false)
      mail = imap_handler.fetch_header(mailbox, message_id)

      warn "# filtering mail on \"#{mailbox}\" of subject \"#{mail.subject}\"..."

      rules.each do |rule_set|
        dst_mailbox = rule_set.destination
        rule = rule_set.rule

        next unless rule.match?(mail)

        warn "the mail matches for the rule of the destination \"#{dst_mailbox}\""
        warn "moving the mail..."

        if dry_run
          warn "moving skipped because this is dry run"
        else
          result = imap_handler.move(mailbox, message_id, dst_mailbox)
          if result
            warn "moving done"
          else
            warn "moving skipped because the destination is the same with the current mailbox \"#{mailbox}\""
          end
        end
      end

      imap_handler.close_operation_for_mailbox(mailbox)
    end
  end
end
