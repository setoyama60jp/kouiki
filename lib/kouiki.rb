# coding: utf-8
require 'rexml/document'

module Kouiki
  class OreillyXmlConverter
    include REXML

    def initialize xml_file_name
      @xml_file_name = xml_file_name
    end

    def convert_to_markdown
      doc = Document.new File.new @xml_file_name

      XPath.each(doc, "//chapter").inject(1) do |index, chapter|

        file_name = "chapter" + index.to_s + ".txt"

        result = File.open(file_name, "w")

        #タイトルを書き込み
        result.write('# ' + chapter.elements["title"].text + "\n")
        crlf result #改行
        crlf result

        ##とりあえず、ソースコード要素全てを抽出
        program_listings = chapter.elements.to_a("//programlisting")

        program_listings.each do |program_listing|
          write_program_listing program_listing, result
        end

        result.close

        #チャプター番号を1個増やす
        index + 1
      end


    end

    private

    def write_program_listing(program_listing_element, file)
      file.write("```") and crlf file
      file.write('#!python') and crlf file
      file.write(program_listing_element.text + "\n")
      file.write("```") and crlf file
    end

    def crlf(file)
      file.write("\n")
    end
  end
end