module OdinFlex
  class AR
    include Enumerable

    HEADER_LENGTH = 16 + # File Identifier
      12 + # File modification timestamp
      6  + # Owner ID
      6  + # Group ID
      8  + # File Mode
      10 + # File size in bytes
      2    # Ending characters

    AR_HEADER = "!<arch>\n"

    def self.is_ar? io
      pos = io.pos
      header = io.read(AR_HEADER.length)
      header == AR_HEADER
    ensure
      io.seek pos, IO::SEEK_SET
    end

    def initialize fd
      @fd = fd
      @pos = fd.pos
    end

    Info = Struct.new :identifier, :timestamp, :owner, :group, :mode, :size, :pos

    def each
      @fd.seek @pos, IO::SEEK_SET
      header = @fd.read(AR_HEADER.length)

      raise "Wrong Header" unless header == AR_HEADER

      loop do
        break if @fd.eof?

        identifier, timestamp, owner, group, mode, size, ending =
          @fd.read(HEADER_LENGTH).unpack('A16A12A6A6A8A10A2')

        raise "wrong ending #{ending}" unless ending.bytes == [0x60, 0x0A]
        pos = @fd.pos

        fname_len = 0

        if identifier =~ /\d+$/ # BSD
          fname_len = identifier[/\d+$/].to_i
          filename = @fd.read(fname_len).unpack1('A*')
        else
          if identifier == "/" || identifier == "//"
            filename = identifier
          else
            filename = identifier.sub(/[\/]$/, '')
          end
        end
        info = Info.new filename, timestamp, owner, group, mode, size.to_i - fname_len, @fd.pos

        yield info

        @fd.seek size.to_i + pos, IO::SEEK_SET
      end
    end
  end
end
