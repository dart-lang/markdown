require 'optparse'
require 'tmpdir'
require 'yaml'

options = {markdown_after: 'HEAD', sdk: false}

OptionParser.new do |opts|
  opts.banner = "Usage: dartdoc-compare.rb [OPTIONS] <dart-package>"

  opts.on("--dartdoc-dir=DARTDOC_DIR", "Directory of the dartdoc package") do |dartdoc_dir|
    options[:dartdoc_dir] = dartdoc_dir
  end

  opts.on("--before=BEFORE", "Markdown package 'before' ref") do |before|
    options[:markdown_before] = before
  end

  opts.on("--after=AFTER", "Markdown package 'after' ref (default: HEAD)") do |after|
    options[:markdown_after] = after
  end

  opts.on("--sdk", "Is the package the SDK?") do
    options[:sdk] = true
  end
end.parse!

raise OptionParser::MissingArgument.new("--dartdoc-dir") if options[:dartdoc_dir].nil?
raise OptionParser::MissingArgument.new("--before") if options[:markdown_before].nil?

class DartdocCompare
  def initialize(options)
    @dartdoc_dir = options[:dartdoc_dir]
    @markdown_before = options[:markdown_before]
    @markdown_after = options[:markdown_after]
    @dartdoc_bin = "#{@dartdoc_dir}/bin/dartdoc.dart"
    @dartdoc_pubspec_path = "#{@dartdoc_dir}/pubspec.yaml"
    @sdk = options[:sdk] ? '--sdk-docs --dart-sdk=%s' : ''
  end

  def compare(package)
    # Generate docs with Markdown "A".
    out_before = run_dartdoc(@markdown_before, package)

    # Generate docs with Markdown "B".
    out_after = run_dartdoc(@markdown_after, package)

    # Compare outputs
    diff = "diff -r -B #{out_before} #{out_after}"
    puts "Diff lines: #{`#{diff} |wc -l`.to_i}"
    puts diff
  end

  def run_dartdoc(markdown_ref, package)
    puts '=' * 80
    puts "Running dartdoc for #{markdown_ref}..."
    puts '=' * 80
    update_dartdoc_pubspec(markdown_ref)
    Dir.chdir(package)
    system('pub get')
    out = Dir.mktmpdir("dartdoc-compare-#{markdown_ref}__")
    sdk_options = @sdk % package
    cmd = "dart #{@dartdoc_bin} --output=#{out} #{sdk_options}"
    puts "Command: #{cmd}"
    system(cmd)
    puts ''

    out
  end

  def update_dartdoc_pubspec(markdown_ref)
    Dir.chdir(@dartdoc_dir)
    dartdoc_pubspec = YAML.load(File.read(@dartdoc_pubspec_path))

    dartdoc_pubspec['dependencies']['markdown'] = {
      'git' => {
        'url' => 'git://github.com/dart-lang/markdown.git',
        'ref' => markdown_ref
      }
    }

    File.write(@dartdoc_pubspec_path, YAML.dump(dartdoc_pubspec))
    system('pub get')
  end
end

package_to_document = ARGV.shift

comparer = DartdocCompare.new(options)
comparer.compare(package_to_document)
