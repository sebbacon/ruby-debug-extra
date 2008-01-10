#!/usr/bin/env ruby
require "test/unit"
require "fileutils"

# require "rubygems"
# require "ruby-debug"; Debugger.start

SRC_DIR = File.expand_path(File.dirname(__FILE__)) + "/" unless 
  defined?(SRC_DIR)

require File.join(SRC_DIR, "helper.rb")

include TestHelper

# Test --no-stop and $0 setting.
class TestDollar0 < Test::Unit::TestCase
  require 'stringio'

  def test_basic
    Dir.chdir(SRC_DIR) do 
      assert_equal(true, 
                   run_debugger("dollar-0", 
                                "-nx --no-stop ./dollar-0.rb",
                                nil, nil, false, File.join(SRC_DIR, '../bin/rdebug')))
    end
  end
end
