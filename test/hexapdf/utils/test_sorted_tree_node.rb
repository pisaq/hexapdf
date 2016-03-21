# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/name_tree_node'
require 'hexapdf/number_tree_node'

describe HexaPDF::Utils::SortedTreeNode do
  before do
    @doc = HexaPDF::Document.new
    @root = HexaPDF::NameTreeNode.new({}, document: @doc)
  end

  def add_multilevel_entries
    @kid11 = HexaPDF::NameTreeNode.new({Limits: ['c', 'f'], Names: ['c', 1, 'f', 1]},
                                       document: @doc)
    @kid12 = HexaPDF::NameTreeNode.new({Limits: ['i', 'm'], Names: ['i', 1, 'm', 1]},
                                       document: @doc)
    @kid1 = HexaPDF::NameTreeNode.new({Limits: ['c', 'm'], Kids: [@kid11, @kid12]},
                                      document: @doc)
    @kid21 = HexaPDF::NameTreeNode.new({Limits: ['o', 'q'], Names: ['o', 1, 'q', 1]},
                                       document: @doc)
    @kid221 = HexaPDF::NameTreeNode.new({Limits: ['s', 'u'], Names: ['s', 1, 'u', 1]},
                                        document: @doc)
    @kid22 = HexaPDF::NameTreeNode.new({Limits: ['s', 'u'], Kids: [@kid221]},
                                       document: @doc)
    @kid2 = HexaPDF::NameTreeNode.new({Limits: ['o', 'u'], Kids: [@kid21, @kid22]},
                                      document: @doc)
    @root[:Kids] = [@kid1, @kid2]
  end

  describe "add" do
    it "works with the root node alone" do
      @root.add_name('c', 1)
      @root.add_name('a', 2)
      @root.add_name('e', 3)
      assert_equal(['a', 2, 'c', 1, 'e', 3], @root[:Names])
      refute(@root[:Limits])
    end

    it "replaces an existing entry if overwrite is true" do
      assert(@root.add_name('a', 2))
      assert(@root.add_name('a', 5))
      assert_equal(['a', 5], @root[:Names])
    end

    it "doesn't replace an existing entry if overwrite is false" do
      assert(@root.add_name('a', 2))
      refute(@root.add_name('a', 5, overwrite: false))
      assert_equal(['a', 2], @root[:Names])
    end

    it "works with one level of intermediate nodes" do
      kid1 = HexaPDF::NameTreeNode.new({Limits: ['m', 'm'], Names: ['m', 1]}, document: @doc)
      kid2 = HexaPDF::NameTreeNode.new({Limits: ['t', 't'], Names: ['t', 1]}, document: @doc)
      @root[:Kids] = [kid1, kid2]
      @root.add_name('c', 1)
      @root.add_name('d', 1)
      @root.add_name('p', 1)
      @root.add_name('r', 1)
      @root.add_name('u', 1)
      assert_equal(['c', 'm'], kid1[:Limits])
      assert_equal(['c', 1, 'd', 1, 'm', 1], kid1[:Names])
      assert_equal(['p', 'u'], kid2[:Limits])
      assert_equal(['p', 1, 'r', 1, 't', 1, 'u', 1], kid2[:Names])
    end

    it "works with multiple levels of intermediate nodes" do
      add_multilevel_entries
      @root.add_name('a', 1)
      @root.add_name('e', 1)
      @root.add_name('g', 1)
      @root.add_name('j', 1)
      @root.add_name('n', 1)
      @root.add_name('p', 1)
      @root.add_name('r', 1)
      @root.add_name('v', 1)
      assert_equal(['a', 'm'], @kid1[:Limits])
      assert_equal(['a', 'f'], @kid11[:Limits])
      assert_equal(['a', 1, 'c', 1, 'e', 1, 'f', 1], @kid11[:Names])
      assert_equal(['g', 'm'], @kid12[:Limits])
      assert_equal(['g', 1, 'i', 1, 'j', 1, 'm', 1], @kid12[:Names])
      assert_equal(['n', 'v'], @kid2[:Limits])
      assert_equal(['n', 'q'], @kid21[:Limits])
      assert_equal(['n', 1, 'o', 1, 'p', 1, 'q', 1], @kid21[:Names])
      assert_equal(['r', 'v'], @kid22[:Limits])
      assert_equal(['r', 'v'], @kid221[:Limits])
      assert_equal(['r', 1, 's', 1, 'u', 1, 'v', 1], @kid221[:Names])
    end

    it "splits nodes if needed" do
      @doc.config['sorted_tree.max_leaf_node_size'] = 4
      %w[a c e m k i g d b l j f h].each {|key| @root.add_name(key, 1)}
      refute(@root.value.key?(:Limits))
      refute(@root.value.key?(:Names))
      assert_equal(6, @root[:Kids].size)
      assert_equal(['a', 1, 'b', 1], @root[:Kids][0][:Names])
      assert_equal(['c', 1, 'd', 1], @root[:Kids][1][:Names])
      assert_equal(['e', 1, 'f', 1], @root[:Kids][2][:Names])
      assert_equal(['g', 1, 'h', 1, 'i', 1], @root[:Kids][3][:Names])
      assert_equal(['j', 1, 'k', 1], @root[:Kids][4][:Names])
      assert_equal(['l', 1, 'm', 1], @root[:Kids][5][:Names])
    end

    it "fails if not called on the root node" do
      @root[:Limits] = ['a', 'c']
      assert_raises(HexaPDF::Error) { @root.add_name('b', 1) }
    end

    it "fails if the key is not a string" do
      assert_raises(HexaPDF::Error) { @root.add_name(5, 1) }
    end
  end

  describe "find" do
    it "finds the correct entry" do
      add_multilevel_entries
      assert_equal(1, @root.find_name('i'))
      assert_equal(1, @root.find_name('q'))
    end

    it "returns nil for non-existing entries" do
      add_multilevel_entries
      assert_nil(@root.find_name('non'))
    end

    it "works when no entry exists" do
      assert_nil(@root.find_name('non'))
    end
  end

  describe "delete" do
    it "works with only the root node" do
      %w[a b c d e f g].each {|name| @root.add_name(name, 1)}
      %w[g b a unknown e d c].each {|name| @root.delete_name(name)}
      refute(@root.value.key?(:Kids))
      refute(@root.value.key?(:Limits))
      assert_equal(['f', 1], @root[:Names])
      assert_equal(1, @root.delete_name('f'))
    end

    it "works with multiple levels of intermediate nodes" do
      add_multilevel_entries
      %w[c f i m unknown o q s u].each {|name| @root.delete_name(name)}
      refute(@root.value.key?(:Names))
      refute(@root.value.key?(:Limits))
      assert(@root[:Kids].empty?)
    end

    it "works on an uninitalized tree" do
      assert_nil(@root.delete_name('non'))
    end

    it "fails if not called on the root node" do
      @root[:Limits] = ['a', 'c']
      assert_raises(HexaPDF::Error) { @root.delete_name('b') }
    end
  end

  describe "each" do
    it "enumerates in the key-value pairs in sorted order" do
      add_multilevel_entries
      assert_equal(['c', 1, 'f', 1, 'i', 1, 'm', 1, 'o', 1, 'q', 1, 's', 1, 'u', 1],
                   @root.each_tree_entry.to_a.flatten)
    end

    it "works on an uninitalized tree" do
      assert_equal([], @root.each_tree_entry.to_a)
    end
  end

  it "works equally well with a NumberTreeNode" do
    root = HexaPDF::NumberTreeNode.new({}, document: @doc)
    root.add_number(2, 1)
    root.add_number(1, 2)
    assert_equal([1, 2, 2, 1], root[:Nums])
  end
end