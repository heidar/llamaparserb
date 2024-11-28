# Llamaparserb

A Ruby client for the LlamaIndex Parsing API. This gem allows you to easily parse various document formats (PDF, DOCX, etc.) into text or markdown. Loosely based on the Python version.

## Installation

Add this line to your application's Gemfile:

```bash
gem 'llamaparserb'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install llamaparserb
```

## Usage

### Basic Usage

```ruby
require 'llamaparserb'

# Initialize client with API key
client = Llamaparserb::Client.new(ENV['LLAMA_CLOUD_API_KEY'])

# Parse a file from disk (to text by default)
text = client.parse_file('path/to/document.pdf')

# Parse an in-memory file (requires file type)
require 'open-uri'
file_content = URI.open('https://example.com/document.pdf')
text = client.parse_file(file_content, 'pdf')

# Parse a file to markdown
client = Llamaparserb::Client.new(ENV['LLAMA_CLOUD_API_KEY'], result_type: "markdown")
markdown = client.parse_file('path/to/document.pdf')
```

### File Input Options

The `parse_file` method accepts two types of inputs:

1. File path (String):
```ruby
client.parse_file('path/to/document.pdf')
```

2. IO object (requires file type parameter):
```ruby
# From a URL
file_content = URI.open('https://example.com/document.pdf')
client.parse_file(file_content, 'pdf')

# From memory
io = StringIO.new(file_content)
client.parse_file(io, 'pdf')

# From a Tempfile
temp_file = Tempfile.new(['document', '.pdf'])
client.parse_file(temp_file, 'pdf')
```

### Advanced Options

```ruby
client = Llamaparserb::Client.new(
  ENV['LLAMA_CLOUD_API_KEY'],
  {
    result_type: "markdown",  # Output format: "text" or "markdown"
    num_workers: 4,           # Number of workers for concurrent processing
    check_interval: 1,        # How often to check job status (seconds)
    max_timeout: 2000,        # Maximum time to wait for parsing (seconds)
    verbose: true,            # Enable detailed logging
    language: :en,            # Target language
    parsing_instruction: "",  # Custom parsing instructions
    premium_mode: false,      # Enable premium parsing features
    split_by_page: true       # Split result by pages
  }
)
```

### Supported File Types

The client supports a wide range of file formats including:
- Documents: PDF, DOCX, DOC, RTF, TXT
- Presentations: PPT, PPTX
- Spreadsheets: XLS, XLSX, CSV
- Images: JPG, PNG, TIFF
- And many more

See `SUPPORTED_FILE_TYPES` constant for the complete list.

## Error Handling

By default, the client will return `nil` and print an error message if something goes wrong. You can change this behavior with the `ignore_errors` option:

```ruby
# Raise errors instead of returning nil
client = Llamaparserb::Client.new(api_key, ignore_errors: false)
```

## Logging

By default, the client uses Ruby's standard Logger with output to STDOUT. You can configure logging in several ways:

```ruby
# Use default logger with debug level output
client = Llamaparserb::Client.new(api_key, verbose: true)

# Use default logger with info level (less output)
client = Llamaparserb::Client.new(api_key, verbose: false)

# Use custom logger
custom_logger = Logger.new('llamaparse.log')
custom_logger.level = Logger::INFO
client = Llamaparserb::Client.new(api_key, logger: custom_logger)

# Use Rails logger in a Rails app
client = Llamaparserb::Client.new(api_key, logger: Rails.logger)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/horizing/llamaparserb.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
