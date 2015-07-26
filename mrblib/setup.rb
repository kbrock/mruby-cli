module MRubyCLI
  class Setup
    def initialize(name, output)
      @name   = name
      @output = output
    end

    def run
      Dir.mkdir(@name) unless Dir.exist?(@name)
      Dir.chdir(@name) do
        write_file("mrbgem.rake", mrbgem_rake)
        write_file("build_config.rb", build_config_rb)
        write_file("Rakefile", rakefile)
        write_file("Dockerfile", dockerfile)
        write_file("docker-compose.yml", docker_compose_yml)

        create_dir_p("tools/#{@name}")
        write_file("tools/#{@name}/#{@name}.c", tools)

        create_dir("mrblib")
        write_file("mrblib/#{@name}.rb", mrblib)

        create_dir("bintest")
        write_file("bintest/#{@name}.rb", bintest)

        create_dir("test")
        write_file("test/test_#{@name}.rb", test)
      end
    end

    private
    def create_dir_p(dir)
      dir.split("/").inject("") do |parent, base|
        new_dir =
          if parent == ""
            base
          else
            "#{parent}/#{base}"
          end

        create_dir(new_dir)

        new_dir
      end
    end

    def create_dir(dir)
      if Dir.exist?(dir)
        @output.puts "  skip    #{dir}"
      else
        @output.puts "  create  #{dir}/"
        Dir.mkdir(dir)
      end
    end

    def write_file(file, contents)
      @output.puts "  create  #{file}"
      File.open(file, 'w') {|file| file.puts contents }
    end

    def test
      <<TEST
class Test#{Util.camelize(@name)} < MTest::Unit::TestCase
  def test_main
    assert_nil __main__
  end
end

MTest::Unit.new.run
TEST
    end

    def bintest
      <<BINTEST
require 'open3'
require 'tmpdir'

BIN_PATH = File.join(File.dirname(__FILE__), "../mruby/bin/#{@name}")

assert('setup') do
  Dir.mktmpdir do |tmp_dir|
    Dir.chdir(tmp_dir) do
      output, status = Open3.capture2("\#{BIN_PATH}")

      assert_true status.success?, "Process did not exit cleanly"
      assert_include output, "Hello World"
    end
  end
end
BINTEST
    end

    def mrbgem_rake
      <<MRBGEM_RAKE
MRuby::Gem::Specification.new('#{@name}') do |spec|
  spec.license = 'MIT'
  spec.author  = 'MRuby Developer'
  spec.summary = '#{@name}'
  spec.bins    = ['#{@name}']

  spec.add_dependency 'mruby-print', :core => 'mruby-print'
  spec.add_dependency 'mruby-mtest', :mgem => 'mruby-mtest'
end
MRBGEM_RAKE
    end

    def build_config_rb
      <<BUILD_CONFIG_RB
def gem_config(conf)
  #conf.gembox 'default'

  # be sure to include this gem (the cli app)
  conf.gem File.expand_path(File.dirname(__FILE__))
end

MRuby::Build.new do |conf|
  toolchain :clang

  conf.enable_bintest

  gem_config(conf)
end

MRuby::CrossBuild.new('i686-pc-linux-gnu') do |conf|
  toolchain :gcc

  [conf.cc, conf.cxx, conf.linker].each do |cc|
    cc.flags << "-m32"
  end

  conf.build_mrbtest_lib_only

  gem_config(conf)
end

MRuby::CrossBuild.new('x86_64-apple-darwin14') do |conf|
  toolchain :clang

  [conf.cc, conf.linker].each do |cc|
    cc.command = 'x86_64-apple-darwin14-clang'
  end
  conf.cxx.command      = 'x86_64-apple-darwin14-clang++'
  conf.archiver.command = 'x86_64-apple-darwin14-ar'

  conf.build_target     = 'x86_64-pc-linux-gnu'
  conf.host_target      = 'x86_64-apple-darwin14'

  conf.build_mrbtest_lib_only

  gem_config(conf)
end

MRuby::CrossBuild.new('i386-apple-darwin14') do |conf|
  toolchain :clang

  [conf.cc, conf.linker].each do |cc|
    cc.command = 'i386-apple-darwin14-clang'
  end
  conf.cxx.command      = 'i386-apple-darwin14-clang++'
  conf.archiver.command = 'i386-apple-darwin14-ar'

  conf.build_target     = 'i386-pc-linux-gnu'
  conf.host_target      = 'i386-apple-darwin14'

  conf.build_mrbtest_lib_only

  gem_config(conf)
end

MRuby::CrossBuild.new('x86_64-w64-mingw32') do |conf|
  toolchain :gcc

  [conf.cc, conf.linker].each do |cc|
    cc.command = 'x86_64-w64-mingw32-gcc'
  end
  conf.cxx.command      = 'x86_64-w64-mingw32-cpp'
  conf.archiver.command = 'x86_64-w64-mingw32-gcc-ar'
  conf.exts.executable  = ".exe"

  conf.build_target     = 'x86_64-pc-linux-gnu'
  conf.host_target      = 'x86_64-w64-mingw32'

  conf.build_mrbtest_lib_only

  gem_config(conf)
end

MRuby::CrossBuild.new('i686-w64-mingw32') do |conf|
  toolchain :gcc

  [conf.cc, conf.linker].each do |cc|
    cc.command = 'i686-w64-mingw32-gcc'
  end
  conf.cxx.command      = 'i686-w64-mingw32-cpp'
  conf.archiver.command = 'i686-w64-mingw32-gcc-ar'
  conf.exts.executable  = ".exe"

  conf.build_target     = 'i686-pc-linux-gnu'
  conf.host_target      = 'i686-w64-mingw32'

  conf.build_mrbtest_lib_only

  gem_config(conf)
end
BUILD_CONFIG_RB
    end

    def tools
      <<TOOLS
#include <stdlib.h>
#include <stdio.h>

/* Include the mruby header */
#include <mruby.h>
#include <mruby/array.h>

int main(int argc, char *argv[])
{
  mrb_state *mrb = mrb_open();
  mrb_value ARGV = mrb_ary_new_capa(mrb, argc);
  int i;
  int return_value;

  for (i = 0; i < argc; i++) {
    mrb_ary_push(mrb, ARGV, mrb_str_new_cstr(mrb, argv[i]));
  }
  mrb_define_global_const(mrb, "ARGV", ARGV);

  // call __main__(ARGV)
  mrb_funcall(mrb, mrb_top_self(mrb), "__main__", 1, ARGV);

  return_value = EXIT_SUCCESS;

  if (mrb->exc) {
    mrb_print_error(mrb);
    return_value = EXIT_FAILURE;
  }
  mrb_close(mrb);

  return return_value;
}
TOOLS
    end

    def mrblib
      <<TOOLS
def __main__(argv)
  puts "Hello World"
end
TOOLS
    end

    def dockerfile
      <<DOCKERFILE
FROM hone/mruby-cli
DOCKERFILE
    end

    def docker_compose_yml
      <<DOCKER_COMPOSE_YML
compile: &defaults
  build: .
  volumes:
    - .:/home/mruby/code:rw
  command: rake compile
test:
  <<: *defaults
  command: rake test
bintest:
  <<: *defaults
  command: rake test:bintest
mtest:
  <<: *defaults
  command: rake test:mtest
clean:
  <<: *defaults
  command: rake clean
shell:
  <<: *defaults
  command: bash
DOCKER_COMPOSE_YML
    end

    def rakefile
      <<RAKEFILE
file :mruby do
  sh "git clone --depth=1 https://github.com/mruby/mruby"
end

APP_NAME=ENV["APP_NAME"] || "#{@name}"
APP_ROOT=ENV["APP_ROOT"] || Dir.pwd
# avoid redefining constants in mruby Rakefile
mruby_root=File.expand_path(ENV["MRUBY_ROOT"] || "\#{APP_ROOT}/mruby")
mruby_config=File.expand_path(ENV["MRUBY_CONFIG"] || "build_config.rb")
ENV['MRUBY_ROOT'] = mruby_root
ENV['MRUBY_CONFIG'] = mruby_config
Rake::Task[:mruby].invoke unless Dir.exist?(mruby_root)
Dir.chdir(mruby_root)
load "\#{mruby_root}/Rakefile"

desc "compile binary"
task :compile => [:mruby, :all] do
  %W(\#{MRUBY_ROOT}/build/host/bin/\#{APP_NAME} \#{MRUBY_ROOT}/build/i686-pc-linux-gnu/\#{APP_NAME}").each do |bin|
    sh "strip --strip-unneeded \#{bin}" if File.exist?(bin)
  end
end

namespace :test do
  desc "run mruby & unit tests"
  # only build mtest for host
  task :mtest => [:compile] + MRuby.targets.values.map {|t| t.build_mrbtest_lib_only? ? nil : t.exefile("\#{t.build_dir}/test/mrbtest") }.compact do
    # mruby-io tests expect to be in MRUBY_ROOT
    Dir.chdir(MRUBY_ROOT) do
      # in order to get mruby/test/t/synatx.rb __FILE__ to pass,
      # we need to make sure the tests are built relative from MRUBY_ROOT
      load "\#{MRUBY_ROOT}/test/mrbtest.rake"
      MRuby.each_target do |target|
        # only run unit tests here
        target.enable_bintest = false
        run_test unless build_mrbtest_lib_only?
      end
    end
  end

  def clean_env(envs)
    old_env = {}
    envs.each do |key|
      old_env[key] = ENV[key]
      ENV[key] = nil
    end
    yield
    envs.each do |key|
      ENV[key] = old_env[key]
    end
  end

  desc "run integration tests"
  task :bintest => :compile do
    MRuby.each_target do |target|
      clean_env(%w(MRUBY_ROOT MRUBY_CONFIG)) do
        run_bintest if bintest_enabled?
      end
    end
  end
end

desc "run all tests"
Rake::Task['test'].clear
task :test => ["test:mtest", "test:bintest"]

desc "cleanup"
task :clean do
  sh "cd \#{MRUBY_ROOT} && rake deep_clean"
end
RAKEFILE
    end
  end
end
