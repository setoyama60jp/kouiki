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

        write_chapter(file_name, chapter)

        #チャプター番号を1個増やす
        index + 1
      end


    end

    private

    def write_chapter(file_name, chapter_element)
      result = File.open(file_name, "w")

      #タイトルを書き込み
      result.write('# ' + chapter_element.elements["title"].text + "\n")
      crlf result #改行
      crlf result

      ##とりあえず、ソースコード要素全てを抽出
      program_listings = chapter_element.elements.to_a("//programlisting")

      program_listings.each do |program_listing|
        write_program_listing program_listing, result, "python"
      end

      result.close
    end

    def write_program_listing(program_listing_element, file, language = nil)
      file.write("```") and crlf file
      file.write('#!') + file.write(language) and crlf file if language

      program_listing_element.each_child do |child|
        if (child.node_type == :text)
          file.write(child.value)
        else
          if (child.node_type == :element && child.name == "userinput")
            file.write(child.text) and crlf file
          else
            file.write(child.text)
          end
        end
      end
      crlf file

      file.write("```") and crlf file
    end

    def crlf(file)
      file.write("\n")
    end
  end
end