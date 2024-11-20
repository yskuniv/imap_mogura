# ImapMogura

A mail filtering tool for IMAP.

## Installation

To install this gem, just run as following. You can get the gem from [RubyGems.org](https://rubygems.org/).

```console
$ gem install imap_mogura
```

## Usage

Create `rules.yml` and write rules like following.

```yaml
rules:
  - destination: test
    rule:
      and:
        - subject: "^\\[TEST "
        - or:
          - sender: "test@example\\.com"
          - x-test: "X-TEST"

  - destination: bar
    rule:
      from: "no-reply@bar\\.example\\.com"

  - destination: Trash
    rule:
      subject: "i'm trash-like email!!"
```

Running `mogura start` command will start monitoring RECENT mails coming to "INBOX". If a mail with RECENT flag is coming to the mailbox, it will be filtered.

```console
$ mogura start <host> -u <user> --password-base64=<password-base64-encoded> -c rules.yml -b INBOX
```

You can specify a mailbox to be monitored by `-b` option.

If you want to just filter mails on the specific mailbox, use `mogura filter` command.

```console
$ mogura filter <host> -u <user> --password-base64=<password-base64-encoded> -c rules.yml -b <mailbox>
```

You can check your config by `mogura check-config` command. It returns just OK if no errors in the config.

```console
$ mogura check-config -c rules.yml
OK
$ 
```

About more features, see `--help`.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yskuniv/imap_mogura.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
