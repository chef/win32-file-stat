#####################################################################
# test_file_stat.rb
#
# Test case for stat related methods of win32-file. You should use
# the 'rake test' task to run these tests.
#####################################################################
require 'etc'
require 'ffi'
require 'test-unit'
require 'win32/file/stat'

class TC_Win32_File_Stat < Test::Unit::TestCase
  extend FFI::Library
  ffi_lib :kernel32

  attach_function :GetDriveType, :GetDriveTypeA, [:string], :ulong
  attach_function :IsWow64Process, [:uintptr_t, :pointer], :bool
  attach_function :GetCurrentProcess, [], :uintptr_t
  attach_function :GetFileAttributes, :GetFileAttributesA, [:string], :ulong
  attach_function :SetFileAttributes, :SetFileAttributesA, [:string, :ulong], :bool

  DRIVE_REMOVABLE = 2
  DRIVE_CDROM     = 5
  DRIVE_RAMDISK   = 6

  # Helper method to determine if you're on a 64 bit version of Windows
  def windows_64?
    bool = false

    if respond_to?(:IsWow64Process, true)
      pbool = FFI::MemoryPointer.new(:int)

      # The IsWow64Process function will return false for a 64 bit process,
      # so we check using both the address size and IsWow64Process.
      if FFI::Platform::ADDRESS_SIZE == 64
        bool = true
      else
        if IsWow64Process(GetCurrentProcess(), pbool)
          bool = true if pbool.read_int == 1
        end
      end
    end

    bool
  end

  def self.startup
    'A'.upto('Z'){ |volume|
      volume += ":\\"
      case GetDriveType(volume)
      when DRIVE_REMOVABLE, DRIVE_CDROM, DRIVE_RAMDISK
        @@block_dev = volume
        break
      end
    }

    @@txt_file = File.join(File.expand_path(File.dirname(__FILE__)), 'test_file.txt')
    @@exe_file = File.join(File.expand_path(File.dirname(__FILE__)), 'test_file.exe')
    @@sys_file = File.join(File.expand_path(File.dirname(__FILE__)), 'C:/pagefile.sys')

    File.open(@@txt_file, "w"){ |fh| fh.print "This is a test\nHello" }
    File.open(@@exe_file, "wb"){ |fh| fh.print "This is a test" }
  end

  def setup
    @dir  = Dir.pwd
    @stat = File::Stat.new(@@txt_file)
    @temp = 'win32_file_stat.tmp'
    File.open(@temp, 'w'){}
    @attr = GetFileAttributes(@@txt_file)
  end

  test "version is set to expected value" do
    assert_equal('1.4.0', File::Stat::VERSION)
  end

  test "constructor does not modify argument" do
    expected = File.join(File.expand_path(File.dirname(__FILE__)), 'test_file.txt')
    File::Stat.new(@@txt_file)
    assert_equal(expected, @@txt_file)
  end

  test "archive? method basic functionality" do
    assert_respond_to(@stat, :archive?)
    assert_nothing_raised{ @stat.archive? }
  end

  test "archive? method returns a boolean value" do
    assert_boolean(@stat.archive?)
  end

  test "atime method basic functionality" do
    assert_respond_to(@stat, :atime)
    assert_nothing_raised{ @stat.atime }
  end

  test "atime method returns expected value" do
    assert_kind_of(Time, @stat.atime)
    assert_true(@stat.atime.to_i > 0)
  end

  test "mtime method basic functionality" do
    assert_respond_to(@stat, :mtime)
    assert_nothing_raised{ @stat.mtime }
  end

  test "mtime method returns expected value" do
    assert_kind_of(Time, @stat.mtime)
    assert_true(@stat.mtime.to_i > 0)
  end

  test "ctime method basic functionality" do
    assert_respond_to(@stat, :ctime)
    assert_nothing_raised{ @stat.ctime }
  end

  test "ctime method returns expected value" do
    assert_kind_of(Time, @stat.ctime)
    assert_true(@stat.ctime.to_i > 0)
  end

  test "blksize basic functionality" do
    assert_respond_to(@stat, :blksize)
    assert_kind_of(Fixnum, @stat.blksize)
  end

  test "blksize returns expected value" do
    assert_equal(4096, @stat.blksize)
    assert_equal(4096, File::Stat.new("C:\\").blksize)
  end

  test "blockdev? basic functionality" do
    assert_respond_to(@stat, :blockdev?)
    assert_boolean(@stat.blockdev?)
  end

  test "blockdev? returns the expected value for a non-block device" do
    assert_false(@stat.blockdev?)
    assert_false(File::Stat.new('NUL').blockdev?)
  end

  test "blockdev? returns the expected value for a block device" do
    begin
      assert_true(File::Stat.new(@@block_dev).blockdev?)
    rescue StandardError, SystemCallError
      omit("Skipping because drive is empty or not found")
    end
  end

  test "blocks basic functionality" do
    assert_respond_to(@stat, :blocks)
    assert_kind_of(Fixnum, @stat.blocks)
  end

  test "blocks method returns expected value" do
    assert_equal(1, @stat.blocks)
  end

  test "chardev? custom method basic functionality" do
    assert_respond_to(@stat, :chardev?)
    assert_boolean(@stat.chardev?)
  end

  test "chardev? custom method returns expected value" do
    assert_true(File::Stat.new("NUL").chardev?)
    assert_false(File::Stat.new("C:\\").chardev?)
  end

  test "custom comparison method basic functionality" do
    assert_respond_to(@stat, :<=>)
    assert_nothing_raised{ @stat <=> File::Stat.new(@@exe_file) }
  end

  test "custom comparison method works as expected" do
    assert_equal(0, @stat <=> @stat)
  end

  test "compressed? basic functionality" do
    assert_respond_to(@stat, :compressed?)
    assert_boolean(@stat.compressed?)
  end

  test "compressed? returns expected value" do
    assert_false(@stat.compressed?)
  end

  test "dev basic functionality" do
    assert_respond_to(@stat, :dev)
    assert_kind_of([NilClass, String], @stat.dev)
  end

  test "dev returns expected value on non-unc path" do
    assert_equal('C:', File::Stat.new("C:\\Program Files").dev.upcase)
  end

  # Not sure how to test properly in a generic way, but works on my local network
  test "dev returns expected value on unc path" do
    omit_unless(Etc.getlogin == "djberge")
    assert_nil(File::Stat.new("//scipio/users").dev)
  end

  test "dev_major defined and always returns nil" do
    assert_respond_to(@stat, :dev_major)
    assert_nil(@stat.dev_major)
  end

  test "dev_minor defined and always returns nil" do
    assert_respond_to(@stat, :dev_minor)
    assert_nil(@stat.dev_minor)
  end

  test "directory? custom method basic functionality" do
    assert_respond_to(@stat, :directory?)
    assert_boolean(@stat.directory?)
  end

  test "directory? custom method returns expected value" do
    assert_false(@stat.directory?)
    assert_true(File::Stat.new("C:\\").directory?)
  end

  test "executable? custom method basic functionality" do
    assert_respond_to(@stat, :executable?)
    assert_boolean(@stat.executable?)
  end

  test "executable? custom method returns expected value" do
    assert_false(@stat.executable?)
    assert_true(File::Stat.new(@@exe_file).executable?)
  end

  test "executable_real? is an alias for executable?" do
    assert_respond_to(@stat, :executable_real?)
    assert_alias_method(@stat, :executable?, :executable_real?)
  end

  test "file? custom method basic functionality" do
    assert_respond_to(@stat, :file?)
    assert_boolean(@stat.file?)
  end

  test "file? custom method returns expected value" do
    assert_true(@stat.file?)
    assert_true(File::Stat.new(@@exe_file).file?)
    assert_true(File::Stat.new(Dir.pwd).file?)
    assert_false(File::Stat.new('NUL').file?)
  end

  test "ftype custom method basic functionality" do
    assert_respond_to(@stat, :ftype)
    assert_kind_of(String, @stat.ftype)
  end

  test "ftype custom method returns expected value" do
    assert_equal('file', @stat.ftype)
    assert_equal('characterSpecial', File::Stat.new('NUL').ftype)
    assert_equal('directory', File::Stat.new(Dir.pwd).ftype)
  end

  test "encrypted? basic functionality" do
    assert_respond_to(@stat, :encrypted?)
    assert_boolean(@stat.encrypted?)
  end

  test "encrypted? returns the expected value" do
    assert_false(@stat.encrypted?)
  end

  test "gid defined and always returns zero" do
    assert_respond_to(@stat, :gid)
    assert_equal(0, @stat.gid)
  end

  test "grpowned? defined and always returns true" do
    assert_respond_to(@stat, :grpowned?)
  end

  test "hidden? basic functionality" do
    assert_respond_to(@stat, :hidden?)
    assert_boolean(@stat.hidden?)
  end

  test "hidden? returns expected value" do
    assert_false(@stat.hidden?)
  end

  test "indexed? basic functionality" do
    assert_respond_to(@stat, :indexed?)
    assert_boolean(@stat.indexed?)
  end

  test "indexed? returns expected value" do
    assert_true(@stat.indexed?)
  end

  test "content_indexed? is an alias for indexed?" do
    assert_respond_to(@stat, :content_indexed?)
    assert_alias_method(@stat, :indexed?, :content_indexed?)
  end

  test "ino method basic functionality" do
    assert_respond_to(@stat, :ino)
    assert_kind_of(Fixnum, @stat.ino)
  end

  test "ino method defined and always returns zero" do
    assert_equal(0, @stat.ino)
  end

  test "inspect custom method basic functionality" do
    assert_respond_to(@stat, :inspect)
  end

  test "inspect string contains expected values" do
    assert_match('File::Stat', @stat.inspect)
    assert_match('compressed', @stat.inspect)
    assert_match('normal', @stat.inspect)
  end

  test "mode custom method basic functionality" do
    assert_respond_to(@stat, :mode)
    assert_kind_of(Fixnum, @stat.mode)
  end

  test "mode custom method returns the expected value" do
    assert_equal(33188, File::Stat.new(@@txt_file).mode)
    assert_equal(33261, File::Stat.new(@@exe_file).mode)
    assert_equal(16877, File::Stat.new(@dir).mode)
  end

  test "mode custom method returns expected value for readonly file" do
    SetFileAttributes(@@txt_file, 1) # Set to readonly.
    assert_equal(33060, File::Stat.new(@@txt_file).mode)
  end

  test "nlink basic functionality" do
    assert_respond_to(@stat, :nlink)
    assert_kind_of(Fixnum, @stat.nlink)
  end

  test "nlink returns the expected value" do
    assert_equal(1, @stat.nlink)
    assert_equal(1, File::Stat.new(Dir.pwd).nlink)
    assert_equal(1, File::Stat.new('NUL').nlink)
  end

  test "normal? basic functionality" do
    assert_respond_to(@stat, :normal?)
    assert_boolean(@stat.normal?)
  end

  test "normal? returns expected value" do
    assert_false(@stat.normal?)
  end

  test "offline? method basic functionality" do
    assert_respond_to(@stat, :offline?)
    assert_boolean(@stat.offline?)
  end

  test "offline? method returns expected value" do
    assert_false(@stat.offline?)
  end

  test "pipe? custom method basic functionality" do
    assert_respond_to(@stat, :pipe?)
    assert_boolean(@stat.pipe?)
  end

  test "pipe? custom method returns expected value" do
    assert_false(@stat.pipe?)
  end

  test "socket? is an alias for pipe?" do
    assert_respond_to(@stat, :socket?)
    assert_alias_method(@stat, :socket?, :pipe?)
  end

  test "readable? basic functionality" do
    assert_respond_to(@stat, :readable?)
    assert_boolean(@stat.readable?)
  end

  test "readable? returns expected value" do
    assert_true(@stat.readable?)
  end

  test "readable_real? basic functionality" do
    assert_respond_to(@stat, :readable_real?)
    assert_boolean(@stat.readable_real?)
  end

  test "readable_real? returns expected value" do
    assert_true(@stat.readable_real?)
  end

  test "readonly? basic functionality" do
    assert_respond_to(@stat, :readonly?)
    assert_boolean(@stat.readonly?)
  end

  test "readonly? returns the expected value" do
    assert_false(@stat.readonly?)
    SetFileAttributes(@@txt_file, 1)
    assert_true(File::Stat.new(@@txt_file).readonly?)
  end

  test "read_only? is an alias for readonly?" do
    assert_respond_to(@stat, :read_only?)
    assert_alias_method(@stat, :readonly?, :read_only?)
  end

  test "reparse_point? basic functionality" do
    assert_respond_to(@stat, :reparse_point?)
    assert_boolean(@stat.reparse_point?)
  end

  test "reparse_point returns expected value" do
    assert_false(@stat.reparse_point?)
  end

  test "rdev custom method basic functionality" do
    assert_respond_to(@stat, :rdev)
    assert_kind_of(Fixnum, @stat.rdev)
  end

  test "rdev custom method returns expected value" do
    assert_equal(2, File::Stat.new("C:\\").rdev)
    assert_equal(-1, File::Stat.new("NUL").rdev)
  end

  test "setgid is set to false" do
    assert_respond_to(@stat, :setgid?)
    assert_false(@stat.setgid?)
  end

  test "setuid is set to false" do
    assert_respond_to(@stat, :setuid?)
    assert_false(@stat.setuid?)
  end

  test "size custom method basic functionality" do
    assert_respond_to(@stat, :size)
    assert_kind_of(Numeric, @stat.size)
  end

  test "size custom method returns expected value" do
    assert_equal(21, @stat.size)
    @stat = File::Stat.new(@temp)
    assert_equal(0, @stat.size)
  end

  test "size custom method works on system files" do
    omit_if(windows_64?, 'skipping system file test on 64-bit OS')
    assert_nothing_raised{ File::Stat.new(@@sys_file).size }
  end

  test "size? method basic functionality" do
    assert_respond_to(@stat, :size?)
    assert_kind_of(Numeric, @stat.size)
  end

  test "size? method returns integer if size greater than zero" do
    assert_equal(21, @stat.size?)
  end

  test "size? method returns nil if size is zero" do
    @stat = File::Stat.new(@temp)
    assert_nil(@stat.size?)
  end

  test "sparse? basic fucntionality" do
    assert_respond_to(@stat, :sparse?)
    assert_boolean(@stat.sparse?)
  end

  test "sparse? returns expected value" do
    assert_false(@stat.sparse?)
  end

  test "sticky is always set to false" do
    assert_respond_to(@stat, :sticky?)
    assert_false(@stat.sticky?)
  end

=begin
   def test_symlink
      assert_respond_to(@stat, :symlink?)
      assert_equal(false, @stat.symlink?)
   end
=end

  test "system? basic functionality" do
    assert_respond_to(@stat, :system?)
    assert_boolean(@stat.system?)
  end

  test "system? returns expected value" do
    assert_false(@stat.system?)
  end

  test "temporary? basic functionality" do
    assert_respond_to(@stat, :temporary?)
    assert_boolean(@stat.temporary?)
  end

  test "temporary? returns expected value" do
    assert_false(@stat.temporary?)
  end

  test "uid is always set to zero" do
    assert_respond_to(@stat, :uid)
    assert_equal(0, @stat.uid)
  end

  test "writable? basic functionality" do
    assert_respond_to(@stat, :writable?)
    assert_boolean(@stat.writable?)
  end

  test "writable? returns expected value" do
    assert_true(@stat.writable?)
  end

  test "writable_real? basic functionality" do
    assert_respond_to(@stat, :writable_real?)
    assert_boolean(@stat.writable_real?)
  end

  test "writable_real? returns expected value" do
    assert_true(@stat.writable_real?)
  end

  test "zero? method basic functionality" do
    assert_respond_to(@stat, :zero?)
    assert_boolean(@stat.zero?)
  end

  test "zero? method returns expected value" do
    assert_false(@stat.zero?)
    @stat = File::Stat.new(@temp)
    assert_true(@stat.zero?)
  end

  def teardown
    SetFileAttributes(@@txt_file, @attr) # Set file back to normal
    File.delete(@temp) if File.exists?(@temp)
    @dir  = nil
    @stat = nil
    @attr = nil
    @temp = nil
  end

  def self.shutdown
    File.delete(@@txt_file) if File.exists?(@@txt_file)
    File.delete(@@exe_file) if File.exists?(@@exe_file)

    @@block_dev = nil
    @@txt_file  = nil
    @@exe_file  = nil
    @@sys_file  = nil
  end
end
