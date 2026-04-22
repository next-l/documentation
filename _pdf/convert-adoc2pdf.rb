#!/usr/bin/env ruby

require "tempfile"
require "fileutils"
require "open3"

HEADER_REGEX = /\A---.*?---/m
TOC_REGEX    = /^include::.*_toc.*$/
XREF_REGEX   = /(xref:enju_\w+)_\d+\.adoc/
IMAGE_REGEX   = /image(::?)\.\.\/assets\/images\//
INCLUDE_REGEX = /^include::..\/_includes/

def usage!
  abort "Usage: #{File.basename($PROGRAM_NAME)} 1.4/enju_manual_all.adoc"
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

  input_files.each do |input_file|
    base_name = File.basename(input_file, "_all.adoc")
    base_dir = File.dirname(input_file)
    version_dir = File.basename(base_dir)
    output_pdf = output_pdf_path(input_file)
    warn "input:  #{input_file}"
    warn "output: #{output_pdf}"
    #warn "base_dir: #{base_dir}"
    #warn "version: #{version_dir}"

    FileUtils.cp(File.join(base_dir, "..", "..", version_dir, "enju_introduction.adoc"), base_dir)

    Dir.glob(File.join(base_dir,"..", "..", version_dir, "#{base_name}*.adoc")).each do |file|
      file = File.expand_path(file)
      output_file = File.expand_path(File.join(base_dir, File.basename(file)))
      next if output_file == file
      content = File.read(file)
      normalized = normalize_content(content)
      #warn "cp #{file} #{output_file}"
      File.open(output_file, "w"){|io| io.print(normalized) }
    end
    build_pdf(input_file, output_pdf, base_dir)
  end
end