require "test/unit"
require "ocra"
require "tmpdir"
require "fileutils"
require "rbconfig"
include FileUtils

class TestOcra < Test::Unit::TestCase

  DefaultArgs = [ '--quiet', '--no-lzma' ]

  def initialize(*args)
    super(*args)
    @testnum = 0
    @ocra = File.expand_path(File.join(File.dirname(__FILE__), '../bin/ocra.rb'))
    ENV['RUBYOPT'] = ""
  end

  def ocra
    @ocra
  end

  FixturePath = File.expand_path(File.join(File.dirname(__FILE__), 'fixtures'))

  def copy_fixture(name)
    path = File.join(FixturePath, name)
    FileUtils.cp_r Dir.glob(File.join(path, '*')), '.'
  end
  
  def setup
    @testnum += 1
    @tempdirname = ".ocratest-#{$$}-#{@testnum}"
    Dir.mkdir @tempdirname
    Dir.chdir @tempdirname
  end

  def teardown
    Dir.chdir '..'
    FileUtils.rm_rf @tempdirname
  end
  
  def test_helloworld
    File.open("helloworld.rb", "w") do |f|
      f << "hello_world = \"Hello, World!\"\n"
    end
    assert system("ruby", ocra, "helloworld.rb", *DefaultArgs)
    assert File.exist?("helloworld.exe")
    assert system("helloworld.exe")
  end

  def test_writefile
    File.open("writefile.rb", "w") do |f|
      f << "File.open(\"output.txt\", \"w\") do |f| f.write \"output\"; end"
    end
    assert system("ruby", ocra, "writefile.rb", *DefaultArgs)
    assert File.exist?("writefile.exe")
    assert system("writefile.exe")
    assert File.exist?("output.txt")
    assert "output", File.read("output.txt")
  end

  def test_exitstatus
    File.open("exitstatus.rb", "w") do |f|
      f << "exit 167 if __FILE__ == $0"
    end
    assert system("ruby", ocra, "exitstatus.rb", *DefaultArgs)
    system("exitstatus.exe")
    assert_equal 167, $?.exitstatus
  end

  def test_arguments
    File.open("arguments.rb", "w") do |f|
      f << "if $0 == __FILE__\n"
      f << "exit 1 if ARGV.size != 2\n"
      f << "exit 2 if ARGV[0] != \"foo\"\n"
      f << "exit 3 if ARGV[1] != \"bar baz\"\n"
      # f << "exit 4 if ARGV[2] != \"\\\"smile\\\"\"\n"
      f << "exit(5)\n"
      f << "end"
    end
    assert system("ruby", ocra, "arguments.rb", *DefaultArgs)
    assert File.exist?("arguments.exe")
    # system(File.expand_path("arguments.exe"), "foo", "bar baz", "\"smile\"")
    system("arguments.exe foo \"bar baz\"")
    assert_equal 5, $?.exitstatus
  end

  def test_stdout_redir
    File.open("stdoutredir.rb", "w") do |f|
      f << "if $0 == __FILE__\n"
      f << "puts \"Hello, World!\"\n"
      f << "end\n"
    end
    assert system("ruby", ocra, "stdoutredir.rb", *DefaultArgs)
    assert File.exist?("stdoutredir.exe")
    system("stdoutredir.exe > output.txt")
    assert File.exist?("output.txt")
    assert_equal "Hello, World!\n", File.read("output.txt")
  end

  def test_stdin_redir
    File.open("input.txt", "w") do |f|
      f << "Hello, World!\n"
    end
    File.open("stdinredir.rb", "w") do |f|
      f << "if $0 == __FILE__\n"
      f << "  exit 104 if gets == \"Hello, World!\\n\""
      f << "end\n"
    end
    assert system("ruby", ocra, "stdinredir.rb", *DefaultArgs)
    assert File.exist?("stdinredir.exe")
    system("stdinredir.exe < input.txt")
    assert 104, $?.exitstatus
  end

  def test_gdbmdll
    File.open("gdbmdll.rb", "w") do |f|
      f << "require 'gdbm'\n"
      f << "exit 104 if $0 == __FILE__ and defined?(GDBM)\n"
    end
    bindir = RbConfig::CONFIG['bindir']
    
    gdbmdllpath = Dir[File.join(bindir, 'gdbm*.dll')][0]
    raise "gdbm dll was not found" unless gdbmdllpath
    gdbmdll = File.basename(gdbmdllpath)
    assert system("ruby", ocra, "--dll", gdbmdll, "gdbmdll.rb", *DefaultArgs)
    path = ENV['PATH']
    ENV['PATH'] = "."
    begin
      system("gdbmdll.exe")
    ensure
      ENV['PATH'] = path
    end
    assert_equal 104, $?.exitstatus
  end

  def test_relative_require
    File.open("relativerequire.rb", "w") do |f|
      f << "require 'somedir/somefile.rb'\n"
      f << "exit 160 if __FILE__ == $0 and defined?(SomeConst)"
    end
    Dir.mkdir('somedir')
    File.open("somedir/somefile.rb", "w") do |f|
      f << "SomeConst = 12312\n"
    end
    assert system("ruby", ocra, "relativerequire.rb", *DefaultArgs)
    assert File.exist?("relativerequire.exe")
    system("relativerequire.exe")
    assert_equal 160, $?.exitstatus
  end

  def test_exiting
    File.open("exiting.rb", "w") do |f|
      f << "exit 214\n"
    end
    assert system("ruby", ocra, "exiting.rb", *DefaultArgs)
    assert File.exist?("exiting.exe")
    system("exiting.exe")
    assert_equal 214, $?.exitstatus
  end

  def test_autoload
    File.open("autoload.rb", "w") do |f|
      f << "$:.unshift File.dirname(__FILE__)\n"
      f << "autoload :Foo, 'foo'\n"
      f << "Foo if __FILE__ == $0\n"
    end
    File.open("foo.rb", "w") do |f|
      f << "class Foo; end\n"
    end
    assert system("ruby", ocra, "autoload.rb", *DefaultArgs)
    assert File.exist?("autoload.exe")
    File.unlink('foo.rb')
    assert system("autoload.exe")
    # assert_equal 214, $?.exitstatus
  end

  def test_autoload_missing
    File.open("autoloadmissing.rb", "w") do |f|
      f << "$:.unshift File.dirname(__FILE__)\n"
      f << "autoload :Foo, 'foo'\n"
    end
    assert system("ruby", ocra, "autoloadmissing.rb", *DefaultArgs)
    assert File.exist?("autoloadmissing.exe")
    assert system("autoloadmissing.exe")
  end
  
  def test_autoload_nested
    File.open("autoloadnested.rb", "w") do |f|
      f << "$:.unshift File.dirname(__FILE__)\n"
      f << "module Bar\n"
      f << "  autoload :Foo, 'foo'\n"
      f << "end\n"
      f << "Bar::Foo if __FILE__ == $0\n"
    end
    File.open("foo.rb", "w") do |f|
      f << "module Bar\n"
      f << "class Foo; end\n"
      f << "end\n"
    end
    assert system("ruby", ocra, "autoloadnested.rb", *DefaultArgs)
    assert File.exist?("autoloadnested.exe")
    File.unlink('foo.rb')
    assert system("autoloadnested.exe")
    # assert_equal 214, $?.exitstatus
  end

  # Test that we can use custom include paths when invoking Ocra (ruby
  # -I somepath). In this case the lib scripts are put in the src/
  # directory.
  def test_relative_loadpath1_ilib
    copy_fixture 'relloadpath1'
    assert system('ruby', '-I', 'lib', ocra, 'relloadpath1.rb', *DefaultArgs)
    assert File.exist?('relloadpath1.exe')
    assert system('relloadpath1.exe')
  end
  def test_relative_loadpath_idotlib
    copy_fixture 'relloadpath1'
    assert system('ruby', '-I', './lib', ocra, 'relloadpath1.rb', *DefaultArgs)
    assert File.exist?('relloadpath1.exe')
    assert system('relloadpath1.exe')
  end

  # Test that we can use custom include paths when invoking Ocra (env
  # RUBYLIB=lib). In this case the lib scripts are put in the src/
  # directory.
  def test_relative_loadpath_rubyliblib
    copy_fixture 'relloadpath1'
    rubylib = ENV['RUBYLIB']
    begin
      ENV['RUBYLIB'] = 'lib'
      assert system('ruby', ocra, 'relloadpath1.rb', *DefaultArgs)
      assert File.exist?('relloadpath1.exe')
      assert system('relloadpath1.exe')
    ensure
      ENV['RUBYLIB'] = rubylib
    end
  end
  def test_relative_loadpath_rubylibdotlib
    copy_fixture 'relloadpath1'
    rubylib = ENV['RUBYLIB']
    begin
      ENV['RUBYLIB'] = './lib'
      assert system('ruby', ocra, 'relloadpath1.rb', *DefaultArgs)
      assert File.exist?('relloadpath1.exe')
      assert system('relloadpath1.exe')
    ensure
      ENV['RUBYLIB'] = rubylib
    end
  end

  def test_relative_loadpath2_idotdotlib
    copy_fixture 'relloadpath2'
    cd 'src' do
      assert system('ruby', '-I', '../lib', ocra, 'relloadpath2.rb', *DefaultArgs)
      assert File.exist?('relloadpath2.exe')
      assert system('relloadpath2.exe')
    end
  end

  # Test that scripts which modify $LOAD_PATH with a relative path
  # (./lib) work correctly.
  def test_relloadpath3
    copy_fixture 'relloadpath3'
    assert system('ruby', ocra, 'relloadpath3.rb', *DefaultArgs)
    assert File.exist?('relloadpath3.exe')
    assert system('relloadpath3.exe')
  end

  # Test that scripts which modify $LOAD_PATH with a relative path
  # (../lib) work correctly.
  def test_relloadpath4
    copy_fixture 'relloadpath4'
    cd 'src' do
      assert system('ruby', ocra, 'relloadpath4.rb', *DefaultArgs)
      assert File.exist?('relloadpath4.exe')
      assert system('relloadpath4.exe')
    end
  end
  
end
