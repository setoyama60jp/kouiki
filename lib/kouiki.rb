# coding: utf-8
require 'rexml/document'

module Kouiki

  class ChapterResource
    attr_accessor :tables
    attr_accessor :figures
    attr_accessor :program_lists
    attr_accessor :chapter_num
    attr_accessor :footnotes_count

    def initialize(chapter_num)
      @chapter_num = chapter_num
      @tables = Array.new
      @figures = Array.new
      @program_lists = Array.new
      @footnotes_count = 1
    end

    def increment_footnote_count
      @footnotes_count = @footnotes_count + 1
    end

    def get_reference_name(reference_id)
      if @tables.index(reference_id)
        return "Table " + @chapter_num.to_s + "-" + (@tables.index(reference_id) + 1).to_s
      end

      if @figures.index(reference_id)
        return "Figure " + @chapter_num.to_s + "-" + (@figures.index(reference_id) + 1).to_s
      end

      return "[Reference Not Found]"
    end

  end

  class OreillyXmlConverter
    include REXML

    def initialize xml_file_name
      @xml_file_name = xml_file_name
    end

    def convert_to_markdown
      doc = Document.new File.new @xml_file_name

      XPath.each(doc, "//chapter").inject(1) do |index, chapter|

        file_name = "chapter" + index.to_s + ".txt"
        chapter_resource = ChapterResource.new index
        write_chapter(file_name, chapter, chapter_resource)

        #チャプター番号を1個増やす
        index + 1
      end

      #chater3 = doc.elements["//chapter[3]"]
      #chapter_resource = ChapterResource.new 3
      #write_chapter("chater3.txt", chater3, chapter_resource)

      #chater2 = doc.elements["//chapter[2]"]
      #chapter_resource = ChapterResource.new 2
      #write_chapter("chater2.txt", chater2, chapter_resource)


    end

    private

    def write_chapter(file_name, chapter_element, chapter_resource)
      result = File.open(file_name, "w")

      init_chapter(chapter_element, result, chapter_resource)

      chapter_element.elements.each do |child_element|
        write_correspoinding_element(child_element, result, chapter_resource)
      end

      result.close
    end

    def init_chapter(chapter_element, file, chapter_resource)
      #タイトルはここで先に出力しておく
      chap_title_element = chapter_element.elements["title"]
      write_chapter_title(file, chap_title_element)

      #図、表は参照するために、リストを初期化しておく

      #まずは図のリスト
      chapter_element.elements.to_a(".//figure").each do |figure|
        chapter_resource.figures.push figure.attribute('id').to_s
      end

      #puts chapter_resource.figures

      #次に表のリスト
      chapter_element.elements.to_a(".//table").each do |table|
        chapter_resource.tables.push table.attribute('id').to_s
      end

      #puts chapter_resource.tables

    end

    def write_correspoinding_element(element, file, chapter_resource)
      if (element.node_type == :element)

        if (element.name == "blockquote")
          write_blockquote(file, element, chapter_resource)
        end

        if (element.name == "note")
          write_note(file, element, chapter_resource)
        end

        if (element.name == "caution")
          write_caution(file, element, chapter_resource)
        end

        if (element.name == "warning")
          write_warning(file, element, chapter_resource)
        end

        if (element.name == "para")
          write_para(file, element, chapter_resource)
        end

        if (element.name == "programlisting")
          write_program_listing(file, element, "python")
        end

        if (element.name == "sect1")
          write_section(file, element, chapter_resource, 1)
        end

        if (element.name == "sect2")
          write_section(file, element, chapter_resource, 2)
        end

        if (element.name == "sect3")
          write_section(file, element, chapter_resource, 3)
        end

        if (element.name == "itemizedlist")
          write_itemizedlist(file, element, chapter_resource)
        end

        if (element.name == "variablelist")
          write_variablelist(file, element, chapter_resource)
        end

        if (element.name == "figure")
          write_figure(file, element, chapter_resource)
        end

        if (element.name == "table")
          write_table(file, element, chapter_resource)
        end

        if (element.name == "sidebar")
          write_sidebar(file, element, chapter_resource)
        end
      end
    end

    def write_figure(file, element, chapter_resource)
      figure_num = chapter_resource.get_reference_name(element.attribute('id').to_s)

      output = figure_num + ". "

      figure_title = element.elements["title"].text

      if figure_title
        output = output + figure_title
      end

      file.write(output)
      insert_crlf_into file #改行
      insert_crlf_into file #空行を挿入
    end

    def write_table(file, element, chapter_resource)

      #まずは、表の上にタイトルを挿入
      table_num = chapter_resource.get_reference_name(element.attribute('id').to_s)
      output = table_num + ". "

      table_title = element.elements["title"].text

      if table_title
        output = output + table_title
      end

      file.write(output)
      insert_crlf_into file #改行
      insert_crlf_into file #空行を挿入

      #次にテーブルの中身を書く

      #テーブルヘッダーを取得
      thead_row = element.elements['.//thead/row']

      thead_entries = thead_row.elements.to_a("entry")
      thead_entries.each.inject(true) do |is_first_element, entry|
        unless is_first_element
          file.write('|')
        else
          is_first_element = false
        end
        write_all_text_contents(file, entry, chapter_resource, true, true, true)
      end
      insert_crlf_into file #改行
      #ヘッダー行の次の区切り行を追加

      (thead_entries.length - 1).times do
        file.write('----')
        file.write('|')
      end
      file.write('----')
      insert_crlf_into file #改行

      #次にテーブルのコンテンツを追加していく
      tbody_rows = element.elements.to_a(".//tbody/row")

      tbody_rows.each do |row|
        row.elements.to_a("entry").each.inject(true) do |is_first_entry, entry|
          unless is_first_entry
            file.write('|')
          else
            is_first_entry = false
          end
          write_all_text_contents(file, entry, chapter_resource, true, true, true)
        end
        insert_crlf_into file #改行
      end

      insert_crlf_into file #空行を入れる
    end

    def write_variablelist(file, element, chapter_resource)
      element.elements.to_a("varlistentry").each do |varlist_entry|
        term = varlist_entry.elements["term"]
        #定義する言葉を書き出す
        file.write(term.text)
        insert_crlf_into file #改行

        list_item = varlist_entry.elements["listitem"]
        #定義の説明を書く
        list_item.elements.to_a("para").each do |para|
          file.write(': ')
          write_para(file, para, chapter_resource, true)
        end
        #最後は改行をしておく
        insert_crlf_into file

      end
    end

    def write_itemizedlist(file, element, chapter_resource)
      element.elements.to_a("listitem").each do |list_item|

        file.write("* ")

        list_item.elements.to_a("para").each do |para|
          write_para(file, para, chapter_resource, true)
        end
      end

      #末尾には空行を入れておく。
      insert_crlf_into file
    end

    def write_warning(file, element, chapter_resource)
      write_blockquote(file, element, chapter_resource)
    end

    def write_note(file, element, chapter_resource)
      write_blockquote(file, element, chapter_resource)
    end

    def write_caution(file, element, chapter_resource)
      write_blockquote(file, element, chapter_resource)
    end

    def write_sidebar(file, element, chapter_resource)
      #実際はsection1と同じレベルで中身を書く
      insert_hr_into(file)

      write_section(file, element, chapter_resource, 2)

      insert_hr_into(file)
    end

    def write_section(file, section_element, chapter_resource, section_level)

      #タイトルをまずは書いておく
      section_title_element = section_element.elements["title"]
      write_section_title(file, section_title_element, section_level)

      section_element.elements.each do |element|
        write_correspoinding_element(element, file, chapter_resource)
      end
    end

    def write_section_title(file, section1_title_element, section_level)
      #タイトルを書き込み
      title_tag = '#' + '#' * section_level + ' '
      file.write(title_tag + section1_title_element.text + "\n")
      insert_crlf_into file #改行
      insert_crlf_into file #空行を入れる

    end

    def write_para(file, para_element, chapter_resource, without_end_crlf = false)

      write_all_text_contents(file, para_element, chapter_resource, without_end_crlf, false, true)

    end


    def write_all_text_contents(file, element, chapter_resource, without_end_crlf=false, inline=false, remove_crlf=false)
      footnote_index_and_para_elements = Hash.new #{footnote_index, para_element_list}形式のハッシュ

      element.each_child do |child|
        if (child.node_type == :text)
          if (remove_crlf)
            file.write(remove_all_crlf(child.value))
          else
            file.write(child.value)
          end
        else
          if (child.node_type == :element and child.name == "emphasis")
            file.write(clip_markdown_italic_for(child.text))
          elsif (child.node_type == :element and child.name == "ulink")
            write_ulink file, child
          elsif (child.node_type == :element and child.name == "indexterm")
            #索引用のマークアップは無視する
            #何もしない。必要になったらここに処理を書く
          elsif (child.node_type == :processing_instruction)
            #<?dbfo-need?>などのタグは何もしない
          elsif (child.node_type == :element and child.name == "footnote")
            footnote_index = chapter_resource.footnotes_count
            chapter_resource.increment_footnote_count

            footnote_index_and_para_elements[footnote_index] = child.elements.to_a("para")

            write_footnote_index(file, footnote_index)
          elsif (child.node_type == :element and child.name == "xref")
            write_xref(file, child, chapter_resource)
          elsif (child.node_type == :elemet and child.name == "inlineequation")
            write_inline_text_contents(file, element, chapter_resource)
          else
            if (remove_crlf)
              file.write(remove_all_crlf(child.text)) if (child.text)
            else
              file.write(child.text)
            end

            if (child.has_elements?)
              child.elements.each do |element|
                write_inline_text_contents(file, element, chapter_resource)
              end
            end
          end
        end
      end
      insert_crlf_into file unless inline #改行
      insert_crlf_into file unless without_end_crlf #空行を入れる

      #foot_notesがあれば、パラグラフの末尾に、foot_noteを記述する
      if (footnote_index_and_para_elements.length > 0 and not inline)
        footnote_index_and_para_elements.each do |footnote_index, para_element_list|

          write_footnote_index(file, footnote_index, true)
          para_element_list.each do |para_element|
            write_all_text_contents(file, para_element, chapter_resource, false, true, true) #末尾の改行は必要
          end
          #末尾には空行を入れておく。
          insert_crlf_into file
        end
      end
    end

    def write_inline_text_contents(file, element, chapter_resource)
      write_all_text_contents(file, element, chapter_resource, true, true, true)
    end


    def write_xref(file, element, chapter_resource)
      #属性linkendを取得
      linkend = element.attribute("linkend").to_s
      ref_name = chapter_resource.get_reference_name(linkend)

      file.write(ref_name)
    end

    def write_footnote_index(file, footnote_index, is_footnote_contents=false)
      unless is_footnote_contents
        file.write("[^" + footnote_index.to_s + "]")
      else
        file.write("[^" + footnote_index.to_s + "]: ")
      end
    end

    def write_ulink (file, ulink_element)
      unless ulink_element.has_elements? or ulink_element.has_text?
        #内部にElementもテキストも持たないときは、属性urlの値を出力
        file.write(ulink_element.attribute('url'))
        insert_whitespace_into file #最後に半角空白を入れておく
      else #内部にElementsかテキストを持つときは、展開しながらurlを括弧書きで表示する
        em_element = ulink_element.elements["emphasis"]
        if (em_element)
          insert_whitespace_into file
          output_text =clip_markdown_italic_for(em_element.text) +
            '(' + ulink_element.attribute('url').to_s + ')'
          file.write(output_text)
        else
          insert_whitespace_into file
          child_text = ulink_element.text
          url_attribute = ulink_element.attribute('url').to_s

          if (child_text == url_attribute)
            #属性値とchild_textが同じurlを持っていたら、片方だけ出力（たまにある。。）
            file.write(child_text)
          else
            output_text =child_text + '(' + url_attribute + ')'
            file.write(output_text)
          end

        end
      end
    end

    def write_blockquote(file, blockquote_element, chapter_resource)
      blockquote_element.elements.to_a("para").each do |para|
        insert_markdown_blockquote_into file
        write_all_text_contents(file, para, chapter_resource, false, false, false)
      end
      attri_element = blockquote_element.elements["attribution"]
      if attri_element
        insert_markdown_blockquote_into file
        file.write('—')
        file.write(attri_element.text)
      end
      insert_crlf_into file #改行
      insert_crlf_into file #空行を入れる
      insert_hr_into file #blockquoteが2回連続で続いた場合に、つながってしまうので、hrタグを末尾に挿入する。
    end

    def write_chapter_title(file, chap_title_element)
      #タイトルを書き込み
      file.write('# ' + chap_title_element.text + "\n")
      insert_crlf_into file #改行
      insert_crlf_into file #空行を入れる

    end

    def write_program_listing(file, program_listing_element, language = nil)
      file.write("```") and insert_crlf_into file
      file.write('#!') + file.write(language) and insert_crlf_into file if language

      program_listing_element.each_child do |child|
        if (child.node_type == :text)
          file.write(child.value)
        else
          if (child.node_type == :element && child.name == "userinput")
            file.write(child.text) and insert_crlf_into file
          else
            file.write(child.text)
          end
        end
      end
      insert_crlf_into file

      file.write("```") and insert_crlf_into file
      insert_crlf_into file #空行を入れる
    end

    def insert_crlf_into(file)
      file.write("\n")
    end

    def insert_markdown_blockquote_into(file)
      file.write(">") #先頭にmarkdownのblockquoteを付与する
    end

    def clip_markdown_emphasis_for(text)
      return '**' + text + '**'
    end

    def clip_markdown_italic_for(text)
      return '*' + text + '*'
    end

    def insert_whitespace_into(file)
      file.write(' ')
    end

    def remove_all_crlf(text)
      return text.gsub(/[\n]/, "")
    end

    def insert_hr_into(file)
      file.write('----')
      insert_crlf_into(file)
    end
  end
end