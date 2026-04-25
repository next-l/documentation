#!/usr/bin/env ruby

require "tempfile"
require "fileutils"
require "open3"
require "digest"
require "time"
require "json"

CACHE_FILE = ".jekyll-pdf-cache.json"

HEADER_REGEX = /\A---.*?---/m
TOC_REGEX    = /^include::.*_toc.*$/
XREF_REGEX   = /(xref:enju_\w+)_\d+\.adoc/
IMAGE_REGEX   = /image(::?)\.\.\/assets\/images\//
INCLUDE_REGEX = /^include::..\/_includes/

def usage!
  abort "Usage: #{File.basename($PROGRAM_NAME)} 1.4/enju_manual_all.adoc"
end

def hash_files(files)
  Digest::SHA256.hexdigest(
    files.select { |f| File.file?(f) }
         .sort
         .map { |f| "#{f}\0#{Digest::SHA256.file(f).hexdigest}" }
         .join("\0")
  )
end

def normalize_content(content)
  content
    .sub(HEADER_REGEX, "")
    .gsub(TOC_REGEX, "")
    .gsub(XREF_REGEX, '\1_all.adoc')
    .gsub(IMAGE_REGEX, 'image\1../../assets/images/')
    .gsub(INCLUDE_REGEX, "include::../../_includes/")
    .strip
end

def output_pdf_path(input_file)
  input_file.sub(/\.adoc\z/, ".pdf")
end

def load_cache
  return {} unless File.exist?(CACHE_FILE)
  begin
    JSON.parse(File.read(CACHE_FILE))
  rescue JSON::ParserError
    {}
  end
end

def save_cache(cache)
  File.write(CACHE_FILE, JSON.pretty_generate(cache))
end

def source_files_for(input_file, base_name, base_dir, version_dir)
  Dir.glob(File.join(base_dir, "..", "..", version_dir, "#{base_name}*.adoc"))
end

def asciidoctor_command(input_file, output_file, base_dir)
  [
    "asciidoctor-pdf",
    "-v",
    "-t",
    "-a", "compress",
    "-a", "scripts=cjk",
    "-a", "pdf-theme=base",
    "-a", "pdf-themesdir=#{File.join(base_dir, "..")}",
    "-a", "pdf-fontsdir=#{File.join(base_dir, '..', 'fonts')}",
    "-a", "imagesdir=../../assets/images",
    "-a", "includedir=../../_includes",
#    "-r", "asciidoctor/pdf/nogmagick",
    "-o", output_file,
    input_file
  ]
end

def build_pdf(input_file, output_file, base_dir)
  stdout, stderr, status = Open3.capture3(*asciidoctor_command(input_file, output_file, base_dir))
  warn stdout unless stdout.empty?
  warn stderr unless stderr.empty?
  raise "PDF build failed: #{output_file}" unless status.success?
end

if File.expand_path($0) == File.expand_path(__FILE__)
  input_files = ARGV
  if input_files.empty?
    usage!
  end

  cache = load_cache
  cache_changed = false

  input_files.each do |input_file|
    base_name = File.basename(input_file, "_all.adoc")
    base_dir = File.dirname(input_file)
    version_dir = File.basename(base_dir)
    output_pdf = output_pdf_path(input_file)
    warn "input:  #{input_file}"
    warn "output: #{output_pdf}"
    #warn "base_dir: #{base_dir}"
    #warn "version: #{version_dir}"

    source_files = source_files_for(input_file, base_name, base_dir, version_dir)
    current_hash = hash_files(source_files)
    cache_key = input_file
    if File.exist?(output_pdf) and cache.dig(cache_key, "hash") == current_hash
      warn "skip: PDF is up to date"
      next
    end

    source_files.each do |file|
      file = File.expand_path(file)
      output_file = File.expand_path(File.join(base_dir, File.basename(file)))
      next if output_file == file
      content = File.read(file)
      normalized = normalize_content(content)
      #warn "cp #{file} #{output_file}"
      File.open(output_file, "w"){|io| io.print(normalized) }
    end
    build_pdf(input_file, output_pdf, base_dir)

    cache[cache_key] = {
      "hash" => current_hash,
      "sources_count" => source_files.count { |f| File.file?(f) },
      "updated_at" => Time.now.utc.iso8601
    }
    cache_changed = true
  end
  save_cache(cache) if cache_changed
end