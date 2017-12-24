require "cocaine"
require "find"
require "colorize"
require "./src/extract-innosetup"
require "./src/extract-upx"
require "./src/extract-uefi"
require "./src/extract-7z"

module VBiosFinder
  class Main
    def self.run file
      puts "trying to extract #{file}"

      if Utils::installed?("innoextract", "required for Inno Installers") && Test::innosetup(file)
        puts "found InnoSetup, attempting extraction...".colorize(:green)
        Extract::innosetup(file)
      else
        puts "not an InnoSetup archive".colorize(:red)
      end

      if Utils::installed?("upx", "required for UPX executables") && Test::upx(file)
        puts "found file packed with UPX, attempting extraction...".colorize(:green)
        Extract::upx(file)
      else
        puts "not packed with UPX".colorize(:red)
      end

      if Utils.installed?("7z", "required for 7z (self-extracting) archives") && Test::p7zip(file)
        puts "found 7z archive".colorize(:green)
        Extract::p7zip(file)
      else
        puts "not packed with 7z".colorize(:red)
      end

      if Utils::installed?("UEFIDump", "required for UEFI images") && Test::uefi(file)
        puts "found UEFI image".colorize(:green)
        Extract::uefi(file)
        puts "extracted. filtering modules...".colorize(:blue)
        modules = Find.find("#{file}.dump").reject{|e| File.directory? e}.select{|e| e.end_with? ".bin"}
        puts "got #{modules.length} modules".colorize(:blue)
        puts "finding vbios".colorize(:blue)
        line = Cocaine::CommandLine.new("file", "-b :file")
        modules = modules.select{|e| line.run(file: e).include? "Video"}
        if modules.length > 0
          puts "#{modules.length} possible candidates".colorize(:green)
          outpath = "#{Dir.pwd}/../output"
          FileUtils.mkdir_p outpath
          modules.each do |mod|
            rom_parser = Cocaine::CommandLine.new("rom-parser", ":file")
            begin
              romdata = rom_parser.run(file: mod)
              romdata = romdata.split("\n")[1].split(", ").map{|e| e.split(": ")}.to_h rescue nil
              unless romdata.nil? && romdata['vendor'].nil? && romdata['device'].nil?
                puts "Found VBIOS for device #{romdata['vendor']}:#{romdata['device']}!".colorize(:green)
                new_filename = "vbios_#{romdata['vendor']}_#{romdata['device']}.rom"
                FileUtils.cp(file, "#{outpath}/#{new_filename}")
              end
            rescue Cocaine::ExitStatusError => e
              puts "can't determine vbios type"
            end
          end
          puts "Job done. Extracted files can be found in #{outpath}".colorize(:green)
        else
          puts "no candidates found :(".colorize(:red)
        end
        exit 0
      else
        puts "not an uefi image"
      end

      Utils::get_new_files.each do |e|
        puts
        run e
      end
    end
  end
end