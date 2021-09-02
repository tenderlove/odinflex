require "helper"

module OdinFlex
  class MachODWARFIntegrationTest < Test
    def test_can_read_archive
      skip unless File.exist?(ruby_archive)
      archive = nil

      File.open(RbConfig.ruby) do |f|
        my_macho = MachO.new f
        my_macho.each do |section|
          if section.symtab?
            archive = section.nlist.find_all(&:archive?).map(&:archive).uniq.first
          end
        end
      end

      assert archive

      found_object = nil

      File.open(archive) do |f|
        ar = AR.new f
        ar.each do |object_file|
          next unless object_file.identifier.end_with?(".o")
          next unless object_file.identifier == "version.o"

          found_object = object_file
        end
      end

      assert found_object
    end
  end
end
