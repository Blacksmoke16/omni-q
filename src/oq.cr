require "json"
require "xml"
require "yaml"

require "./converters/*"

# A performant, and portable jq wrapper thats facilitates the consumption and output of formats other than JSON; using jq filters to transform the data.
module OQ
  VERSION = "1.1.2"

  # The support formats that can be converted to/from.
  enum Format
    Json
    Yaml
    Xml

    # Returns the list of supported formats.
    def self.to_s(io : IO) : Nil
      self.names.join(io, ", ") { |str, join_io| str.downcase join_io }
    end

    # Maps a given format to its converter.
    def converter
      {% begin %}
        case self
          {% for format in @type.constants %}
            in .{{format.downcase.id}}? then OQ::Converters::{{format.id}}
          {% end %}
        end
      {% end %}
    end
  end

  class Processor
    # The format that the input data is in.
    setter input_format : Format = Format::Json

    # The format that the output should be transcoded into.
    setter output_format : Format = Format::Json

    # The args passed to the program.
    #
    # Non `oq` args are passed to `jq`.
    getter args : Array(String) = [] of String

    # The root of the XML document when transcoding to XML.
    setter xml_root : String = "root"

    # If the XML prolog should be emitted.
    setter xml_prolog : Bool = true

    # The name for XML array elements without keys.
    setter xml_item : String = "item"

    # The number of spaces to use for indentation.
    setter indent : Int32 = 2

    # If a tab for each indentation level instead of two spaces.
    setter tab : Bool = false

    # Keep a reference to the created temp files in order to delete them later.
    @tmp_files = Set(File).new

    # Consume the input, convert the input to JSON if needed, pass the input/args to `jq`, then convert the output if needed.
    def process(input_args : Array(String) = ARGV, input : IO = ARGF, output : IO = STDOUT, error : IO = STDERR) : Nil
      # Register an at_exit handler to cleanup temp files.
      at_exit { @tmp_files.each &.delete }

      # Parse out --rawfile, --argfile, --slurpfile, and -f/--from-file before processing additional args
      # since these options use a file that should not be used as input.
      self.consume_file_args input_args, "--rawfile", "--argfile", "--slurpfile"
      self.consume_file_args input_args, "-f", "--from-file", count: 1

      # Extract `jq` arguments from `ARGV`.
      self.extract_args input_args, output

      input_read, input_write = IO.pipe
      output_read, output_write = IO.pipe

      channel = Channel(Bool | Exception).new

      # If the input format is not JSON and there is more than 1 file in ARGV,
      # convert each file to JSON from the `#input_format` and save it to a temp file.
      # Then replace ARGV with the temp files.
      if !@input_format.json? && ARGV.size > 1
        ARGV.replace(ARGV.map do |file_name|
          File.tempfile ".#{File.basename file_name}" do |tmp_file|
            File.open file_name do |file|
              @input_format.converter.deserialize file, tmp_file
            end
          end
            .tap { |tf| @tmp_files << tf }
            .path
        end)

        # Conversion has already been completed by this point, so reset input format back to JSON.
        @input_format = :json
      end

      spawn do
        @input_format.converter.deserialize(input, input_write)
        input_write.close
        channel.send true
      rescue ex
        input_write.close
        channel.send ex
      end

      spawn do
        output_write.close
        @output_format.converter.serialize(
          output_read,
          output,
          indent: ((@tab ? "\t" : " ")*@indent),
          xml_root: @xml_root,
          xml_prolog: @xml_prolog,
          xml_item: @xml_item
        )
        channel.send true
      rescue ex
        channel.send ex
      end

      run = Process.run(
        "jq",
        args,
        input: input_read,
        output: output_write,
        error: error
      )

      unless run.success?
        raise RuntimeError.new
      end

      2.times do
        case (v = channel.receive)
        when Exception then raise v
        end
      end
    end

    # Parses the *input_args*, extracting `jq` arguments while leaving files
    private def extract_args(input_args : Array(String), output : IO) : Nil
      # Add color option if *output* is a tty
      # and the output format is JSON
      # (Since it will go straight to *output* and not converted)
      input_args.unshift "-C" if output.tty? && @output_format.json? && !input_args.includes? "-C"

      # If the -C option was explicitly included
      # and the output format is not JSON;
      # remove it from the input_args to prevent
      # conversion errors
      input_args.delete("-C") if !@output_format.json?

      # If there are any files within the *input_args*, ignore "." as it's both a valid file and filter
      idx = if first_file_idx = input_args.index { |a| a != "." && File.exists? a }
              # extract everything else
              first_file_idx - 1
            else
              # otherwise just take it all
              -1
            end

      @args.concat input_args.delete_at 0..idx
    end

    # Extracts the provided *arg_name* from `ARGV` if it exists;
    # concatenating the result to the internal arg array.
    private def consume_file_arg(input_args : Array(String), arg_name : String, count : Int32 = 2) : Nil
      input_args.index(arg_name).try { |idx| @args.concat input_args.delete_at idx..(idx + count) }
    end

    private def consume_file_args(input_args : Array(String), *arg_names : String, count : Int32 = 2) : Nil
      arg_names.each { |name| consume_file_arg input_args, name, count }
    end
  end
end
