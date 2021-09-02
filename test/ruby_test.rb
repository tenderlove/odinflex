require "helper"

module OdinFlex
  class RubyTest < OdinFlex::Test
    def archive
      File.join File.dirname(__FILE__), "fixtures", "test.a"
    end

    AR_FILES = ["__.SYMDEF SORTED", "README.md", "Gemfile", "test.rb", "a.out"]

    def test_read_archive
      files = []
      File.open(archive) do |f|
        AR.new(f).each { |file| files << file.identifier }
      end
      assert_equal AR_FILES, files
    end

    def test_read_archive_twice
      files = []
      File.open(archive) do |f|
        ar = AR.new(f)
        ar.each { |file| files << file.identifier }
        assert_equal AR_FILES, files
        files.clear
        ar.each { |file| files << file.identifier }
        assert_equal AR_FILES, files
      end
    end

    def test_macho_in_archive
      File.open(archive) do |f|
        ar = AR.new f
        gc = ar.find { |file| file.identifier == "a.out" }

        f.seek gc.pos, IO::SEEK_SET
        macho = MachO.new f
        sections = macho.find_all(&:section?)
        segnames = sections.map(&:segname)
        sectnames = sections.map(&:sectname)
        assert_equal ["__TEXT", "__TEXT", "__TEXT", "__TEXT", "__TEXT", "__DATA_CONST", "__DATA", "__DATA"], segnames
        assert_equal ["__text", "__stubs", "__stub_helper", "__cstring", "__unwind_info", "__got", "__la_symbol_ptr", "__data"], sectnames
      end
    end

    def test_macho_find_sections
      File.open(archive) do |f|
        ar = AR.new f
        bin = ar.find { |file| file.identifier == "a.out" }

        f.seek bin.pos, IO::SEEK_SET
        macho = MachO.new f
        assert macho.find_section("__text")
        assert macho.find_section("__stubs")
        assert macho.find_section("__cstring")
      end
    end

    [
      [:section?, MachO::Section],
      [:symtab?, MachO::LC_SYMTAB],
      [:segment?, MachO::LC_SEGMENT_64],
      [:dysymtab?, MachO::LC_DYSYMTAB],
      [:command?, MachO::Command],
    ].each do |predicate, klass|
      define_method :"test_find_#{predicate}" do
        File.open(RbConfig.ruby) do |f|
          my_macho = MachO.new f
          list = my_macho.find_all(&predicate)
          refute_predicate list, :empty?
          assert list.all? { |x| x.is_a?(klass) }
        end
      end
    end

    def test_rb_vm_get_insns_address_table
      symbols = {}
      file = File.exist?(ruby_archive) ? RbConfig.ruby : ruby_so
      File.open(file) do |f|
        my_macho = MachO.new f

        my_macho.each do |section|
          if section.symtab?
            section.nlist.each do |symbol|
              name = symbol.name.delete_prefix(RbConfig::CONFIG["SYMBOL_PREFIX"])
              symbols[name] = symbol.value if symbol.value
            end
          end
        end
      end

      slide = Fiddle::Handle::DEFAULT["rb_st_insert"] - symbols["rb_st_insert"]
      addr = symbols["rb_vm_get_insns_address_table"] + slide

      ptr = Fiddle::Function.new(addr, [], Fiddle::TYPE_VOIDP).call
      len = RubyVM::INSTRUCTION_NAMES.length
      assert ptr[0, len * Fiddle::SIZEOF_VOIDP].unpack("Q#{len}")
    end

    def test_guess_slide
      symbols = {}
      file = File.exist?(ruby_archive) ? RbConfig.ruby : ruby_so

      File.open(file) do |f|
        my_macho = MachO.new f

        my_macho.each do |section|
          if section.symtab?
            section.nlist.each do |symbol|
              name = symbol.name.delete_prefix(RbConfig::CONFIG["SYMBOL_PREFIX"])
              symbols[name] = symbol.value
            end
          end
        end
      end

      slide = Fiddle::Handle::DEFAULT["rb_st_insert"] - symbols["rb_st_insert"]
      assert_equal Fiddle::Handle::DEFAULT["rb_st_update"],
        symbols["rb_st_update"] + slide
    end

    def test_find_global
      symbols = {}
      file = File.exist?(ruby_archive) ? RbConfig.ruby : ruby_so

      File.open(file) do |f|
        my_macho = MachO.new f

        my_macho.each do |section|
          if section.symtab?
            section.nlist.each do |symbol|
              name = symbol.name.delete_prefix(RbConfig::CONFIG["SYMBOL_PREFIX"])
              symbols[name] = symbol.value
              if name == "ruby_api_version"
                if symbol.value > 0
                else
                  assert_predicate symbol, :stab?
                  assert_predicate symbol, :gsym?
                end
              end
            end
          end
        end
      end

      slide = Fiddle::Handle::DEFAULT["rb_st_insert"] - symbols["rb_st_insert"]
      addr = symbols["ruby_api_version"] + slide
      pointer = Fiddle::Pointer.new(addr, Fiddle::SIZEOF_INT * 3)
      assert_equal RbConfig::CONFIG["ruby_version"].split(".").map(&:to_i),
        pointer[0, Fiddle::SIZEOF_INT * 3].unpack("LLL")
      symbols
    end
  end
end
