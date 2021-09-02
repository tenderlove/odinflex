require "helper"

module OdinFlex
  class RubyTest < OdinFlex::Test
    def ruby_archive
      File.join RbConfig::CONFIG["prefix"], "lib", RbConfig::CONFIG["LIBRUBY"]
    end

    def test_idk
      File.open(ruby_archive) do |f|
        macho = OdinFlex::MachO.new f
        macho.each do |section|
          next unless section.symtab?
          section.nlist.each do |sym|
            if sym.oso?
              p sym.name
              p File.exists?(sym.name)
            end
          end
        end
      end
    end

    def test_ruby_archive
      assert File.file?(ruby_archive)
    end

    def test_read_archive
      files = []
      File.open(ruby_archive) do |f|
        AR.new(f).each { |file| files << file.identifier }
      end
      assert_includes files, "gc.o"
    end

    def test_read_archive_twice
      files = []
      puts ruby_archive
      File.open(ruby_archive) do |f|
        ar = AR.new(f)
        ar.each { |file| files << file.identifier }
        assert_includes files, "gc.o"
        files.clear
        ar.each { |file| files << file.identifier }
        assert_includes files, "gc.o"
      end
    end

    def test_macho_in_archive
      File.open(ruby_archive) do |f|
        ar = AR.new f
        gc = ar.find { |file| file.identifier == "gc.o" }

        f.seek gc.pos, IO::SEEK_SET
        macho = MachO.new f
        section = macho.find_section("__debug_str")
        assert_equal "__debug_str", section.sectname
      end
    end

    def test_macho_find_sections
      File.open(ruby_archive) do |f|
        ar = AR.new f
        gc = ar.find { |file| file.identifier == "gc.o" }

        f.seek gc.pos, IO::SEEK_SET
        macho = MachO.new f
        assert macho.find_section("__debug_str")
        assert macho.find_section("__debug_abbrev")
        assert macho.find_section("__debug_info")
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
      sym = nil

      File.open(RbConfig.ruby) do |f|
        my_macho = MachO.new f

        my_macho.each do |section|
          if section.symtab?
            sym = section.nlist.find do |symbol|
              symbol.name == "_rb_vm_get_insns_address_table" && symbol.value
            end
            break if sym
          end
        end
      end

      addr = sym.value + Hacks.slide
      ptr = Fiddle::Function.new(addr, [], TYPE_VOIDP).call
      len = RubyVM::INSTRUCTION_NAMES.length
      assert ptr[0, len * Fiddle::SIZEOF_VOIDP].unpack("Q#{len}")
    end

    def test_guess_slide
      File.open(RbConfig.ruby) do |f|
        my_macho = MachO.new f

        my_macho.each do |section|
          if section.symtab?
            section.nlist.each do |symbol|
              if symbol.name == "_rb_st_insert"
                guess_slide = Fiddle::Handle::DEFAULT["rb_st_insert"] - symbol.value
                assert_equal Hacks.slide, guess_slide
              end
            end
          end
        end
      end
    end

    def test_find_global
      File.open(RbConfig.ruby) do |f|
        my_macho = MachO.new f

        my_macho.each do |section|
          if section.symtab?
            section.nlist.each do |symbol|
              if symbol.name == "_ruby_api_version"
                if symbol.value > 0
                  addr = symbol.value + Hacks.slide
                  pointer = Fiddle::Pointer.new(addr, Fiddle::SIZEOF_INT * 3)
                  assert_equal RbConfig::CONFIG["ruby_version"].split(".").map(&:to_i),
                    pointer[0, Fiddle::SIZEOF_INT * 3].unpack("LLL")
                else
                  assert_predicate symbol, :stab?
                  assert_predicate symbol, :gsym?
                end
              end
            end
          end
        end
      end
    end
  end
end
