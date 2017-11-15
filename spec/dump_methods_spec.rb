require 'spec_helper'

describe SeedDump do
  before do
    @update_code = """
[var_name].each do |f|
  item = [model_name].find_by_key(f[:key])
  unless item.nil?
    item.update_attributes(f)
    item.save
  else
    [model_name].create!(f)
  end
end
"""
  end

  def underscore(camel_cased_word)
   camel_cased_word.to_s.gsub(/::/, '/').
     gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
     gsub(/([a-z\d])([A-Z])/,'\1_\2').
     tr("-", "_").
     downcase
  end

  def expected_output(include_id = false, id_offset = 0)
      output = "sample = [\n  "

      data = []
      ((1 + id_offset)..(3 + id_offset)).each do |i|
        data << "{#{include_id ? "id: #{i}, " : ''}string: \"string\", text: \"text\", integer: 42, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false}"
      end

      @update_code = @update_code.gsub("[model_name]", "Sample").gsub("[var_name]", "sample")

      output + data.join(",\n  ") + "\n]\n"+@update_code
  end

  describe '.dump' do
    before do
      Rails.application.eager_load!

      create_db

      FactoryGirl.create_list(:sample, 3)
    end

    context 'without file option' do
      it 'should return the dump of the models passed in' do
        SeedDump.dump(Sample).should eq(expected_output)
      end
    end

    context 'with file option' do
      before do
        @filename = Dir::Tmpname.make_tmpname(File.join(Dir.tmpdir, 'foo'), nil)
      end

      after do
        File.unlink(@filename)
      end

      it 'should dump the models to the specified file' do
        SeedDump.dump(Sample, file: @filename)

        File.open(@filename) { |file| file.read.should eq(expected_output) }
      end

      context 'with append option' do
        it 'should append to the file rather than overwriting it' do
          SeedDump.dump(Sample, file: @filename)
          SeedDump.dump(Sample, file: @filename, append: true)

          File.open(@filename) { |file| file.read.should eq(expected_output + expected_output) }
        end
      end
    end

    context 'ActiveRecord relation' do
      it 'should return nil if the count is 0' do
        SeedDump.dump(EmptyModel).should be(nil)
      end

      context 'without an order parameter' do
        it 'should dump the models sorted by primary key ascending' do
          SeedDump.dump(Sample).should eq(expected_output)
        end
      end
    end

    context 'with a batch_size parameter' do
      it 'should not raise an exception' do
        SeedDump.dump(Sample, batch_size: 100)
      end

      it 'should not cause records to not be dumped' do
        SeedDump.dump(Sample, batch_size: 2).should eq(expected_output)

        SeedDump.dump(Sample, batch_size: 1).should eq(expected_output)
      end
    end

    context 'Array' do
      it 'should return the dump of the models passed in' do
        SeedDump.dump(Sample.all.to_a, batch_size: 2).should eq(expected_output)
      end

      it 'should return nil if the array is empty' do
        SeedDump.dump([]).should be(nil)
      end
    end

    context 'with an exclude parameter' do
      it 'should exclude the specified attributes from the dump' do
        @update_code = @update_code.gsub("[model_name]", "Sample").gsub("[var_name]", "sample")
        expected_output = "sample = [\n  {text: \"text\", integer: 42, decimal: \"2.72\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {text: \"text\", integer: 42, decimal: \"2.72\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {text: \"text\", integer: 42, decimal: \"2.72\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false}\n]\n"+@update_code


        SeedDump.dump(Sample, exclude: [:id, :created_at, :updated_at, :string, :float, :datetime]).should eq(expected_output)
      end
    end
  end
end
