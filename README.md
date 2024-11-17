# Mogura

A mail filtering tool for IMAP.

## Installation

Check out this repository first and enter the directory.

```console
$ git clone https://github.com/yskuniv/mogura.git
$ cd mogura/
```

Install this gem and add to the application's Gemfile by executing:

    $ bundle install

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

As following `start` command, which will start monitoring RECENT mails on "INBOX". If a mail is coming (and it's RECENT), it will be filtered.

```console
$ mogura start mail.example.com -u <user> --password-base64=<password-base64-encoded> -c rules.yml -b INBOX
```

You can specify a mailbox to which be monitored by `-b` option.

If you want to just filter mails on a specific mailbox, run the `filter` command as following.

```console
$ mogura filter mail.example.com -u <user> --password-base64=<password-base64-encoded> -c rules.yml -b <mailbox>
```

You can check your config by `check-config` command. It returns just OK if no problems in the specified config.

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

Bug reports and pull requests are welcome on GitHub at https://github.com/yskuniv/mogura.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
