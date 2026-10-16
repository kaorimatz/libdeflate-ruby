# libdeflate-ruby

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

The gem compiles the bundled libdeflate (see `ext/libdeflate/libdeflate/VERSION`)
with a C compiler only: no cmake, no download. To link a system libdeflate instead:

    $ gem install libdeflate -- --use-system-libraries

## Usage

```ruby
require 'libdeflate'

compressor = Libdeflate::Compressor.new
compressed_string = compressor.compress('Hello, World!')

decompressor = Libdeflate::Decompressor.new
decompressor.decompress(compressed_string)
```

`Compressor#compress` releases the GVL for strings of 16 KiB or more, so other
Ruby threads keep running while it compresses. A compressor can be shared by
threads, and they compress such strings in parallel.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kaorimatz/libdeflate.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

The gem bundles [libdeflate](https://github.com/ebiggers/libdeflate), which is licensed under the terms of the [MIT License](https://github.com/ebiggers/libdeflate/blob/master/COPYING).
