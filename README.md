# Mogura

A mail filtering tool for IMAP.

## Installation

Check out this repo first and enter the directory.

```console
$ git clone https://github.com/yskuniv/mogura.git
$ cd mogura/
```

Install this gem and add to the application's Gemfile by executing:

    $ bundle install

## Usage

Write `rules.yml` as following.

```yaml
- destination: test
  rule:
    and:
      - subject: "^\\[TEST "
      - or:
        - sender: "test@example.com"
        - x-test: "X-TEST"
        - x-foo: "X-FOO"
- destination: Trash
  rule:
    subject: "hi, im trash-like email!!"
- destination: bar
  rule:
    from: "bar@bar.example.com"
```

Then, run the command as following. This will start monitor recent mails on "INBOX" and filter them.

```console
$ mogura start mail.example.com -u <user> --password-base64=<password-base64-encoded> -c rules.yml -b INBOX
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yskuniv/mogura.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
