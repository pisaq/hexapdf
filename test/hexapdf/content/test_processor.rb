# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/content/processor'
require 'hexapdf/document'

describe HexaPDF::Content::Processor::GlyphBox do
  before do
    @box = HexaPDF::Content::Processor::GlyphBox.new(5, "5", 1, 2, 3, 4, 5, 6)
  end

  it "returns the correct bounding box coordinates" do
    assert_equal([1, 2], @box.lower_left)
    assert_equal([3, 4], @box.lower_right)
    assert_equal([5, 6], @box.upper_left)
    assert_equal([7, 8], @box.upper_right)
  end

  it "returns all box corners in one array when using #points" do
    assert_equal([1, 2, 3, 4, 7, 8, 5, 6], @box.points)
  end
end

describe HexaPDF::Content::Processor::CompositeBox do
  before do
    @glyph_box1 = HexaPDF::Content::Processor::GlyphBox.new(4, "4", 1, 1, 2, 1, 1, 2)
    @glyph_box2 = HexaPDF::Content::Processor::GlyphBox.new(2, "2", 3, 1, 7, 1, 3, 2)
    @boxes = HexaPDF::Content::Processor::CompositeBox.new
  end

  it "allows appending and retrieving of glyph boxes" do
    result = (@boxes << @glyph_box1)
    assert_equal(@boxes, result)
    assert_equal(@glyph_box1, @boxes[0])
  end

  it "allows iterating over the glyph boxes " do
    @boxes << @glyph_box1 << @glyph_box2
    assert_equal([@glyph_box1, @glyph_box2], @boxes.each.to_a)
  end

  it "returns the concatenated string of the individual boxes" do
    @boxes << @glyph_box1 << @glyph_box2
    assert_equal("42", @boxes.string)
  end

  it "returns the correct bounding box coordinates" do
    @boxes << @glyph_box1 << @glyph_box2
    assert_equal([1, 1], @boxes.lower_left)
    assert_equal([7, 1], @boxes.lower_right)
    assert_equal([1, 2], @boxes.upper_left)
    assert_equal([7, 2], @boxes.upper_right)
  end
end

describe HexaPDF::Content::Processor do
  before do
    @processor = HexaPDF::Content::Processor.new
  end

  describe "initialization" do
    it "has a prepopulated operators mapping" do
      assert_kind_of(HexaPDF::Content::Operator::BaseOperator, @processor.operators[:q])
    end
  end

  describe "graphics_object" do
    it "default to :none on initialization" do
      assert_equal(:none, @processor.graphics_object)
    end
  end

  describe "process" do
    it "invokes the specified operator implementation" do
      op = Minitest::Mock.new
      op.expect(:invoke, nil, [@processor, :arg])
      @processor.operators[:test] = op
      @processor.process(:test, [:arg])
      op.verify
    end

    it "invokes the mapped message name" do
      val = nil
      @processor.define_singleton_method(:save_graphics_state) { val = :arg }
      @processor.process(:q)
      assert_equal(:arg, val)
    end
  end

  describe "paint_xobject" do
    it "processes the contents of a Form xobject" do
      test_case = self
      invoked = false

      @processor.define_singleton_method(:set_line_width) do |_width|
        test_case.assert_equal([2, 0, 0, 2, 10, 10], graphics_state.ctm.to_a)
        invoked = true
      end
      @processor.resources = resources = Object.new
      @processor.resources.define_singleton_method(:xobject) do |_name|
        obj = {Matrix: [2, 0, 0, 2, 10, 10], Subtype: :Form}
        obj.define_singleton_method(:process_contents) {|processor| processor.process(:w, [10])}
        obj
      end

      @processor.process(:Do, [:Name])
      assert(invoked)
      assert_equal([1, 0, 0, 1, 0, 0], @processor.graphics_state.ctm.to_a)
      assert_same(resources, @processor.resources)
    end
  end

  describe "text decoding" do
    before do
      @doc =  HexaPDF::Document.new
      @processor.process(:BT)
      @processor.graphics_state.font = @font = @doc.add(Type: :Font, Subtype: :Type1,
                                                        Encoding: :WinAnsiEncoding,
                                                        BaseFont: :"Times-Roman")
      @processor.graphics_state.font_size = 10
      @processor.graphics_state.text_rise = 10
    end

    describe "decode_text" do
      it "decodes text provided via one or the other of the two show show text operators" do
        assert_equal("Hülle", @processor.send(:decode_text, "Hülle".encode("Windows-1252")))
        arr = ["Hül".encode("Windows-1252"), 20, "le".encode("Windows-1252")]
        assert_equal("Hülle", @processor.send(:decode_text, arr))
      end
    end

    describe "decode_text_with_positioning" do
      it "returns a composite box with positioning information" do
        lly = @font.bounding_box[1] / 1000.0 * @processor.graphics_state.font_size +
          @processor.graphics_state.text_rise
        lry = @font.bounding_box[3] / 1000.0 * @processor.graphics_state.font_size +
          @processor.graphics_state.text_rise
        arr = ["Hül".encode("Windows-1252"), 20, "le".encode("Windows-1252")]
        width = "Hülle".encode("Windows-1252").codepoints.inject(0) {|s, cp| s + @font.width(cp)}
        width = (width - 20) * @processor.graphics_state.font_size / 1000.0

        box = @processor.send(:decode_text_with_positioning, arr)
        assert_equal("Hülle", box.string)
        assert_in_delta(0, box[0].lower_left[0])
        assert_in_delta(lly, box[0].lower_left[1])
        assert_in_delta(width, box[4].upper_right[0])
        assert_in_delta(lry, box[4].upper_right[1])
      end

      it "fails if the current font is a vertical font" do
        @processor.graphics_state.font.define_singleton_method(:writing_mode) { :vertical }
        assert_raises(NotImplementedError) { @processor.send(:decode_text_with_positioning, "a") }
      end
    end
  end
end
