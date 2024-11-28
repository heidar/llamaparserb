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

# Parse a file from a URL
markdown = client.parse_file('https://example.com/document.pdf')
```

### File Input Options

The `parse_file` method accepts three types of inputs:

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

3. URL (String):
```ruby
client.parse_file('https://example.com/document.pdf')
```

### Advanced Options

```ruby
client = Llamaparserb::Client.new(
  ENV['LLAMA_CLOUD_API_KEY'],
  {
    # Basic Configuration
    result_type: "markdown",    # Output format: "text" or "markdown"
    num_workers: 4,             # Number of workers for concurrent processing
    check_interval: 1,          # How often to check job status (seconds)
    max_timeout: 2000,          # Maximum time to wait for parsing (seconds)
    verbose: true,              # Enable detailed logging
    show_progress: true,        # Show progress during parsing
    ignore_errors: true,        # Return nil instead of raising errors
    
    # Language and Parsing Options
    language: :en,              # Target language for parsing
    parsing_instruction: "",    # Custom parsing instructions
    skip_diagonal_text: false,  # Skip diagonal text in documents
    invalidate_cache: false,    # Force reprocessing of cached documents
    do_not_cache: false,        # Disable caching of results
    
    # Processing Modes
    fast_mode: false,          # Enable faster processing (may reduce quality)
    premium_mode: false,       # Enable premium parsing features
    continuous_mode: false,    # Process document as continuous text
    do_not_unroll_columns: false, # Keep columnar text structure
    
    # Page Handling
    split_by_page: true,       # Split result by pages
    page_separator: "\n\n",    # Custom page separator
    page_prefix: "Page ",      # Text to prepend to each page
    page_suffix: "\n",         # Text to append to each page
    target_pages: [1,2,3],     # Array of specific pages to process
    bounding_box: {            # Specify area to parse (coordinates in pixels)
      x1: 0, y1: 0,           # Top-left corner
      x2: 612, y2: 792        # Bottom-right corner
    },
    
    # OCR and Image Processing
    disable_ocr: false,        # Disable Optical Character Recognition
    take_screenshot: false,    # Capture screenshot of document
    
    # Advanced Processing Features
    gpt4o_mode: false,         # Enable GPT-4 Optimization mode
    gpt4o_api_key: "key",      # API key for GPT-4 Optimization
    guess_xlsx_sheet_names: false, # Attempt to guess Excel sheet names
    is_formatting_instruction: false, # Use formatting instructions
    annotate_links: false,     # Include link annotations in output
    
    # Multimodal Processing
    vendor_multimodal_api_key: "key",      # API key for multimodal processing
    use_vendor_multimodal_model: false,     # Enable multimodal model
    vendor_multimodal_model_name: "model",  # Specify multimodal model
    
    # Integration Options
    webhook_url: "https://...", # URL for webhook notifications
    http_proxy: "http://...",   # HTTP proxy configuration
    
    # Azure OpenAI Configuration
    azure_openai_deployment_name: "deployment", # Azure OpenAI deployment name
    azure_openai_endpoint: "endpoint",         # Azure OpenAI endpoint
    azure_openai_api_version: "2023-05-15",    # Azure OpenAI API version
    azure_openai_key: "key"                    # Azure OpenAI API key
  }
)
```

### Feature-Specific Options

#### Page Processing
- `split_by_page`: Split the document into separate pages
- `page_separator`: Custom text to insert between pages
- `page_prefix`/`page_suffix`: Add custom text before/after each page
- `target_pages`: Process only specific pages
- `bounding_box`: Parse only a specific area of the document

#### OCR and Image Processing
- `disable_ocr`: Turn off Optical Character Recognition
- `take_screenshot`: Generate document screenshots
- `skip_diagonal_text`: Ignore text at diagonal angles

#### Advanced Processing
- `continuous_mode`: Process text as a continuous stream
- `do_not_unroll_columns`: Preserve column structure
- `guess_xlsx_sheet_names`: Auto-detect Excel sheet names
- `annotate_links`: Include document hyperlinks in output
- `is_formatting_instruction`: Use special formatting instructions

#### Performance Options
- `fast_mode`: Faster processing with potential quality trade-offs
- `premium_mode`: Access to premium features
- `invalidate_cache`/`do_not_cache`: Control result caching
- `num_workers`: Configure concurrent processing

#### Integration Features
- `webhook_url`: Receive processing notifications
- `http_proxy`: Configure proxy settings

#### Azure OpenAI Integration
Configure Azure OpenAI services with:
- `azure_openai_deployment_name`
- `azure_openai_endpoint`
- `azure_openai_api_version`
- `azure_openai_key`

#### Multimodal Processing
Enable advanced multimodal processing with:
- `vendor_multimodal_api_key`
- `use_vendor_multimodal_model`
- `vendor_multimodal_model_name`

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
