#!/usr/bin/env ruby

require "tempfile"
require "fileutils"

if $0 == __FILE__
  d = File.dirname(__FILE__)
  files = Dir.glob(File.join(d, "..", "1.4/enju_*.adoc"))
  FileUtils.cp(files, d)
  header_regex = /\A---.*?---/m
  toc_regex = /^include::.*_toc.*$/
  Dir.glob(File.join(d, "*.adoc")).each do |file|
    STDERR.puts file
    cont = open(file).read
    content_adoc = cont.sub(header_regex, "").strip
    content_adoc = content_adoc.gsub(toc_regex, "")
    open(file, "w"){|io| io.print(content_adoc) }
  end
  system("asciidoctor-pdf -a pdf-theme=default-with-fallback-font #{File.join(d, "enju_install_vm.adoc")}")
  system("asciidoctor-pdf -a pdf-theme=default-with-fallback-font #{File.join(d, "enju_setup_all.adoc")}")
  system("asciidoctor-pdf -a pdf-theme=default-with-fallback-font #{File.join(d, "enju_operation_all.adoc")}")
  system("asciidoctor-pdf -a pdf-theme=default-with-fallback-font #{File.join(d, "enju_user_all.adoc")}")
  system("asciidoctor-pdf -a pdf-theme=default-with-fallback-font #{File.join(d, "enju_webapi_all.adoc")}")
end
