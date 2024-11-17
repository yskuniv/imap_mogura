# frozen_string_literal: true

require "mail"
require "net/imap"

module Mogura
  class IMAPHandler
    class Error < StandardError; end

    class MailFetchError < Error
      def initialize(mailbox, message_id, bad_response_error_message)
        @mailbox = mailbox
        @message_id = message_id
        @bad_response_error_message = bad_response_error_message

        super("failed to fetch mail: id = #{message_id} on \"#{mailbox}\", message = \"#{bad_response_error_message}\"")
      end

      attr_reader :mailbox, :message_id, :bad_response_error_message
    end

    def initialize(host, port = 143, starttls: true, usessl: false, certs: nil, verify: true,
                   auth_info: nil)
      @imap = Net::IMAP.new(host, port, usessl, certs, verify)

      if usessl || starttls
        @imap.starttls(certs, verify) if !usessl && starttls

        # in case with TLS, just authenticate with LOGIN command
        @imap.login(auth_info[:user], auth_info[:password])
      else
        # in plain text session, use AUTHENTICATE command
        @imap.authenticate(auth_info[:auth_type], auth_info[:user], auth_info[:password])
      end

      initialize_selected_mailbox
    end

    def close
      close_mailbox
      @imap.disconnect
    end

    def monitor_events(mailbox, events, &block)
      loop do
        resp = wait_event_with_idle(mailbox, events)

        break unless block

        block[resp]
      end
    end

    def wait_event_with_idle(mailbox, expected_response_names)
      select_mailbox(mailbox)

      @imap.idle do |resp|
        if expected_response_names.include? resp.name
          @imap.idle_done

          return resp
        end
      end
    end

    def all_mailbox_list
      @imap.list("", "*").map(&:name)
    end

    def find_and_handle_mails(mailbox, search_keys, &block)
      select_mailbox(mailbox)

      @imap.search(search_keys).each do |message_id|
        break unless block

        block[message_id]
      end
    end

    def handle_all_mails(mailbox, &block)
      select_mailbox(mailbox)

      @imap.search(["ALL"]).each do |message_id|
        break unless block

        block[message_id]
      end
    end

    def fetch_envelope(mailbox, message_id)
      with_mailbox_selected(mailbox) do
        @imap.fetch(message_id, "ENVELOPE")[0].attr["ENVELOPE"]
      rescue Net::IMAP::BadResponseError => e
        raise MailFetchError.new(mailbox, message_id, e.message)
      end
    end

    def fetch_header(mailbox, message_id)
      with_mailbox_selected(mailbox) do
        fetch_data = @imap.fetch(message_id, "BODY.PEEK[HEADER]")[0].attr["BODY[HEADER]"]

        Mail.read_from_string(fetch_data)
      rescue Net::IMAP::BadResponseError => e
        raise MailFetchError.new(mailbox, message_id, e.message)
      end
    end

    def touch_mailbox(mailbox)
      @imap.create(mailbox) if @imap.list("", mailbox).empty?
    end

    def move(src_mailbox, src_message_id, dst_mailbox)
      return if src_mailbox == dst_mailbox # skip moving if src_mailbox is the same with dst_mailbox

      with_mailbox_selected(src_mailbox, readonly: false) do
        @imap.copy([src_message_id], dst_mailbox)
        @imap.store(src_message_id, "+FLAGS", [:Deleted])
      end

      dst_mailbox
    end

    def close_operation_for_mailbox(_)
      close_mailbox
    end

    private

    def initialize_selected_mailbox
      @selected_mailbox = nil
    end

    def with_mailbox_selected(mailbox, readonly: true, &block)
      select_mailbox(mailbox, readonly: readonly)

      block[]
    end

    def select_mailbox(mailbox, readonly: true)
      return if @selected_mailbox == [mailbox, readonly]

      close_mailbox

      if readonly
        @imap.examine(mailbox)
      else
        @imap.select(mailbox)
      end

      @selected_mailbox = [mailbox, readonly]
    end

    def close_mailbox
      return unless @selected_mailbox

      @imap.close
      @selected_mailbox = nil
    end
  end
end
