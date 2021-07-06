# OdinFlex

This is just a collection of weird tools that I wrote for dealing with some
binary file formats.  There is an AR parser and a MachO parser in here.


## Examples

Find debugging information:

```ruby
mach_o = OdinFlex::MachO.new(io)
abbrev = mach_o.find_section "__debug_abbrev"

# Do stuff with the debugging information
```

List all symbols in Ruby:

```ruby
require "odinflex/mach-o"

File.open(RbConfig.ruby) do |f|
  my_macho = OdinFlex::MachO.new f
  my_macho.each do |section|
    if section.symtab?
      section.nlist.each { |symbol|
        p symbol
      }
    end
  end
end
```

Find Ruby's archive file, then read the archive:

```ruby
require "odinflex/mach-o"
require "odinflex/ar"

archive = nil

File.open(RbConfig.ruby) do |f|
  my_macho = OdinFlex::MachO.new f
  my_macho.each do |section|
    if section.symtab?
      archive = section.nlist.find_all(&:archive?).map(&:archive).uniq.first
      break
    end
  end
end

File.open(archive) do |f|
  ar = OdinFlex::AR.new f
  ar.each do |object_file|
    p object_file.identifier
  end
end
```
