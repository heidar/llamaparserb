# frozen_string_literal: true

require_relative "llamaparserb/version"
require "faraday"
require "faraday/multipart"
require "json"
require "mime/types"
require "uri"
require "async"
require "logger"
require "tempfile"

module Llamaparserb
  class Error < StandardError; end

  class Client
    DEFAULT_BASE_URL = "https://api.cloud.llamaindex.ai/api/parsing"
    DEFAULT_SEPARATOR = "\n---\n"
    VALID_STATUSES = ["SUCCESS", "COMPLETED"].freeze
    SUPPORTED_FILE_TYPES = [
      ".pdf", ".602", ".abw", ".cgm", ".cwk", ".doc", ".docx", ".docm", ".dot",
      ".dotm", ".hwp", ".key", ".lwp", ".mw", ".mcw", ".pages", ".pbd", ".ppt",
      ".pptm", ".pptx", ".pot", ".potm", ".potx", ".rtf", ".sda", ".sdd", ".sdp",
      ".sdw", ".sgl", ".sti", ".sxi", ".sxw", ".stw", ".sxg", ".txt", ".uof",
      ".uop", ".uot", ".vor", ".wpd", ".wps", ".xml", ".zabw", ".epub", ".jpg",
      ".jpeg", ".png", ".gif", ".bmp", ".svg", ".tiff", ".webp", ".htm", ".html",
      ".xlsx", ".xls", ".xlsm", ".xlsb", ".xlw", ".csv", ".dif", ".sylk", ".slk",
      ".prn", ".numbers", ".et", ".ods", ".fods", ".uos1", ".uos2", ".dbf",
      ".wk1", ".wk2", ".wk3", ".wk4", ".wks", ".123", ".wq1", ".wq2", ".wb1",
      ".wb2", ".wb3", ".qpw", ".xlr", ".eth", ".tsv"
    ].freeze

    attr_reader :api_key, :base_url, :options, :logger

    def initialize(api_key = nil, options = {})
      @api_key = api_key || ENV["LLAMA_CLOUD_API_KEY"]
      raise Error, "API key is required" unless @api_key

      @base_url = options[:base_url] || ENV["LLAMA_CLOUD_BASE_URL"] || DEFAULT_BASE_URL
      @options = default_options.merge(options)
      @logger = options[:logger] || default_logger
      @connection = build_connection
    end

    def parse_file(file_input, file_type = nil)
      case file_input
      when String
        if file_type
          job_id = create_job_from_io(file_input, file_type)
          log "Started parsing binary data under job_id #{job_id}", :info
        elsif File.exist?(file_input)
          job_id = create_job_from_path(file_input)
          log "Started parsing file under job_id #{job_id}", :info
        elsif URI::DEFAULT_PARSER.make_regexp.match?(file_input)
          job_id = create_job_from_url(file_input)
          log "Started parsing URL under job_id #{job_id}", :info
        else
          raise Error, "file_type parameter is required for binary string input"
        end
      when IO, StringIO, Tempfile
        raise Error, "file_type parameter is required for IO objects" unless file_type
        job_id = create_job_from_io(file_input, file_type)
        log "Started parsing in-memory file under job_id #{job_id}", :info
      else
        raise Error, "Invalid input type. Expected String (file path) or IO object, got #{file_input.class}"
      end

      wait_for_completion(job_id)
      result = get_result(job_id)
      log "Successfully retrieved result", :info
      result
    rescue => e
      handle_error(e, file_input)
      raise unless @options[:ignore_errors]
      nil
    end

    private

    def default_options
      {
        result_type: :text,
        num_workers: 4,
        check_interval: 1,
        max_timeout: 2000,
        verbose: true,
        show_progress: true,
        language: :en,
        parsing_instruction: "",
        skip_diagonal_text: false,
        invalidate_cache: false,
        do_not_cache: false,
        fast_mode: false,
        premium_mode: false,
        continuous_mode: false,
        do_not_unroll_columns: false,
        page_separator: nil,
        page_prefix: nil,
        page_suffix: nil,
        gpt4o_mode: false,
        gpt4o_api_key: nil,
        guess_xlsx_sheet_names: false,
        bounding_box: nil,
        target_pages: nil,
        ignore_errors: true,
        split_by_page: true,
        vendor_multimodal_api_key: nil,
        use_vendor_multimodal_model: false,
        vendor_multimodal_model_name: nil,
        take_screenshot: false,
        disable_ocr: false,
        is_formatting_instruction: false,
        annotate_links: false,
        webhook_url: nil,
        azure_openai_deployment_name: nil,
        azure_openai_endpoint: nil,
        azure_openai_api_version: nil,
        azure_openai_key: nil,
        http_proxy: nil
      }
    end

    def default_logger
      logger = Logger.new($stdout)
      logger.level = @options[:verbose] ? Logger::DEBUG : Logger::INFO
      logger.formatter = proc do |severity, datetime, progname, msg|
        "#{msg}\n"
      end
      logger
    end

    def log(message, level = :debug)
      return unless @options[:verbose]

      # Convert message to string and force UTF-8 encoding, replacing invalid characters
      safe_message = message.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")

      case level
      when :info
        logger.info(safe_message)
      when :warn
        logger.warn(safe_message)
      when :error
        logger.error(safe_message)
      else
        logger.debug(safe_message)
      end
    end

    def wait_for_completion(job_id)
      start_time = Time.now

      loop do
        sleep(@options[:check_interval])
        response = get_job_status(job_id)
        log "Status: #{response["status"]}", :debug

        check_timeout(start_time, job_id)
        break if job_completed?(response)
        handle_error_status(response, job_id)
      end
    end

    def job_completed?(response)
      VALID_STATUSES.include?(response["status"])
    end

    def check_timeout(start_time, job_id)
      return unless Time.now - start_time > @options[:max_timeout]
      raise Error, "Job #{job_id} timed out after #{@options[:max_timeout]} seconds"
    end

    def handle_error_status(response, job_id)
      if response["status"] == "ERROR"
        error_code = response["error_code"] || "No error code found"
        error_message = response["error_message"] || "No error message found"
        raise Error, "Job failed: #{error_code} - #{error_message}"
      end

      unless response["status"] == "PENDING"
        raise Error, "Unexpected status: #{response["status"]}"
      end
    end

    def handle_error(error, file_input)
      if @options[:ignore_errors]
        safe_message = if file_input.is_a?(String) && file_input.start_with?("/")
          "file path: #{file_input}"
        else
          "binary data"
        end

        log "Error while parsing file (#{safe_message}): #{error.message}", :error
        nil
      else
        raise error
      end
    end

    def build_connection
      Faraday.new(url: base_url) do |f|
        f.request :multipart
        f.request :url_encoded
        f.response :json
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end
    end

    def create_job_from_path(file_path)
      validate_file_type!(file_path)
      file = Faraday::Multipart::FilePart.new(
        file_path,
        detect_content_type(file_path)
      )
      create_job(file)
    end

    def create_job_from_io(io_or_string, file_type)
      file_type = ".#{file_type}" unless file_type.start_with?(".")
      validate_file_type!(file_type)

      temp_file = Tempfile.new(["upload", file_type])
      temp_file.binmode

      case io_or_string
      when String
        temp_file.write(io_or_string.force_encoding("ASCII-8BIT"))
      else
        io_or_string.rewind if io_or_string.respond_to?(:rewind)
        temp_file.write(io_or_string.read.force_encoding("ASCII-8BIT"))
      end

      temp_file.rewind

      file = Faraday::Multipart::FilePart.new(
        temp_file,
        detect_content_type(temp_file.path)
      )

      response = @connection.post("upload") do |req|
        req.headers["Authorization"] = "Bearer #{api_key}"
        req.body = upload_params(file)
      end

      response.body["id"]
    ensure
      temp_file&.close
      temp_file&.unlink
    end

    def create_job(file)
      response = @connection.post("upload") do |req|
        req.headers["Authorization"] = "Bearer #{api_key}"
        req.body = upload_params(file)
      end

      response.body["id"]
    end

    def upload_params(file = nil, url = nil)
      params = {
        language: @options[:language].to_s,
        parsing_instruction: @options[:parsing_instruction],
        invalidate_cache: @options[:invalidate_cache],
        skip_diagonal_text: @options[:skip_diagonal_text],
        do_not_cache: @options[:do_not_cache],
        fast_mode: @options[:fast_mode],
        premium_mode: @options[:premium_mode],
        continuous_mode: @options[:continuous_mode],
        do_not_unroll_columns: @options[:do_not_unroll_columns],
        page_separator: @options[:page_separator],
        page_prefix: @options[:page_prefix],
        page_suffix: @options[:page_suffix],
        target_pages: @options[:target_pages],
        bounding_box: @options[:bounding_box],
        disable_ocr: @options[:disable_ocr],
        take_screenshot: @options[:take_screenshot],
        gpt4o_mode: @options[:gpt4o_mode],
        gpt4o_api_key: @options[:gpt4o_api_key],
        guess_xlsx_sheet_names: @options[:guess_xlsx_sheet_names],
        is_formatting_instruction: @options[:is_formatting_instruction],
        annotate_links: @options[:annotate_links],
        vendor_multimodal_api_key: @options[:vendor_multimodal_api_key],
        use_vendor_multimodal_model: @options[:use_vendor_multimodal_model],
        vendor_multimodal_model_name: @options[:vendor_multimodal_model_name],
        webhook_url: @options[:webhook_url],
        http_proxy: @options[:http_proxy],
        azure_openai_deployment_name: @options[:azure_openai_deployment_name],
        azure_openai_endpoint: @options[:azure_openai_endpoint],
        azure_openai_api_version: @options[:azure_openai_api_version],
        azure_openai_key: @options[:azure_openai_key],
        from_ruby_package: true
      }

      if url
        params[:input_url] = url.to_s
      elsif file
        params[:file] = file
      end

      params.compact
    end

    def get_job_status(job_id)
      response = @connection.get("job/#{job_id}") do |req|
        req.headers["Authorization"] = "Bearer #{api_key}"
      end

      response.body
    end

    def get_result(job_id)
      result_type = @options[:result_type].to_s
      response = @connection.get("job/#{job_id}/result/#{result_type}") do |req|
        req.headers["Authorization"] = "Bearer #{api_key}"
      end

      log "Result type: #{result_type}", :info
      log "Raw response body: #{response.body.inspect}", :info

      extract_content(response.body, result_type)
    end

    def extract_content(body, result_type)
      content = if body.is_a?(Hash)
        body[result_type] || body["content"]
      else
        body
      end

      log "Warning: No content found in response", :warn if content.nil?
      content
    end

    def detect_content_type(filename)
      MIME::Types.type_for(filename).first&.content_type || "application/octet-stream"
    end

    def validate_file_type!(file_path)
      extension = if file_path.start_with?(".")
        file_path
      else
        File.extname(file_path).downcase
      end

      unless SUPPORTED_FILE_TYPES.include?(extension)
        raise Error, "Unsupported file type: #{extension}. Supported types: #{SUPPORTED_FILE_TYPES.join(", ")}"
      end
    end

    def create_job_from_url(url)
      log "Creating job from URL: #{url}", :debug

      response = @connection.post("upload") do |req|
        req.headers["Authorization"] = "Bearer #{api_key}"
        req.headers["Accept"] = "application/json"
        req.options.timeout = 30
        req.body = upload_params(nil, url)
      end

      log "Response: #{response.body.inspect}", :debug
      response.body["id"]
    end
  end
end
