require "../spec_helper"

WITH_WHITESPACE = <<-XML
<item>
  <flagID>0</flagID>
  <itemID>0</itemID>
  <locationID>0</locationID>
  <ownerID>0</ownerID>
  <quantity>-1</quantity>
  <typeID>0</typeID>
</item>
XML

XML_SCALAR_ARRAY = <<-XML
<?xml version="1.0" encoding="utf-8"?>
<items>
  <number>1</number>
  <number>2</number>
  <number>3</number>
</items>
XML

XML_OBJECT_ARRAY = <<-XML
<?xml version="1.0" encoding="utf-8"?>
<items>
  <item>
    <flagID>0</flagID>
    <itemID>0</itemID>
    <locationID>0</locationID>
    <ownerID>0</ownerID>
    <quantity>-1</quantity>
    <typeID>0</typeID>
  </item>
  <item>
    <flagID>0</flagID>
    <itemID>1</itemID>
    <locationID>0</locationID>
    <ownerID>0</ownerID>
    <quantity>-1</quantity>
    <typeID>0</typeID>
  </item>
</items>
XML

describe OQ::Converters::Xml do
  describe ".deserialize" do
    describe Object do
      describe "a key/value pair" do
        it "should output correctly" do
          run_binary(%(<person>Fred</person>), args: ["-i", "xml", "-c", "."]) do |output|
            output.should eq %({"person":"Fred"}\n)
          end
        end
      end

      describe "with whitespace" do
        it "should output correctly" do
          run_binary(WITH_WHITESPACE, args: ["-i", "xml", "-c", "."]) do |output|
            output.should eq %({"item":{"flagID":"0","itemID":"0","locationID":"0","ownerID":"0","quantity":"-1","typeID":"0"}}\n)
          end
        end
      end

      describe "with the prolog" do
        it "should output correctly" do
          run_binary(%(<?xml version="1.0" encoding="utf-8"?><item><typeID>0</typeID></item>), args: ["-i", "xml", "-c", "."]) do |output|
            output.should eq %({"item":{"typeID":"0"}}\n)
          end
        end
      end

      describe "a simple object" do
        it "should output correctly" do
          run_binary(%(<person><firstname>Jane</firstname><lastname>Doe</lastname></person>), args: ["-i", "xml", "-c", "."]) do |output|
            output.should eq %({"person":{"firstname":"Jane","lastname":"Doe"}}\n)
          end
        end
      end

      describe "attributes" do
        it "should output correctly" do
          run_binary(%(<person id="1" foo="bar"><firstname>Jane</firstname><lastname>Doe</lastname></person>), args: ["-i", "xml", "-c", "."]) do |output|
            output.should eq %({"person":{"@id":"1","@foo":"bar","firstname":"Jane","lastname":"Doe"}}\n)
          end
        end
      end

      describe "nested objects" do
        it "should output correctly" do
          run_binary(%(<person><firstname>Jane</firstname><lastname>Doe</lastname><location><zip>15061</zip><address>123 Foo Street</address></location></person>), args: ["-i", "xml", "-c", "."]) do |output|
            output.should eq %({"person":{"firstname":"Jane","lastname":"Doe","location":{"zip":"15061","address":"123 Foo Street"}}}\n)
          end
        end
      end

      describe "complex object" do
        it "should output correctly" do
          run_binary(%(<root><x a="1"><a>2</a></x><y b="3">4</y></root>), args: ["-i", "xml", "-c", "."]) do |output|
            output.should eq %({"root":{"x":{"@a":"1","a":"2"},"y":{"@b":"3","#text":"4"}}}\n)
          end
        end
      end

      describe "with mixed content" do
        it "should output correctly" do
          run_binary(%(<root>x<y>z</y></root>), args: ["-i", "xml", "-c", ".root"]) do |output|
            output.should eq %({"y":"z"}\n)
          end
        end
      end
    end

    describe Array do
      describe "of scalar values" do
        it "should output correctly" do
          run_binary(XML_SCALAR_ARRAY, args: ["-i", "xml", "-c", "."]) do |output|
            output.should eq %({"items":["1","2","3"]}\n)
          end
        end
      end

      describe "of objects" do
        it "should output correctly" do
          run_binary(XML_OBJECT_ARRAY, args: ["-i", "xml", "-c", "."]) do |output|
            output.should eq %({"items":[{"flagID":"0","itemID":"0","locationID":"0","ownerID":"0","quantity":"-1","typeID":"0"},{"flagID":"0","itemID":"1","locationID":"0","ownerID":"0","quantity":"-1","typeID":"0"}]}\n)
          end
        end
      end
    end
  end

  # describe ".serialize" do
  #   it "allows not emitting the xml prolog" do
  #     run_binary("1", args: ["-o", "xml", "--no-prolog", "."]) do |output|
  #       output.should eq(<<-XML
  #         <root>1</root>\n
  #         XML
  #       )
  #     end
  #   end

  #   describe "allows setting the root element" do
  #     describe "to another string" do
  #       it "should use the provided name" do
  #         run_binary("1", args: ["-o", "xml", "--xml-root", "foo", "."]) do |output|
  #           output.should eq(<<-XML
  #             <?xml version="1.0" encoding="UTF-8"?>
  #             <foo>1</foo>\n
  #             XML
  #           )
  #         end
  #       end
  #     end

  #     describe "to an empty string" do
  #       it "should not be emitted" do
  #         run_binary("1", args: ["-o", "xml", "--xml-root", "", "."]) do |output|
  #           output.should eq(<<-XML
  #             <?xml version="1.0" encoding="UTF-8"?>
  #             1
  #             XML
  #           )
  #         end
  #       end
  #     end

  #     describe "it allows changing the array item name" do
  #       describe "with a single nesting level" do
  #         it "should emit item tags for non empty values" do
  #           run_binary(%(["x",{}]), args: ["-o", "xml", "--xml-item", "foo", "."]) do |output|
  #             output.should eq(<<-XML
  #               <?xml version="1.0" encoding="UTF-8"?>
  #               <root>
  #                 <foo>x</foo>
  #                 <foo/>
  #               </root>\n
  #               XML
  #             )
  #           end
  #         end
  #       end

  #       describe "with a larger nesting level" do
  #         it "should emit item tags for non empty values" do
  #           run_binary(%({"a":[[]]}), args: ["-o", "xml", "--xml-item", "foo", "."]) do |output|
  #             output.should eq(<<-XML
  #               <?xml version="1.0" encoding="UTF-8"?>
  #               <root>
  #                 <a>
  #                   <foo/>
  #                 </a>
  #               </root>\n
  #               XML
  #             )
  #           end
  #         end
  #       end
  #     end

  #     describe "it allows changing the indent" do
  #       describe "more spaces" do
  #         it "should emit the extra spaces" do
  #           run_binary(%({"name": "Jim", "age": 12}), args: ["-o", "xml", "--indent", "4", "."]) do |output|
  #             output.should eq(<<-XML
  #               <?xml version="1.0" encoding="UTF-8"?>
  #               <root>
  #                   <name>Jim</name>
  #                   <age>12</age>
  #               </root>\n
  #               XML
  #             )
  #           end
  #         end
  #       end

  #       describe "to tabs" do
  #         it "should emit the indent as tabs" do
  #           run_binary(%({"name": "Jim", "age": 12}), args: ["-o", "xml", "--indent", "3", "--tab", "."]) do |output|
  #             output.should eq(<<-XML
  #               <?xml version="1.0" encoding="UTF-8"?>
  #               <root>
  #               \t\t\t<name>Jim</name>
  #               \t\t\t<age>12</age>
  #               </root>\n
  #               XML
  #             )
  #           end
  #         end
  #       end
  #     end
  #   end

  #   describe String do
  #     describe "not blank" do
  #       it "should output correctly" do
  #         run_binary(%("Jim"), args: ["-o", "xml", "."]) do |output|
  #           output.should eq(<<-XML
  #             <?xml version="1.0" encoding="UTF-8"?>
  #             <root>Jim</root>\n
  #             XML
  #           )
  #         end
  #       end
  #     end

  #     describe "blank" do
  #       it "should output correctly" do
  #         run_binary(%(""), args: ["-o", "xml", "."]) do |output|
  #           output.should eq(<<-XML
  #           <?xml version="1.0" encoding="UTF-8"?>
  #           <root></root>\n
  #           XML
  #           )
  #         end
  #       end
  #     end
  #   end

  #   describe Bool do
  #     it "should output correctly" do
  #       run_binary(%(true), args: ["-o", "xml", "."]) do |output|
  #         output.should eq(<<-XML
  #           <?xml version="1.0" encoding="UTF-8"?>
  #           <root>true</root>\n
  #           XML
  #         )
  #       end
  #     end
  #   end

  #   describe Float do
  #     it "should output correctly" do
  #       run_binary(%("1.5"), args: ["-o", "xml", "."]) do |output|
  #         output.should eq(<<-XML
  #           <?xml version="1.0" encoding="UTF-8"?>
  #           <root>1.5</root>\n
  #           XML
  #         )
  #       end
  #     end
  #   end

  #   describe Nil do
  #     it "should output correctly" do
  #       run_binary("null", args: ["-o", "xml", "."]) do |output|
  #         output.should eq(<<-XML
  #           <?xml version="1.0" encoding="UTF-8"?>
  #           <root/>\n
  #           XML
  #         )
  #       end
  #     end
  #   end

  #   describe Array do
  #     describe "empty array on root" do
  #       it "should emit a self closing root tag" do
  #         run_binary("[]", args: ["-o", "xml", "."]) do |output|
  #           output.should eq(<<-XML
  #             <?xml version="1.0" encoding="UTF-8"?>
  #             <root/>\n
  #             XML
  #           )
  #         end
  #       end
  #     end

  #     describe "array with values on root" do
  #       it "should emit item tags for non empty values" do
  #         run_binary(%(["x",{}]), args: ["-o", "xml", "."]) do |output|
  #           output.should eq(<<-XML
  #             <?xml version="1.0" encoding="UTF-8"?>
  #             <root>
  #               <item>x</item>
  #               <item/>
  #             </root>\n
  #             XML
  #           )
  #         end
  #       end
  #     end

  #     describe "object with empty array/values" do
  #       it "should emit self closing tags for each" do
  #         run_binary(%({"a":[],"b":{},"c":null}), args: ["-o", "xml", "."]) do |output|
  #           output.should eq(<<-XML
  #             <?xml version="1.0" encoding="UTF-8"?>
  #             <root>
  #               <a/>
  #               <b/>
  #               <c/>
  #             </root>\n
  #             XML
  #           )
  #         end
  #       end
  #     end

  #     describe "2D array object value" do
  #       it "should emit key name tag then self closing item tag" do
  #         run_binary(%({"a":[[]]}), args: ["-o", "xml", "."]) do |output|
  #           output.should eq(<<-XML
  #             <?xml version="1.0" encoding="UTF-8"?>
  #             <root>
  #               <a>
  #                 <item/>
  #               </a>
  #             </root>\n
  #             XML
  #           )
  #         end
  #       end
  #     end

  #     describe "object value mixed/nested array values" do
  #       it "should emit correctly" do
  #         run_binary(%({"x":[1,[2,[3]]]}), args: ["-o", "xml", "."]) do |output|
  #           output.should eq(<<-XML
  #             <?xml version="1.0" encoding="UTF-8"?>
  #             <root>
  #               <x>1</x>
  #               <x>
  #                 <item>2</item>
  #                 <item>
  #                   <item>3</item>
  #                 </item>
  #               </x>
  #             </root>\n
  #             XML
  #           )
  #         end
  #       end
  #     end

  #     describe "object value array primitive values" do
  #       it "should emit correctly" do
  #         run_binary(%({"x":[1,2,3]}), args: ["-o", "xml", "."]) do |output|
  #           output.should eq(<<-XML
  #             <?xml version="1.0" encoding="UTF-8"?>
  #             <root>
  #               <x>1</x>
  #               <x>2</x>
  #               <x>3</x>
  #             </root>\n
  #             XML
  #           )
  #         end
  #       end
  #     end
  #   end

  #   describe Object do
  #     describe "simple key/value" do
  #       it "should output correctly" do
  #         run_binary(%({"name":"Jim"}), args: ["-o", "xml", "."]) do |output|
  #           output.should eq(<<-XML
  #             <?xml version="1.0" encoding="UTF-8"?>
  #             <root>
  #               <name>Jim</name>
  #             </root>\n
  #             XML
  #           )
  #         end
  #       end
  #     end

  #     describe "nested object" do
  #       it "should output correctly" do
  #         run_binary(%({"name":"Jim", "city": {"street":"forbs"}}), args: ["-o", "xml", "."]) do |output|
  #           output.should eq(<<-XML
  #             <?xml version="1.0" encoding="UTF-8"?>
  #             <root>
  #               <name>Jim</name>
  #               <city>
  #                 <street>forbs</street>
  #               </city>
  #             </root>\n
  #             XML
  #           )
  #         end
  #       end
  #     end

  #     describe "with an attribute" do
  #       it "should output correctly" do
  #         run_binary(%({"name":"Jim", "city": {"@street":"forbs"}}), args: ["-o", "xml", "."]) do |output|
  #           output.should eq(<<-XML
  #             <?xml version="1.0" encoding="UTF-8"?>
  #             <root>
  #               <name>Jim</name>
  #               <city street="forbs"/>
  #             </root>\n
  #             XML
  #           )
  #         end
  #       end
  #     end

  #     describe "with an attribute and #text" do
  #       it "should output correctly" do
  #         run_binary(%({"name":"Jim", "city": {"@street":"forbs", "#text": "Atlantic"}}), args: ["-o", "xml", "."]) do |output|
  #           output.should eq(<<-XML
  #             <?xml version="1.0" encoding="UTF-8"?>
  #             <root>
  #               <name>Jim</name>
  #               <city street="forbs">Atlantic</city>
  #             </root>\n
  #             XML
  #           )
  #         end
  #       end
  #     end

  #     describe "with attributes" do
  #       it "should output correctly" do
  #         run_binary(%({"name":"Jim", "city": {"@street":"forbs", "@post": 123}}), args: ["-o", "xml", "."]) do |output|
  #           output.should eq(<<-XML
  #             <?xml version="1.0" encoding="UTF-8"?>
  #             <root>
  #               <name>Jim</name>
  #               <city street="forbs" post="123"/>
  #             </root>\n
  #             XML
  #           )
  #         end
  #       end
  #     end

  #     describe "with attributes and #text" do
  #       it "should output correctly" do
  #         run_binary(%({"name":"Jim", "city": {"@street":"forbs", "@post": 123, "#text": "Atlantic"}}), args: ["-o", "xml", "."]) do |output|
  #           output.should eq(<<-XML
  #             <?xml version="1.0" encoding="UTF-8"?>
  #             <root>
  #               <name>Jim</name>
  #               <city street="forbs" post="123">Atlantic</city>
  #             </root>\n
  #             XML
  #           )
  #         end
  #       end
  #     end
  #   end
  # end
end
