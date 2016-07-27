# -*- encoding: utf-8 -*-

require 'hexapdf/data_dir'
require 'hexapdf/font/type1_wrapper'

module HexaPDF
  module FontLoader

    # This module is used for providing the standard 14 PDF fonts.
    module Standard14

      # Mapping of font family name and variant to font name.
      MAPPING = {
        'Times' => {
          none: 'Times-Roman',
          bold: 'Times-Bold',
          italic: 'Times-Italic',
          bold_italic: 'Times-BoldItalic',
        },
        'Helvetica' => {
          none: 'Helvetica',
          bold: 'Helvetica-Bold',
          italic: 'Helvetica-Oblique',
          bold_italic: 'Helvetica-BoldOblique',
        },
        'Courier' => {
          none: 'Courier',
          bold: 'Courier-Bold',
          italic: 'Courier-Oblique',
          bold_italic: 'Courier-BoldOblique',
        },
        'Symbol' => {
          none: 'Symbol',
        },
        'ZapfDingbats' => {
          none: 'ZapfDingbats',
        },
      }

      # Creates a new font object backed by the AFM font metrics read from the file or IO stream.
      def self.call(document, name, variant: :none, **)
        name = MAPPING[name] && MAPPING[name][variant]
        return nil if name.nil?

        file = File.join(HexaPDF.data_dir, 'afm', "#{name}.afm")
        font = HexaPDF::Font::Type1::Font.from_afm(file)
        HexaPDF::Font::Type1Wrapper.new(document, font)
      end

    end

  end
end