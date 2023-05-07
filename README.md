# libdeflate-ruby

[![Gem](https://img.shields.io/gem/v/libdeflate.svg?style=flat-square)](https://rubygems.org/gems/libdeflate)
[![Coveralls](https://img.shields.io/coveralls/kaorimatz/libdeflate-ruby.svg?style=flat-square)](https://coveralls.io/github/kaorimatz/libdeflate-ruby)
[![Gemnasium](https://img.shields.io/gemnasium/kaorimatz/libdeflate-ruby.svg?style=flat-square)](https://gemnasium.com/kaorimatz/libdeflate-ruby)

Ruby bindings for [libdeflate](https://github.com/ebiggers/libdeflate).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'libdeflate'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install libdeflate

## Usage

```ruby
require 'libdeflate'

compressor = Libdeflate::Compressor.new
compressed_string = compressor.compress('Hello, World!')

decompressor = Libdeflate::Decompressor.new
decompressor.decompress(compressed_string)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kaorimatz/libdeflate.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

The gem bundles [libdeflate](https://github.com/ebiggers/libdeflate), which is licensed under the terms of the [MIT License](https://github.com/ebiggers/libdeflate/blob/master/COPYING).
